#!/usr/bin/env node
// Sets imagePath on every Product() record in product_catalog.dart to the
// downloaded Pexels target path recorded in scripts/fetch_state.json.
// Only records whose fetch status === 'done' are updated; the rest keep their
// existing imagePath so nothing is ever left pointing at a missing file.

const fs = require('fs');
const path = require('path');
const ROOT = process.env.PROJECT_ROOT || 'D:/src/my_print_shop';
const SRC = path.join(ROOT, 'lib/data/product_catalog.dart');
const RECORDS = path.join(ROOT, 'scripts/catalog_records.json');
const STATE = path.join(ROOT, 'scripts/fetch_state.json');

const lines = fs.readFileSync(SRC, 'utf8').split('\n');
const records = JSON.parse(fs.readFileSync(RECORDS, 'utf8')).records;
const state = fs.existsSync(STATE) ? JSON.parse(fs.readFileSync(STATE, 'utf8')) : { results: {} };

const recById = new Map(records.map((r) => [r.id, r]));

// Reuse the same list-block locator logic.
function stripStrings(line) {
  return line.replace(/'(?:[^'\\]|\\.)*'/g, "''").replace(/"(?:[^"\\]|\\.)*"/g, '""');
}

let listStart = -1;
for (let i = 0; i < lines.length; i++) {
  if (/^\s*static\s+final\s+List<Product>\s+products\s*=\s*\[/.test(lines[i])) {
    listStart = i;
    break;
  }
}
let listEnd = -1;
{
  let depth = 0;
  let started = false;
  for (let i = listStart; i < lines.length; i++) {
    const s = stripStrings(lines[i]);
    const open = (s.match(/\[/g) || []).length;
    const close = (s.match(/\]/g) || []).length;
    if (!started) {
      const eqIdx = s.indexOf('=');
      const bIdx = s.indexOf('[');
      if (eqIdx !== -1 && bIdx > eqIdx) {
        depth = open - close;
        started = depth > 0;
      }
      if (started && depth === 0) { listEnd = i; break; }
      continue;
    }
    depth += open - close;
    if (depth <= 0) { listEnd = i; break; }
  }
}

const blocks = [];
{
  let i = listStart + 1;
  while (i <= listEnd) {
    const line = stripStrings(lines[i]);
    if (/^\s{0,4}Product\s*\(\s*$/.test(line)) {
      let depth = 1;
      let j = i + 1;
      for (; j <= listEnd; j++) {
        depth += stripStrings(lines[j]).split('').reduce(
          (n, ch) => n + (ch === '(' ? 1 : ch === ')' ? -1 : 0), 0);
        if (depth <= 0) break;
      }
      blocks.push({ start: i, end: j });
      i = j + 1;
    } else {
      i++;
    }
  }
}
console.log('blocks:', blocks.length);

let updated = 0;
let leftAlone = 0;
const notDone = [];
const notFound = [];
const now = new Date().toISOString();

for (const b of blocks) {
  const text = lines.slice(b.start, b.end + 1).join('\n');
  const mId = text.match(/id\s*:\s*'([^']*)'/);
  if (!mId) { notFound.push({ line: b.start + 1, issue: 'no id' }); continue; }
  const id = mId[1];
  const rec = recById.get(id);
  const res = state.results && state.results[id];

  // Locate the imagePath line inside this block.
  let imgLine = -1;
  for (let k = b.start; k <= b.end; k++) {
    if (/^\s*imagePath\s*:/.test(lines[k])) { imgLine = k; break; }
  }
  if (imgLine === -1) {
    notFound.push({ id, line: b.start + 1, issue: 'no imagePath line' });
    continue;
  }

  if (rec && res && res.status === 'done') {
    const indent = lines[imgLine].match(/^\s*/)[0];
    lines[imgLine] = `${indent}imagePath: '${rec.targetPath}',`;
    updated++;
  } else {
    if (rec && res && res.status !== 'done') notDone.push({ id, status: res.status });
    else if (rec && !res) notDone.push({ id, status: 'no-fetch-state' });
    else if (!rec) notFound.push({ id, line: imgLine + 1, issue: 'not in records json' });
    leftAlone++;
  }
}

fs.writeFileSync(SRC, lines.join('\n'), 'utf8');
console.log(`updated imagePath: ${updated}`);
console.log(`kept existing    : ${leftAlone}`);
console.log('records with fetch not-done (kept existing):');
for (const n of notDone.slice(0, 60)) console.log('  ', n.id, n.status);
if (notDone.length > 60) console.log('   ... and', notDone.length - 60, 'more');
console.log('not-found:', notFound.length, notFound.slice(0, 10));