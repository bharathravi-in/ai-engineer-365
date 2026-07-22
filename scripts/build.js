const fs = require('fs');
const path = require('path');

const dist = path.join(process.cwd(), 'dist');
fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(path.join(dist, 'src'), { recursive: true });
for (const file of ['index.html', 'src/styles.css', 'src/app.js']) {
  fs.copyFileSync(path.join(process.cwd(), file), path.join(dist, file));
}
console.log('Built static site in dist/');
