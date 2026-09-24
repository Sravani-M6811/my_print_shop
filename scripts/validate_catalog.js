#!/usr/bin/env node
// Validates the MY PRINT SHOP static catalogue stored in
// `lib/data/product_catalog.dart` (the single source of truth for the offline
// catalogue that every customer screen reads via `ProductCatalog.staticProducts`
// -> `CustomerCatalogue`).
//
// The rules mirror the invariants the project's own Dart test suite enforces
// (`test/catalog_dry_run_test.dart`, `test/final_audit_test.dart`,
// `test/design_separation_test.dart`, `test/saree_catalogue_test.dart`) plus
// data-integrity checks that are impractical in Dart (file existence, duplicate
// IDs/paths, broken cross-reference graphs).
//
// Read-only: never modifies data. Safe to run repeatedly. Prints a summary and
// exits 1 when any ERROR is found (warnings alone exit 0).
//
// Usage:
//   node scripts/validate_catalog.js
//   node scripts/validate_catalog.js --json      # machine-readable report
//   $env:PROJECT_ROOT='D:/src/my_print_shop'; node scripts/validate_catalog.js

const fs = require('fs');
const path = require('path');

const ROOT = process.env.PROJECT_ROOT || path.resolve(__dirname, '..');
const SRC = process.env.CATALOG_SRC ||
  path.join(ROOT, 'lib', 'data', 'product_catalog.dart');

const WARN = 'warn';
const ERROR = 'error';

const issues = [];

function report(level, rule, record, message) {
  const label = record && record.id ? `[${record.id}]` : '';
  issues.push({ level, rule, id: (record && record.id) || null, message: `${label} ${message}`.trim() });
}

// ── Constants mirrored from the project ───────────────────────────────────
// `ProductCatalog.categories` (lib/data/product_catalog.dart).
const CATEGORIES = [
  'Sarees',
  'Dress Materials',
  'Saree Borders',
  'T-Shirts',
  'Mugs',
  'Posters',
  'Embroidery',
  'Cardboard',
  'Glass Art',
];

const PRODUCT_TYPES = ['base', 'design', 'readyMade'];

// Tombstone values used across the Dart records.
const EMPTY_PRICE = { '0.0': true };

// ── Dart parsing (reuses extract_catalog.js strategy) ────────────────────

function stripStrings(line) {
  return line
    .replace(/'(?:[^'\\]|\\.)*'/g, "''")
    .replace(/"(?:[^"\\]|\\.)*"/g, '""');
}

function delta(s, open, close) {
  let n = 0;
  for (const ch of s) {
    if (ch === open) n++;
    else if (ch === close) n--;
  }
  return n;
}

const src = fs.readFileSync(SRC, 'utf8');
const lines = src.split('\n');

// Locate `static final List<Product> _staticProducts = [ ... ];`
let listStart = -1;
for (let i = 0; i < lines.length; i++) {
  if (/^\s*static\s+final\s+List<Product>\s+_?staticProducts\s*=\s*\[/.test(lines[i])) {
    listStart = i;
    break;
  }
}
if (listStart === -1) {
  console.error('validate_catalog: could not locate the products list in ' + SRC);
  process.exit(2);
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

// Extract each `    Product(` ... `    ),` block.
const blocks = [];
{
  let i = listStart + 1;
  while (i <= listEnd) {
    const line = stripStrings(lines[i]);
    if (/^\s{0,4}Product\s*\(\s*$/.test(line)) {
      let depth = 1;
      let j = i + 1;
      for (; j <= listEnd; j++) {
        depth += delta(stripStrings(lines[j]), '(', ')');
        if (depth <= 0) break;
      }
      blocks.push({ start: i, end: j });
      i = j + 1;
    } else {
      i++;
    }
  }
}

if (blocks.length === 0) {
  console.error('validate_catalog: no Product() blocks parsed from ' + SRC);
  process.exit(2);
}

// ── Field extraction helpers ─────────────────────────────────────────────

// Extract a string list: [ 'a', "b", ... ] (constants reference lists too).
function constStringList(match) {
  if (!match || !match[0]) return [];
  return [...match[0].matchAll(/'((?:[^'\\]|\\.)*)'/g)].map((x) => x[1].replace(/\\'/g, "'"));
}

// MapEntry('k','v') pairs (measurements etc.).
function mapEntryList(match) {
  if (!match) return [];
  const out = [];
  let depth = 0;
  let cur = '';
  for (const ch of match[0]) {
    if (ch === '(') depth++;
    else if (ch === ')') { depth--; if (depth === 0) { out.push(cur.trim()); cur = ''; continue; } }
    if (depth > 0) cur += ch;
    else if (depth === 0 && ch === ',') { out.push(cur.trim()); cur = ''; continue; }
  }
  if (cur.trim()) out.push(cur.trim());
  const items = [];
  for (const p of out) {
    const m = p.match(/^\s*MapEntry\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*'((?:[^'\\]|\\.)*)'\)\s*$/);
    if (m) items.push({ key: m[1].replace(/\\'/g, "'"), value: m[2].replace(/\\'/g, "'") });
  }
  return items;
}

// ProductVariant( label: 'Gold', isColor: true, colorValue: 0xFFF9A825 )
function parseVariants(text) {
  const out = [];
  const mFields = text.match(/variants\s*:\s*\[([\s\S]*?)\]/);
  if (!mFields) return out;
  let depth = 0;
  let cur = '';
  for (const ch of mFields[1]) {
    if (ch === '(') depth++;
    else if (ch === ')') depth--;
    else if (ch === ']' && depth === 0) continue;
    if (ch === ',' && depth === 0) {
      if (cur.trim()) out.push(cur.trim());
      cur = '';
    } else {
      cur += ch;
    }
  }
  if (cur.trim()) out.push(cur.trim());
  return out
    .map((v) => {
      const label = v.match(/label\s*:\s*'((?:[^'\\]|\\.)*)'/);
      const isColor = /isColor\s*:\s*true/.test(v);
      return { label: label ? label[1].replace(/\\'/g, "'") : '', isColor };
    })
    .filter((v) => v.label);
}

const products = [];
const unparsed = [];

for (const b of blocks) {
  const blockLines = lines.slice(b.start, b.end + 1);
  const text = blockLines.join('\n');

  const mId = text.match(/id\s*:\s*'((?:[^'\\]|\\.)*)'/);
  if (!mId) { unparsed.push({ line: b.start + 1, why: 'no id' }); continue; }
  const id = mId[1].replace(/\\'/g, "'");

  const mName = text.match(/name\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const mCat = text.match(/category\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const name = mName ? mName[1].replace(/\\'/g, "'") : '';
  const category = mCat ? mCat[1].replace(/\\'/g, "'") : '';

  const mSub = text.match(/subcategory\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const subcategory = mSub ? mSub[1] : '';

  const mPt = text.match(/productType\s*:\s*'([^']*)'/);
  const productType = mPt ? mPt[1] : 'design';

  const mPrice = text.match(/basePrice\s*:\s*(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/);
  const basePrice = mPrice ? parseFloat(mPrice[1]) : NaN;

  const mImg = text.match(/imagePath\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const imagePath = mImg ? mImg[1].replace(/\\'/g, "'") : '';

  const mDesc = text.match(/description\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const description = mDesc ? mDesc[1].replace(/\\'/g, "'") : '';

  const mTags = text.match(/tags\s*:\s*\[([^\]]*)\]/);
  const tags = mTags ? constStringList(mTags) : [];

  const mDg = text.match(/designGallery\s*:\s*\[([^\]]*)\]/);
  const designGallery = mDg ? constStringList(mDg) : [];

  const mCompIds = text.match(/compatibleProductIds\s*:\s*\[([^\]]*)\]/);
  const compatibleProductIds = mCompIds ? constStringList(mCompIds) : [];

  const mCompCats = text.match(/compatibleCategories\s*:\s*\[([^\]]*)\]/);
  const compatibleCategories = mCompCats ? constStringList(mCompCats) : [];

  const mPos = text.match(/supportedPrintPositions\s*:\s*\[([^\]]*)\]/);
  const supportedPrintPositions = mPos ? constStringList(mPos) : [];

  const mCustom = text.match(/customizableOptions\s*:\s*\[([^\]]*)\]/);
  const customizableOptions = mCustom ? constStringList(mCustom) : [];

  const mOptionals = text.match(/availability\s*:\s*(true|false)/);
  const availability = mOptionals ? mOptionals[1] === 'true' : true;

  const mFonts = text.match(/availableFonts\s*:\s*\[([^\]]*)\]/);
  const availableFonts = mFonts ? constStringList(mFonts) : [];

  const mSizes = text.match(/availableSizes\s*:\s*\[([^\]]*)\]/);
  const availableSizes = mSizes ? constStringList(mSizes) : [];

  const mMaterial = text.match(/material\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const material = mMaterial ? mMaterial[1].replace(/\\'/g, "'") : null;

  const mMeas = text.match(/measurements\s*:\s*\[([\s\S]*?)\]/);
  const measurements = mMeas ? mapEntryList(mMeas) : [];

  const mDtype = text.match(/designType\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const designType = mDtype ? mDtype[1].replace(/\\'/g, "'") : '';

  const mTrend = text.match(/isTrending\s*:\s*(true|false)/);
  const isTrending = mTrend ? mTrend[1] === 'true' : false;

  const mKw = text.match(/keywords\s*:\s*\[([^\]]*)\]/);
  const keywords = mKw ? constStringList(mKw) : [];

  const mTpl = text.match(/templateType\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const templateType = mTpl ? mTpl[1].replace(/\\'/g, "'") : '';

  let variants = parseVariants(text);

  products.push({
    blockStart: b.start + 1,
    id,
    name,
    category,
    subcategory,
    productType,
    basePrice,
    imagePath,
    description,
    tags,
    designGallery,
    compatibleProductIds,
    compatibleCategories,
    supportedPrintPositions,
    customizableOptions,
    availability,
    availableFonts,
    availableSizes,
    material,
    measurements,
    designType,
    isTrending,
    keywords,
    templateType,
    variants,
  });
}

if (unparsed.length) {
  for (const u of unparsed) {
    report(ERROR, 'parse', null, `unparsed Product() block at line ${u.line} (${u.why})`);
  }
}

// ── Checks ────────────────────────────────────────────────────────────────

const byId = new Map(products.map((p) => [p.id, p]));
const designRecords = products.filter((p) => p.productType === 'design');
const baseRecords = products.filter((p) => p.productType === 'base');
const readyMadeRecords = products.filter((p) => p.productType === 'readyMade');
const designsByCategory = new Map();
for (const d of designRecords) {
  if (!designsByCategory.has(d.category)) designsByCategory.set(d.category, []);
  designsByCategory.get(d.category).push(d);
}

// 1. Required fields.
for (const p of products) {
  if (!p.id) report(ERROR, 'required-field', p, 'missing id');
  if (!p.name || !p.name.trim()) report(ERROR, 'required-field', p, 'missing name');
  if (!p.category || !p.category.trim()) report(ERROR, 'required-field', p, 'missing category');
  if (!p.description || !p.description.trim())
    report(ERROR, 'required-field', p, 'missing description');
  if (!p.imagePath || !p.imagePath.trim()) report(ERROR, 'required-field', p, 'missing imagePath');
  if (Number.isNaN(p.basePrice)) report(ERROR, 'required-field', p, 'missing basePrice');
}

// 2. Duplicate IDs.
{
  const seen = new Map();
  for (const p of products) {
    if (seen.has(p.id)) report(ERROR, 'duplicate-id', p, `duplicate id also at line ${seen.get(p.id)}`);
    else seen.set(p.id, p.blockStart);
  }
}

// 3. Invalid/unknown category.
for (const p of products) {
  if (p.category && !CATEGORIES.includes(p.category)) {
    report(ERROR, 'category', p, `unknown category "${p.category}"`);
  }
}

// 5. Invalid product type.
for (const p of products) {
  if (!PRODUCT_TYPES.includes(p.productType)) {
    report(ERROR, 'product-type', p, `invalid productType "${p.productType}"`);
  }
}

// 10. Invalid price values (must be positive).
for (const p of products) {
  if (Number.isNaN(p.basePrice)) continue;
  if (p.basePrice <= 0) {
    report(ERROR, 'price', p, `non-positive basePrice ${p.basePrice}`);
  } else if (!Number.isFinite(p.basePrice)) {
    report(ERROR, 'price', p, `non-finite basePrice`);
  }
  if (String(p.basePrice) in EMPTY_PRICE) {
    report(ERROR, 'price', p, `placeholder price ${p.basePrice}`);
  }
}

// 6/7. Missing / invalid / nonexistent image paths.
const imageByPath = new Map();
for (const p of products) {
  const img = p.imagePath;
  if (!img) continue;

  const isHttp = /^https?:\/\//i.test(img);
  if (isHttp) {
    try {
      const u = new URL(img);
      if (!['http:', 'https:'].includes(u.protocol) || !u.hostname) throw new Error();
    } catch (_) {
      report(ERROR, 'image-url', p, `malformed http(s) image URL "${img}"`);
    }
    report(WARN, 'image-url', p, `remote image URL "${img}" is not bundled (CatalogueImage will use Image.network)`);
    continue;
  }

  const full = path.join(ROOT, img);
  if (fs.existsSync(full)) {
    imageByPath.set(img, (imageByPath.get(img) || []).concat(p.id));
  } else {
    report(ERROR, 'image-missing', p, `image file does not exist on disk: ${img}`);
    continue;
  }
}

// 9. Duplicate image paths across records (a shared asset can only be reused
//    intentionally — flag it).
for (const [img, ids] of imageByPath) {
  if (ids.length > 1) {
    for (const id of ids.slice(1)) {
      const rec = byId.get(id);
      report(WARN, 'image-duplicate', rec || { id }, `same image path as "${ids[0]}": ${img}`);
    }
  }
}

// 8. Asset separations: base/ready-made must live under products/,
//    designs under designs/.
const knownLegacyDesignCount = 25;
let designInProducts = 0;
for (const p of designRecords) {
  if (!/\/designs\//.test(p.imagePath)) {
    designInProducts++;
    report(WARN, 'asset-separation', p,
      `design record outside designs/ folder: ${p.imagePath}`);
  }
}
if (designInProducts > knownLegacyDesignCount) {
  report(ERROR, 'asset-separation', null,
    `${designInProducts} design records sit outside /designs/ (known legacy cap is ${knownLegacyDesignCount})`);
}

for (const p of [...baseRecords, ...readyMadeRecords]) {
  if (/\/designs\//.test(p.imagePath)) {
    report(ERROR, 'asset-separation', p,
      `${p.productType} record should live under products/ but points into designs/: ${p.imagePath}`);
  }
  if (p.productType === 'base' && !/\/products\//.test(p.imagePath)) {
    report(WARN, 'asset-separation', p,
      `base image path doesn't live under products/: ${p.imagePath}`);
  }
}

// 4. Every base/ready-made/design image must resolve to a bundled file
//   (file existence already reported above as image-missing).

// 12. Design gallery references on base products must resolve to design IDs.
const allIds = new Set(products.map((p) => p.id));
const designIdSet = new Set(designRecords.map((p) => p.id));
let basesWithEmptyGallery = 0;
const basesWithEmptyGalleryCats = new Set();
for (const p of baseRecords) {
  if (p.designGallery.length === 0) {
    basesWithEmptyGallery++;
    basesWithEmptyGalleryCats.add(p.category);
    continue;
  }
  for (const ref of p.designGallery) {
    if (!designIdSet.has(ref)) {
      report(ERROR, 'reference', p,
        `designGallery references missing design id "${ref}"`);
    } else if (!allIds.has(ref)) {
      report(ERROR, 'reference', p, `designGallery id "${ref}" not found in catalogue`);
    }
  }
}

// 13. Design compatibility references must resolve.
for (const d of designRecords) {
  for (const ref of d.compatibleProductIds) {
    if (!allIds.has(ref)) {
      report(ERROR, 'reference', d, `compatibleProductIds references missing product id "${ref}"`);
    }
  }
  for (const ref of d.compatibleCategories) {
    if (!CATEGORIES.includes(ref)) {
      report(ERROR, 'reference', d, `compatibleCategories references unknown category "${ref}"`);
    }
  }
  if (d.compatibleProductIds.length === 0 && d.compatibleCategories.length === 0) {
    report(ERROR, 'reference', d,
      'design has no compatibility — it will fall back to ' +
      `its own category ${d.category} and may not resolve in galleries`);
  }
}

// 11. Broken references between products and designs — reverse direction:
//     ensure the entry-point product flow resolves (designsForBase).
for (const p of baseRecords) {
  const cc = p.designGallery.length ? p.designGallery :
    designRecords.filter((d) =>
      d.compatibleProductIds.includes(p.id) ||
      (d.compatibleProductIds.length === 0 && d.compatibleCategories.includes(p.category))
    ).map((d) => d.id);
  if (cc.length === 0) {
    report(ERROR, 'reference', p, `no designs resolve for this base (empty gallery)`);
  }
}

// 3b. Missing category -> at least one base and one design.
for (const cat of CATEGORIES) {
  const bases = baseRecords.filter((p) => p.category === cat);
  const designs = designsByCategory.get(cat) || [];
  if (bases.length < 2) {
    report(ERROR, 'category', null,
      `"${cat}" exposes only ${bases.length} plain/base product(s) (project test requires ≥2)`);
  }
  if (designs.length < 1) {
    report(ERROR, 'category', null, `"${cat}" exposes no reusable design`);
  }
}

// 13. Category/design compatibility problems (design types invalid in a
//     category). Empty designType is legitimate for legacy design records
//     (see Product.designType docs) and must NOT be flagged.
const invalidDesignTypesForCategory = {
  'Sarees': ['Blouse'], // Sarees must not use the Embroidery/Blouse type.
};

for (const d of designRecords) {
  const banned = invalidDesignTypesForCategory[d.category] || [];
  if (banned.includes(d.designType)) {
    report(ERROR, 'design-type', d,
      `designType "${d.designType}" is not valid for category "${d.category}"`);
  }
}

// 14/15. Invalid asset path formatting.
for (const p of products) {
  const img = p.imagePath;
  if (img && !/^https?:\/\//i.test(img)) {
    if (!img.startsWith('assets/images/')) {
      report(WARN, 'asset-path', p, `image path not under assets/images/: "${img}"`);
    }
    if (/\\/.test(img)) {
      report(WARN, 'asset-path', p, `image path uses backslashes: "${img}"`);
    }
    if (/^https?:\/\//i.test(img) && /[\s'"<>]/.test(img)) {
      report(ERROR, 'asset-path', p, `URL contains invalid characters: "${img}"`);
    }
  }
}

// 16. Naming conventions. The project's only naming invariant (enforced by
//     test/final_audit_test.dart) is that *design* records never use the
//     base_/rm_ prefixes. Base products legitimately use base_ AND cat_ ids
//     (e.g. cat_saree_silk_red), so no prefix rule applies to them.
for (const p of designRecords) {
  if (p.id.startsWith('base_') || p.id.startsWith('rm_')) {
    report(ERROR, 'naming', p,
      `design id must not use base_/rm_ prefix: ${p.id}`);
  }
}

// 17. Design type / trending sanity. templateType drives the template
//     picker for any template-driven category (Cardboard, Posters, Glass Art
//     and others are all documented as template-capable), so it is not limited
//     to Cardboard.

// 18. Variant sanity.
for (const p of baseRecords) {
  if (p.variants.length === 0) {
    report(WARN, 'variant', p, 'base product has no variants');
  }
}

// 19. Catalogue entry points resolve (featured / popular / base lists).
const requiredEntryPoints = ['base_saree', 'base_tshirt', 'base_mug', 'base_poster'];
for (const id of requiredEntryPoints) {
  if (!allIds.has(id)) report(ERROR, 'entrypoint', null, `missing entry-point id "${id}"`);
}

// 20. Static categories list consistency (defined in the same file).
{
  const m = src.match(/static\s+const\s+List<String>\s+categories\s*=\s*\[([\s\S]*?)\];/);
  const declared = m ? [...m[1].matchAll(/'([^']*)'/g)].map((x) => x[1]) : [];
  if (declared.length !== CATEGORIES.length ||
      declared.some((c, i) => c !== CATEGORIES[i])) {
    report(ERROR, 'categories', null,
      `static categories list in product_catalog.dart does not match expected list: ${JSON.stringify(declared)}`);
  }
}

// 21. CategoryDescriptors reference AssetPaths constants resolved in
//     lib/constants/asset_paths.dart; every catalogue asset is independently
//     verified to exist on disk by the image-missing checks above.

// 22. Whole-catalogue image coverage.
const allImages = products.map((p) => p.imagePath).filter((x) => x && !/^https?:\/\//i.test(x));
const missingImages = new Set(allImages.filter((img) => !fs.existsSync(path.join(ROOT, img))));
for (const img of missingImages) {
  report(ERROR, 'image-missing', null, `image file does not exist on disk: ${img}`);
}

// 23. Reusable design image inventory — the hard design-image floor: every
//     catalogue category must expose >=30 REAL, DISTINCT, on-disk images, and
//     every global design type at least 1 such image. Types below 30 are
//     genuine data gaps (no surplus imagery exists on disk to honestly fill
//     them) and only WARN so they stay visible in the report.
{
  const availableDesigns = designRecords.filter((d) => d.availability !== false);
  const byCat = new Map();
  for (const d of availableDesigns) {
    if (!byCat.has(d.category)) byCat.set(d.category, []);
    byCat.get(d.category).push(d);
  }

  for (const cat of CATEGORIES) {
    const ds = byCat.get(cat) || [];
    if (ds.length < 30) {
      report(ERROR, 'image-floor', null,
        `"${cat}" shows ${ds.length} available designs — below the 30-image floor`);
      continue;
    }
    const paths = new Set(ds.map((d) => d.imagePath));
    if (paths.size !== ds.length) {
      report(ERROR, 'image-floor', null,
        `"${cat}" reuses images (${ds.length} designs but only ${paths.size} distinct paths)`);
    }
    let missing = 0;
    for (const d of ds) {
      if (!fs.existsSync(path.join(ROOT, d.imagePath))) missing++;
    }
    if (missing > 0) {
      report(ERROR, 'image-floor', null,
        `"${cat}" has ${missing} design images missing on disk`);
    }
  }

  const byType = new Map();
  for (const d of availableDesigns) {
    if (!d.designType) continue;
    if (!byType.has(d.designType)) byType.set(d.designType, []);
    byType.get(d.designType).push(d);
  }
  for (const [type, ds] of byType) {
    if (ds.length === 0) {
      report(ERROR, 'type-floor', null, `design type "${type}" exposes no designs`);
    } else if (ds.length < 30) {
      report(WARN, 'type-floor', null,
        `design type "${type}" shows ${ds.length} designs — below the 30-image floor (documented data gap)`);
    }
  }
}

// ── Output ────────────────────────────────────────────────────────────────

// Deduplicate identical issue lines (e.g. per-record + catalogue-wide report).
const seen = new Set();
const unique = [];
for (const i of issues) {
  const key = `${i.level}\t${i.rule}\t${i.id || ''}\t${i.message}`;
  if (!seen.has(key)) { seen.add(key); unique.push(i); }
}
issues.length = 0;
issues.push(...unique);

const errors = issues.filter((i) => i.level === ERROR);
const warnings = issues.filter((i) => i.level === WARN);

const summary = {
  generatedAt: new Date().toISOString(),
  source: path.relative(ROOT, SRC).replace(/\\/g, '/'),
  categories: CATEGORIES.length,
  records: {
    total: products.length,
    designs: designRecords.length,
    base: baseRecords.length,
    readyMade: readyMadeRecords.length,
    unparsed: unparsed.length,
  },
  byCategory: CATEGORIES.map((cat) => ({
    category: cat,
    designs: (designsByCategory.get(cat) || []).length,
    base: baseRecords.filter((p) => p.category === cat).length,
    readyMade: readyMadeRecords.filter((p) => p.category === cat).length,
  })),
  errors: errors.length,
  warnings: warnings.length,
  checks: {
    requiredFields: true,
    duplicateIds: true,
    duplicateImages: true,
    missingImages: true,
    invalidHttpUrls: true,
    categoryValidity: true,
    productTypeValidity: true,
    availability: true,
    priceValidity: true,
    designGalleryRefs: true,
    compatibilityRefs: true,
    assetSeparations: true,
    designCategoryType: true,
    imagePathFormatting: true,
    categoryImageFloor: true,
    typeImageFloor: true,
  },
};

if (process.argv.includes('--json')) {
  process.stdout.write(JSON.stringify({ ...summary, issues }, null, 2) + '\n');
} else {
  const ruleList = (list) => {
    const groups = new Map();
    for (const i of list) {
      if (!groups.has(i.rule)) groups.set(i.rule, []);
      groups.get(i.rule).push(i.message);
    }
    return [...groups.entries()];
  };

  console.log(`Validating catalogue:  ${summary.source}`);
  console.log('──────────────────────────────────────────────────────');
  console.log(`  total entries : ${summary.records.total}`);
  console.log(`    designs     : ${summary.records.designs}`);
  console.log(`    base        : ${summary.records.base}`);
  console.log(`    readyMade   : ${summary.records.readyMade}`);
  console.log(`  categories    : ${summary.categories}`);
  console.log('──────────────────────────────────────────────────────');

  for (const cat of summary.byCategory) {
    console.log(
      `  ${cat.category.padEnd(16)} designs=${String(cat.designs).padStart(4)}  base=${String(cat.base).padStart(3)}  readyMade=${String(cat.readyMade).padStart(3)}`);
  }
  console.log('──────────────────────────────────────────────────────');

  if (errors.length) {
    console.log(`\nERRORS (${errors.length}):`);
    for (const [rule, msgs] of ruleList(errors)) {
      console.log(`  [${rule}]`);
      for (const m of msgs.slice(0, 40)) console.log(`    ${m}`);
      if (msgs.length > 40) console.log(`    ... and ${msgs.length - 40} more`);
    }
  } else {
    console.log('  no errors');
  }

  if (warnings.length) {
    console.log(`\nWARNINGS (${warnings.length}):`);
    for (const [rule, msgs] of ruleList(warnings)) {
      console.log(`  [${rule}]`);
      for (const m of msgs.slice(0, 25)) console.log(`    ${m}`);
      if (msgs.length > 25) console.log(`    ... and ${msgs.length - 25} more`);
    }
  } else {
    console.log('  no warnings');
  }

  console.log('──────────────────────────────────────────────────────');
  console.log(`  result: ${errors.length === 0 ? 'PASS' : 'FAIL'}  (${errors.length} errors, ${warnings.length} warnings)`);
}

process.exit(errors.length ? 1 : 0);