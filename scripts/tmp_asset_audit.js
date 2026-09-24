const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const ROOT = 'D:/src/my_print_shop';
const src = fs.readFileSync(path.join(ROOT, 'lib/data/product_catalog.dart'), 'utf8')
  + fs.readFileSync(path.join(ROOT, 'lib/services/customer_catalogue.dart'), 'utf8');
const assetFile = fs.readFileSync(path.join(ROOT, 'lib/constants/asset_paths.dart'), 'utf8');
const constMap = {};
for (const m of assetFile.matchAll(/static const String\s+(\w+)\s*=\s*['"]([^'"]+)['"]/g)) constMap['AssetPaths.' + m[1]] = m[2];
let src2 = src;
for (const [k, v] of Object.entries(constMap)) src2 = src2.split(k).join(v);
const refs = new Set();
for (const m of src2.matchAll(/'((?:lib\/assets|assets)\/[^']+)'/g)) refs.add(m[1]);

function isJpeg(buf) { return buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8; }
function isPng(buf) { return buf.length > 7 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47; }

let badHeader = 0, tiny = 0, n = 0;
const hashes = new Map(); let dupHash = [];
for (const p of refs) {
  n++;
  const full = path.join(ROOT, p.replace(/\//g, path.sep));
  const buf = fs.readFileSync(full);
  if (!isJpeg(buf) && !isPng(buf)) { badHeader++; console.log('BAD HEADER: ' + p); }
  if (buf.length < 2048) { tiny++; console.log('TINY: ' + p + ' (' + buf.length + 'b)'); }
  const h = crypto.createHash('sha1').update(buf).digest('hex');
  if (hashes.has(h)) dupHash.push([hashes.get(h), p]); else hashes.set(h, p);
}
console.log(`checked=${n} badHeader=${badHeader} tinySmall=${tiny} sha1Check=true collidingPairs=${dupHash.length}`);
dupHash.forEach(([a,b]) => console.log('  SAME BYTES: ' + a + ' == ' + b));
