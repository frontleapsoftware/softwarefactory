#!/usr/bin/env node
/**
 * Local Factory + Studio development server.
 *
 * `mastra factory` disables Studio so Factory can own `/`. We run plain
 * `mastra` `dev` (Studio enabled) with Factory UI pointed at the CLI-bundled
 * assets, and `server.studioBase = '/studio'` keeps Studio on a subpath.
 */
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const mastraPkg = dirname(require.resolve('mastra/package.json'));
const factoryUi = join(mastraPkg, 'dist', 'factory');

const env = { ...process.env };
if (!env.MASTRACODE_UI_DIST && existsSync(join(factoryUi, 'index.html'))) {
  env.MASTRACODE_UI_DIST = factoryUi;
}

const child = spawn(
  process.execPath,
  [join(mastraPkg, 'dist', 'index.js'), 'dev', '--dir', 'src/mastra', ...process.argv.slice(2)],
  { stdio: 'inherit', env },
);

child.on('exit', code => {
  process.exit(code ?? 1);
});
