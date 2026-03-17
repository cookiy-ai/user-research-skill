import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync, chmodSync } from 'node:fs';
import { arch, platform } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { buildBundle } from './build-bundle.mjs';

const packageDir = dirname(fileURLToPath(new URL('../package.json', import.meta.url)));
const distDir = join(packageDir, 'dist');
const releaseDir = join(distDir, 'release');
const binaryName = 'cookiy';
const nodeSeaFuse = 'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2';

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: packageDir,
    encoding: 'utf8',
    stdio: 'pipe',
    ...options,
  });

  if (result.status !== 0) {
    const stderr = result.stderr?.trim();
    const stdout = result.stdout?.trim();
    throw new Error([
      `Command failed: ${command} ${args.join(' ')}`,
      stderr || stdout || `exit code ${result.status}`,
    ].join('\n'));
  }

  return result;
}

function tryRemoveSignature(binaryPath) {
  const result = spawnSync('codesign', ['--remove-signature', binaryPath], {
    cwd: packageDir,
    encoding: 'utf8',
    stdio: 'pipe',
  });

  if (result.status === 0) return;

  const stderr = result.stderr?.toLowerCase() || '';
  if (stderr.includes('is not signed at all') || stderr.includes('code object is not signed at all')) {
    return;
  }

  throw new Error(`Failed to remove code signature from ${binaryPath}: ${result.stderr?.trim() || result.stdout?.trim()}`);
}

function hasSeaFuse(binaryPath) {
  const result = spawnSync('strings', [binaryPath], {
    cwd: packageDir,
    encoding: 'utf8',
    stdio: 'pipe',
  });

  if (result.status !== 0) return false;
  return result.stdout.includes(nodeSeaFuse);
}

function resolveSeaNodeBinary() {
  const candidates = [process.execPath];
  const whichResult = spawnSync('which', ['node'], {
    cwd: packageDir,
    encoding: 'utf8',
    stdio: 'pipe',
  });

  if (whichResult.status === 0) {
    const shellNode = whichResult.stdout.trim();
    if (shellNode) candidates.push(shellNode);
  }

  for (const candidate of candidates) {
    if (candidate && existsSync(candidate) && hasSeaFuse(candidate)) {
      return candidate;
    }
  }

  throw new Error(
    'Could not find a SEA-capable Node binary. Run the build with Node 20/22 LTS, or set COOKIY_SEA_NODE_BINARY to a Node executable that contains the SEA fuse.',
  );
}

async function main() {
  if (platform() !== 'darwin') {
    throw new Error('macOS binary build is only supported on darwin hosts.');
  }

  const bundlePath = await buildBundle();
  const packageJson = JSON.parse(readFileSync(join(packageDir, 'package.json'), 'utf8'));
  const targetArch = arch() === 'arm64' ? 'arm64' : 'x64';
  const archLabel = targetArch === 'x64' ? 'amd64' : targetArch;
  const seaNodeBinary = process.env.COOKIY_SEA_NODE_BINARY || resolveSeaNodeBinary();
  const binaryPath = join(distDir, binaryName);
  const blobPath = join(distDir, 'cookiy.sea.blob');
  const seaConfigPath = join(distDir, 'sea-config.json');
  const archiveName = `${binaryName}-v${packageJson.version}-darwin-${archLabel}.tar.gz`;
  const archivePath = join(distDir, archiveName);
  const stageDir = join(releaseDir, `${binaryName}-darwin-${archLabel}`);
  const stageBinaryPath = join(stageDir, binaryName);
  const checksumPath = `${archivePath}.sha256`;
  const postjectPath = join(packageDir, 'node_modules', '.bin', 'postject');

  if (!existsSync(postjectPath)) {
    throw new Error('Missing local postject binary. Run npm install in packages/tools/cookiy-mcp-setup first.');
  }

  rmSync(releaseDir, { recursive: true, force: true });
  mkdirSync(releaseDir, { recursive: true });

  writeFileSync(seaConfigPath, JSON.stringify({
    main: bundlePath,
    output: blobPath,
    disableExperimentalSEAWarning: true,
    useCodeCache: false,
    useSnapshot: false,
  }, null, 2));

  run(seaNodeBinary, ['--experimental-sea-config', seaConfigPath]);

  rmSync(binaryPath, { force: true });
  copyFileSync(seaNodeBinary, binaryPath);
  chmodSync(binaryPath, 0o755);
  tryRemoveSignature(binaryPath);

  run(postjectPath, [
    binaryPath,
    'NODE_SEA_BLOB',
    blobPath,
    '--sentinel-fuse',
    nodeSeaFuse,
    '--macho-segment-name',
    'NODE_SEA',
  ]);

  run('codesign', ['--sign', '-', binaryPath]);
  chmodSync(binaryPath, 0o755);

  mkdirSync(stageDir, { recursive: true });
  cpSync(binaryPath, stageBinaryPath);
  chmodSync(stageBinaryPath, 0o755);

  run('tar', ['-czf', archivePath, '-C', stageDir, binaryName]);

  const checksum = run('shasum', ['-a', '256', archivePath]).stdout.trim();
  writeFileSync(checksumPath, `${checksum}\n`);

  console.log(`SEA Node binary: ${seaNodeBinary}`);
  console.log(`Built macOS binary: ${binaryPath}`);
  console.log(`Packaged artifact: ${archivePath}`);
  console.log(`SHA256: ${checksumPath}`);
}

await main();
