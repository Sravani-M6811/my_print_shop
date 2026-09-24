const fs = require('fs');
const path = require('path');

const ROOT = process.env.PROJECT_ROOT || 'D:/src/my_print_shop';
const SRC = path.join(ROOT, 'lib/data/product_catalog.dart');
const OUT = path.join(ROOT, 'scripts/catalog_records.json');

const src = fs.readFileSync(SRC, 'utf8');
const lines = src.split('\n');

// Locate the big `static final List<Product> products = [ ... ];` block.
let listStart = -1;
for (let i = 0; i < lines.length; i++) {
  if (/^\s*static\s+final\s+List<Product>\s+products\s*=\s*\[/.test(lines[i])) {
    listStart = i;
    break;
  }
}
if (listStart === -1) {
  console.error('could not locate products list');
  process.exit(1);
}

// Strip quoted strings from a line so paren/bracket counting ignores them.
function stripStrings(line) {
  return line.replace(/'(?:[^'\\]|\\.)*'/g, "''").replace(/"(?:[^"\\]|\\.)*"/g, '""');
}

function delta(s, open, close) {
  let n = 0;
  for (const ch of s) {
    if (ch === open) n++;
    else if (ch === close) n--;
  }
  return n;
}

// Find the end of the products list: the `];` at depth 0 following listStart.
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
    if (depth <= 0) {
      listEnd = i;
      break;
    }
  }
}
console.log('products list lines:', listStart + 1, '..', listEnd + 1);

// Extract each `    Product(` ... `    ),` block within the list.
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
console.log('detected blocks:', blocks.length);

const CAT_FOLDER = {
  'Sarees': 'sarees',
  'Dress Materials': 'dress_materials',
  'Saree Borders': 'borders',
  'T-Shirts': 'tshirts',
  'Mugs': 'mugs',
  'Posters': 'posters',
  'Embroidery': 'embroidery',
  'Cardboard': 'cardboard',
  'Glass Art': 'glass_art',
};

const CAT_TERM = {
  'Sarees': 'saree',
  'Dress Materials': 'dress material',
  'Saree Borders': 'saree border',
  'T-Shirts': 't-shirt',
  'Mugs': 'mug',
  'Posters': 'poster',
  'Embroidery': 'embroidery',
  'Cardboard': 'cardboard',
  'Glass Art': 'glass art',
};

const DESIGN_KIND = {
  'Sarees': 'print pattern',
  'Dress Materials': 'print pattern fabric',
  'Saree Borders': 'border pattern',
  'T-Shirts': 'graphic design',
  'Mugs': 'art design',
  'Posters': 'art design',
  'Embroidery': 'embroidery design',
  'Cardboard': 'design template',
  'Glass Art': 'art design',
};

const STOP = [
  'custom', 'customizable', 'customised', 'customized', 'print', 'prints',
  'printed', 'printing', 'premium', 'elegant', 'beautiful', 'stylish',
  'luxury', 'fancy', 'various', 'available', 'the', 'a', 'an', 'with',
  'for', 'on', 'and', 'of', 'in', 'set', 'sets', 'ready', 'made', 'make',
  'your', 'its', 'just', 'new', 'only', 'one', '1', '2', '3', 'wide',
  'size', 'sizes', 'edition', 'check', 'out', 'buy', 'off', 'online',
  'base', 'basic', 'item', 'items', 'thing', 'dh', 'sq', 'inch', 'inches',
];

function cleanTokens(name) {
  const t = name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ');
  const seen = new Set();
  const out = [];
  for (const w of t) {
    if (!w) continue;
    if (!/^[a-z0-9-]+$/.test(w)) continue;
    if (STOP.includes(w)) continue;
    if (seen.has(w)) continue;
    seen.add(w);
    out.push(w);
  }
  return out;
}

function tokens(q) {
  return q.toLowerCase().replace(/-/g, ' ').replace(/\s+/g, ' ').trim().split(' ');
}

function buildQuery(r, folder) {
  let nameTokens = cleanTokens(r.name);
  const catTerm = CAT_TERM[r.category] || r.category.toLowerCase();
  const catTokens = tokens(catTerm);
  const parts = [];
  if (folder === 'product') {
    if (r.productType === 'base') {
      // Remove any "plain/blank" words already in the name, then add exactly
      // one base-style qualifier so the query reads "plain <material> <item>".
      nameTokens = nameTokens.filter((w) => w !== 'plain' && w !== 'blank');
      const baseWord = r.category === 'Cardboard' ? 'blank' : 'plain';
      parts.push(baseWord);
    }
    parts.push(...nameTokens);
    for (const t of catTokens) {
      if (!parts.some((w) => w === t)) parts.push(t);
    }
  } else {
    parts.push(...nameTokens);
    const kind = DESIGN_KIND[r.category];
    if (kind) {
      for (const t of tokens(kind)) {
        if (!parts.some((w) => w === t)) parts.push(t);
      }
    }
    for (const t of catTokens) {
      if (!parts.some((w) => w === t)) parts.push(t);
    }
  }
  const q = parts.join(' ').replace(/\s+/g, ' ');
  return q.length > 120 ? q.slice(0, 120) : q;
}

function slug(name) {
  const t = name.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
  return t.replace(/\s/g, '_');
}

const records = [];
const usedNames = new Map();
let parsed = 0;
let unparsed = 0;
const problems = [];

for (const b of blocks) {
  const blockLines = lines.slice(b.start, b.end + 1);
  const text = blockLines.join('\n');
  const g = (re) => {
    const m = text.match(re);
    return m ? m[1].replace(/\\'/g, "'") : '';
  };
  const id = g(/id\s*:\s*'([^']*)'/);
  if (!id) { unparsed++; problems.push({ start: b.start + 1, issue: 'no id' }); continue; }
  const name = g(/name\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const category = g(/category\s*:\s*'([^']*)'/);
  const mSub = text.match(/subcategory\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const subcategory = mSub ? mSub[1] : '';
  const mPt = text.match(/productType\s*:\s*'([^']*)'/);
  const productType = mPt ? mPt[1] : 'design';
  const mDt = text.match(/designType\s*:\s*'((?:[^'\\]|\\.)*)'/);
  const designType = mDt ? mDt[1] : '';
  const mTags = text.match(/tags\s*:\s*\[([^\]]*)\]/);
  const tags = mTags
    ? [...mTags[1].matchAll(/'([^']*)'/g)].map((x) => x[1])
    : [];
  const folder = (productType === 'base' || productType === 'readyMade') ? 'product' : 'design';
  const folderDir = CAT_FOLDER[category];
  if (!folderDir) {
    unparsed++;
    problems.push({ id, category, issue: 'unknown category' });
    continue;
  }
  parsed++;

  const base = slug(name) || `item_${id}`;
  let file = base;
  let n = 2;
  if (usedNames.has(base)) {
    file = `${base}_${n}`;
    while (usedNames.has(file)) { n++; file = `${base}_${n}`; }
  }
  usedNames.set(base, true);
  usedNames.set(file, true);
  if (file.length > 70) file = file.slice(0, 70);

  const relDir = folder === 'product'
    ? `assets/images/products/${folderDir}`
    : `assets/images/designs/${folderDir}`;
  const query = buildQuery({ name, category, productType, subcategory, designType }, folder);

  records.push({
    id,
    name,
    category,
    subcategory,
    productType,
    designType,
    tags,
    folder,
    relDir,
    file,
    targetPath: `${relDir}/${file}.jpg`,
    query,
  });
}

records.sort((a, b) => a.id.localeCompare(b.id));
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify({ generatedAt: new Date().toISOString(), records }, null, 2), 'utf8');

console.log('records:', records.length, '| unparsed:', unparsed);
const byCat = {};
const byType = {};
for (const r of records) {
  byCat[r.category] = (byCat[r.category] || 0) + 1;
  byType[r.folder] = (byType[r.folder] || 0) + 1;
}
console.log('by category:', byCat);
console.log('by folder:', byType);
if (problems.length) {
  console.log('PROBLEMS:');
  problems.forEach((p) => console.log('  ', JSON.stringify(p)));
}
// duplicate name check for logging
const dupFile = records.filter((r, i) => records.findIndex((x) => x.file === r.file) !== i);
console.log('duplicate target filenames (resolved):', dupFile.length);
dupFile.slice(0, 20).forEach((d) => console.log('  ', d.id, d.file));