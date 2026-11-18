
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const src = path.join(root, 'src');
const out = path.join(root, 'public');

function required(file) {
  if (!fs.existsSync(file)) {
    throw new Error(`Required file missing: ${file}`);
  }
}

required(path.join(src, 'application.html'));
required(path.join(src, 'launcher.js'));

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });

// Copy source assets, scripts, vendor files and application files.
function copyDirectory(source, destination) {
  fs.mkdirSync(destination, { recursive: true });

  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    if (entry.name === '.gitkeep') continue;

    const from = path.join(source, entry.name);
    const to = path.join(destination, entry.name);

    if (entry.isDirectory()) {
      copyDirectory(from, to);
    } else {
      fs.copyFileSync(from, to);
    }
  }
}

copyDirectory(src, out);

// Use the application as the root page.
// Keep application.html available as a separate route too.
fs.copyFileSync(
  path.join(src, 'application.html'),
  path.join(out, 'application.html')
);

fs.copyFileSync(
  path.join(src, 'application.html'),
  path.join(out, 'index.html')
);

console.log('ATW Source build completed.');
console.log('Application source: src/application.html');
console.log('Published: public/index.html and public/application.html');
