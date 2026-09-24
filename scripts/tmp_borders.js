const fs = require('fs');
const path = require('path');
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
function walk(dir) { let out = []; for (const e of fs.readdirSync(dir, { withFileTypes: true })) { const p = path.join(dir, e.name); if (e.isDirectory()) out = out.concat(walk(p)); else out.push(p.replace(/\\/g,'/')); } return out; }
// products/borders files
const pb = walk(path.join(ROOT,'assets/images/products/borders')).map(f => 'lib/' + f.replace('D:/src/my_print_shop/',''));
const freePb = pb.filter(f => !refs.has(f));
console.log('products/borders on disk:', pb.length, '| referenced:', pb.length - freePb.length, '| FREE:', freePb.length);
console.log('FREE product-border files:'); freePb.forEach(f=>console.log('  '+f.split('/').pop()));
// Referenced border-product images (the base products)
console.log('Referenced product-border files:'); pb.filter(f=>refs.has(f)).forEach(f=>console.log('  '+f.split('/').pop()));
