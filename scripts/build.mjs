
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const src = path.join(root, 'src');
const out = path.join(root, 'public');

function required(file) {
  if (!fs.existsSync(file)) {
    throw new Error(`Required file not found: ${file}`);
  }
}

required(src);
required(path.join(src, 'application.html'));
required(path.join(src, 'index.html'));
required(path.join(src, 'launcher.js'));

fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });

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

// Copy application assets and files.
copyDirectory(src, out);

// Keep login/launcher page as the root entry point.
fs.copyFileSync(
  path.join(src, 'index.html'),
  path.join(out, 'index.html')
);

console.log('ATW Source build completed.');
console.log('Login page: public/index.html');
console.log('Application: public/application.html');
