import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const packageDir = dirname(fileURLToPath(new URL('../package.json', import.meta.url)));
const distDir = join(packageDir, 'dist');
const bundlePath = join(distDir, 'cookiy.bundle.cjs');

export async function buildBundle() {
  mkdirSync(distDir, { recursive: true });

  await build({
    entryPoints: [join(packageDir, 'bin', 'cli.mjs')],
    outfile: bundlePath,
    bundle: true,
    platform: 'node',
    format: 'cjs',
    target: ['node20'],
    logLevel: 'info',
  });

  return bundlePath;
}

if (import.meta.url === new URL(process.argv[1], 'file:').href) {
  await buildBundle();
}
