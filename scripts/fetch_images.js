#!/usr/bin/env node
// Fetch "large" photos from the Pexels Search API for every catalog record.
// - Reads the API key from the PEXELS_API_KEY environment variable only.
// - For each record builds a search, picks the first photo not yet assigned to
//   another record (global uniqueness), downloads photo.src.large into the
//   record's target folder and reports name -> file -> status.
// - Resumable: finished records are recorded in scripts/fetch_state.json and
//   existing files are never re-downloaded.
// - Under 429 the script backs off using Retry-After and adapts pacing.

const fs = require('fs');
const path = require('path');
const ROOT = process.env.PROJECT_ROOT || 'D:/src/my_print_shop';
const RECORDS = path.join(ROOT, 'scripts/catalog_records.json');
const STATE = path.join(ROOT, 'scripts/fetch_state.json');

const args = process.argv.slice(2);
function argVal(name, def) {
  const i = args.indexOf(name);
  return i !== -1 ? args[i + 1] : def;
}
const onlyCategory = argVal('--cat', null);
const limit = argVal('--limit', null) ? parseInt(argVal('--limit'), 10) : null;
const offset = argVal('--offset', null) ? parseInt(argVal('--offset'), 10) : 0;
const onlyIds = argVal('--ids', null) ? argVal('--ids', null).split(',') : null;
const force = args.includes('--force');
const forceUnique = args.includes('--force-unique');

const key = process.env.PEXELS_API_KEY;
if (!key) {
  console.error(
    'PEXELS_API_KEY environment variable is required.\n' +
      'Set it before running, e.g. `$env:PEXELS_API_KEY = "..."` (PowerShell) or\n' +
      '`export PEXELS_API_KEY=...` (macOS/Linux), then run this script.'
  );
  process.exit(1);
}

const BASE_DELAY_MS = parseInt(process.env.PEXELS_DELAY_MS || '6000', 10);
const HOURLY_CAP = parseInt(process.env.PEXELS_HOURLY_CAP || '1000', 10);

const records = JSON.parse(fs.readFileSync(RECORDS, 'utf8')).records;
const state = fs.existsSync(STATE)
  ? JSON.parse(fs.readFileSync(STATE, 'utf8'))
  : { usedPhotoIds: [], results: {} };
state.usedPhotoIds = new Set(state.usedPhotoIds);
state.results = state.results || {};

function saveState() {
  fs.writeFileSync(
    STATE,
    JSON.stringify(
      { usedPhotoIds: [...state.usedPhotoIds], results: state.results },
      null,
      2
    ),
    'utf8'
  );
}

const searchTimes = state.searchTimes || (state.searchTimes = []);
const ok = (r) => r >= 200 && r < 300;

function sleep(ms) {
  return new Promise((res) => setTimeout(res, ms));
}

function slow(query) {
  return query
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .slice(0, 4)
    .join(' ');
}

async function searchPexels(query, attempt, page) {
  const now = Date.now();
  searchTimes.push(now);
  while (searchTimes.length > HOURLY_CAP) searchTimes.shift();
  if (searchTimes.length >= HOURLY_CAP) {
    const oldest = searchTimes[0];
    const wait = oldest + 3600 * 1000 - now;
    if (wait > 0) {
      console.log(`   [pacing] waiting ${Math.ceil(wait / 60000)}m for hourly cap...`);
      await sleep(wait);
    }
  }
  const url =
    'https://api.pexels.com/v1/search?query=' +
    encodeURIComponent(query) +
    '&per_page=80&page=' +
    (page || 1);
  const resp = await fetch(url, { headers: { Authorization: key } });
  if (resp.status === 429) {
    const ra = Number(resp.headers.get('retry-after') || '60');
    const wait = Math.min(900, ra * 1000 || 60000);
    const label = state._rateLimited || 0;
    state._rateLimited = label + 1;
    console.log(`   429 rate limited (x${label + 1}) — waiting ${Math.ceil(wait / 1000)}s`);
    saveState();
    await sleep(wait);
    return searchPexels(query, attempt + 1);
  }
  if (resp.status === 400) {
    const body = await resp.text();
    console.log('   400 status:', body.slice(0, 160));
    return { photos: [] };
  }
  if (!ok(resp.status)) {
    const body = await resp.text();
    console.log('   search error', resp.status, body.slice(0, 160));
    return { photos: [] };
  }
  const data = await resp.json();
  return { photos: data.photos || [] };
}

async function download(url) {
  const resp = await fetch(url);
  if (!ok(resp.status)) return null;
  const buf = Buffer.from(await resp.arrayBuffer());
  if (buf.length < 1024) return null;
  return buf;
}

const summary = { done: 0, downloaded: 0, skipped: 0, failed: [], noresults: [], noImagePhoto: [] };

(async () => {
  let queue = records.slice(offset);
  if (limit !== null) queue = queue.slice(0, limit);
  if (onlyCategory) queue = queue.filter((r) => r.category === onlyCategory);
  if (onlyIds) queue = queue.filter((r) => onlyIds.includes(r.id));

  console.log(`Fetching ${queue.length} records${onlyCategory ? ` (${onlyCategory})` : ''}...\n`);

  let i = 0;
  for (const rec of queue) {
    i++;
    const prev = state.results[rec.id];
    const exists = fs.existsSync(path.join(ROOT, rec.targetPath));
    if (!force && (exists || (prev && prev.status === 'done'))) {
      state.results[rec.id] = { status: 'done', file: rec.file, prev: 'existing' };
      summary.skipped++;
      if (i % 50 === 0 || i === queue.length)
        console.log(`-- ${i}/${queue.length} -- done=${summary.done + summary.downloaded} failed=${summary.failed.length}`);
      continue;
    }
    if (force && exists) {
      fs.rmSync(path.join(ROOT, rec.targetPath), { force: true });
    }
    saveState();
    console.log(`[${i}/${queue.length}] ${rec.id}  (${rec.category})`);
    console.log(`   query: "${rec.query}"`);
    try {
      let photos = (await searchPexels(rec.query, 1)).photos;
      let usedFallback = false;
      if (!photos.length) {
        console.log('   no photos for full query, trying fallback...');
        const simple = slow(rec.query);
        photos = (await searchPexels(simple, 1)).photos;
        usedFallback = true;
      }
      let chosen = null;
      for (const p of photos) {
        if (!state.usedPhotoIds.has(p.id)) { chosen = p; break; }
      }
      if (!chosen && forceUnique) {
        const pickUnused = async (q) => {
          for (let page = 1; page <= 8; page++) {
            const candidates = (await searchPexels(q, 1, page)).photos;
            if (!candidates.length) break;
            for (const p of candidates) {
              if (!state.usedPhotoIds.has(p.id)) return { p, page };
            }
          }
          return null;
        };
        console.log('   all photos already used, paging deeper for an unused photo...');
        let found = await pickUnused(rec.query);
        let q = rec.query;
        if (!found) {
          q = slow(rec.query);
          console.log('   still none, trying fallback query:', q);
          found = await pickUnused(q);
        }
        if (!found) {
          state.results[rec.id] = { status: 'noresults', file: rec.file, query: rec.query };
          summary.noresults.push(rec);
          continue;
        }
        chosen = found.p;
        usedFallback = q !== rec.query;
        photos = [chosen];
      }
      chosen = chosen || (forceUnique ? null : photos[0]);
      if (!chosen && forceUnique) {
        state.results[rec.id] = { status: 'noresults', file: rec.file, query: rec.query };
        summary.noresults.push(rec);
        continue;
      }
      state.usedPhotoIds.add(chosen.id);
      const buf = await download(chosen.src.large);
      if (!buf) {
        state.results[rec.id] = { status: 'nodownload', file: rec.file, photoId: chosen.id };
        summary.noImagePhoto.push(rec);
        continue;
      }
      const full = path.join(ROOT, rec.targetPath);
      fs.mkdirSync(path.dirname(full), { recursive: true });
      fs.writeFileSync(full, buf);
      state.results[rec.id] = {
        status: 'done',
        file: rec.file,
        photoId: chosen.id,
        url: chosen.src.large,
        fallback: usedFallback,
      };
      summary.downloaded++;
      console.log(`   OK -> ${rec.targetPath}`);
    } catch (err) {
      state.results[rec.id] = { status: 'error', file: rec.file, error: String(err).slice(0, 200) };
      summary.failed.push(rec);
      console.log(`   ERROR ${String(err).slice(0, 160)}`);
    }
    saveState();
    if (i % 25 === 0 || i === queue.length)
      console.log(`-- ${i}/${queue.length} -- downloaded=${summary.downloaded} skipped=${summary.skipped} failed=${summary.failed.length} noresults=${summary.noresults.length}`);
    await sleep(BASE_DELAY_MS + Math.floor(Math.random() * 2500));
  }

  saveState();
  console.log('\n=== FETCH SUMMARY ===');
  console.log(`records processed : ${i}`);
  console.log(`downloaded        : ${summary.downloaded}`);
  console.log(`skipped (exists)  : ${summary.skipped}`);
  console.log(`no results        : ${summary.noresults.length}`);
  console.log(`download failed   : ${summary.noImagePhoto.length}`);
  console.log(`errors            : ${summary.failed.length}`);
  console.log(`rate limited hits : ${state._rateLimited || 0}`);

  const failList = [...summary.noresults, ...summary.noImagePhoto, ...summary.failed];
  if (failList.length) {
    console.log('\n=== RECORDS WITHOUT AN IMAGE (review manually) ===');
    for (const r of failList) console.log(`  ${r.id}  [${r.category}]  ${r.name}  -> ${r.query}`);
  }
})();