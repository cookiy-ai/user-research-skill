import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const packageDir = dirname(fileURLToPath(new URL('../package.json', import.meta.url)));
const distDir = join(packageDir, 'dist');
const outputPath = join(distDir, 'cookiy.rb');
const packageJson = JSON.parse(readFileSync(join(packageDir, 'package.json'), 'utf8'));
const version = packageJson.version;
const releaseOwner = process.env.COOKIY_HOMEBREW_OWNER || 'cookiy-ai';
const releaseRepo = process.env.COOKIY_HOMEBREW_REPO || 'homebrew-tap';
const releaseTag = process.env.COOKIY_HOMEBREW_TAG || `cookiy-v${version}`;
const artifactName = `cookiy-v${version}-darwin-arm64.tar.gz`;
const checksumPath = join(distDir, `${artifactName}.sha256`);

if (!existsSync(checksumPath)) {
  throw new Error(`Missing checksum file: ${checksumPath}. Run npm run build:macos first.`);
}

const checksumLine = readFileSync(checksumPath, 'utf8').trim();
const checksum = checksumLine.split(/\s+/)[0];

const formula = `class Cookiy < Formula
  desc "One-command setup for Cookiy MCP server in your AI coding clients"
  homepage "https://cookiy.ai"
  version "${version}"

  on_arm do
    url "https://github.com/${releaseOwner}/${releaseRepo}/releases/download/${releaseTag}/${artifactName}"
    sha256 "${checksum}"
  end

  on_intel do
    odie "cookiy currently publishes only an Apple Silicon macOS binary. Use the npm package on Intel Macs for now."
  end

  def install
    bin.install "cookiy"
  end

  def post_install
    system bin/"cookiy", "-y"
  end

  def caveats
    <<~EOS
      The Homebrew install auto-configured Cookiy MCP for the default production environment.

      To re-run production setup later, run:
        cookiy -y

      For advanced non-production or custom targets, run:
        cookiy --help
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/cookiy --version").strip
  end
end
`;

mkdirSync(distDir, { recursive: true });
writeFileSync(outputPath, formula);
console.log(`Generated Homebrew formula: ${outputPath}`);
