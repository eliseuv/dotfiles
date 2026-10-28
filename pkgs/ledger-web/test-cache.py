"""Check source filtering and dependency caching without building or switching."""
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[2]


def nix(expression):
    return json.loads(subprocess.check_output(
        ['nix', 'eval', '--impure', '--json', '--expr', expression], text=True))


pin = json.loads((ROOT / 'pkgs/ledger-web/pin.json').read_text())
url = urlparse(pin['url'])
assert url.scheme == 'file', 'Run this on the host holding the pinned service repository'
archive = subprocess.check_output(['git', '-C', unquote(url.path), 'archive', pin['rev']])

with tempfile.TemporaryDirectory(prefix='ledger-cache-test-') as directory:
    source = Path(directory) / 'source'
    source.mkdir()
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(source, filter='data')

    def evaluate():
        return nix(f'''let
          flake = builtins.getFlake {json.dumps(str(ROOT))};
          pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
          package = import (flake.outPath + "/pkgs/ledger-web") {{
            inherit pkgs;
            inherit (flake.inputs) crane;
            src = builtins.path {{ path = {json.dumps(str(source))}; name = "ledger-cache-test-source"; }};
          }};
        in {{
          bin = package.bin.drvPath;
          deps = package.bin.cargoArtifacts.drvPath;
          frontend = package.webUi.drvPath;
          backendSource = toString package.bin.src;
          frontendSource = toString package.webUi.src;
        }}''')

    baseline = evaluate()
    # Each case states which build derivations must change: backend, deps, UI.
    cases = [
        ('ledger-web/src/main.rs', '\n// Application source probe.\n', (True, False, False)),
        ('ledger-core/src/lib.rs', '\n// Library source probe.\n', (True, False, False)),
        ('ledger-tui/src/bin/categorize.rs', '\n// Workspace member probe.\n', (True, False, False)),
        ('ledger-core/vendor/office-crypto/src/lib.rs', '\n// Vendored source probe.\n', (True, False, False)),
        ('ledger-core/src/fixtures/cache-probe.json', '{"probe": true}\n', (True, False, False)),
        ('Cargo.lock', '\n# Lockfile probe.\n', (True, True, False)),
        ('ledger-web/Cargo.toml', '\n[features]\ncache-regression-probe = []\n', (True, True, False)),
        ('.cargo/config.toml', '# Cargo configuration probe.\n', (True, True, False)),
        ('ledger-web-ui/src/App.tsx', '\n// Frontend source probe.\n', (False, False, True)),
        ('ledger-web-ui/package-lock.json', '\n', (False, False, True)),
        ('ledger-web-ui/vite.config.ts', '\n// Vite configuration probe.\n', (False, False, True)),
        ('ledger-web-ui/tsconfig.app.json', '\n', (False, False, True)),
        ('ledger-web-ui/public/cache-probe.txt', 'Public asset probe.\n', (False, False, True)),
        ('README.md', '\nDocumentation probe.\n', (False, False, False)),
        ('ledger-core/vendor/office-crypto/README.md', '\nCrate documentation probe.\n', (False, False, False)),
        ('ledger-web-ui/README.md', '\nUI documentation probe.\n', (False, False, False)),
        ('docs/source-filter-probe/example.rs', '// Unrelated directory probe.\n', (False, False, False)),
        ('scripts/source-filter-probe.sh', '# Development script probe.\n', (False, False, False)),
        ('ledger-web-ui/tests/cache-probe.mjs', '// Browser test probe.\n', (False, False, False)),
        ('ledger-web-ui/dist/cache-probe.js', '// Generated output probe.\n', (False, False, False)),
    ]
    for relative, suffix, expected in cases:
        path = source / relative
        original = path.read_text() if path.exists() else None
        path.parent.mkdir(parents=True, exist_ok=True)
        try:
            path.write_text((original or '') + suffix)
            changed = evaluate()
            actual = tuple(changed[key] != baseline[key] for key in ('bin', 'deps', 'frontend'))
            assert actual == expected, f'{relative}: expected backend/deps/UI={expected}, got {actual}'
        finally:
            if original is None:
                path.unlink()
            else:
                path.write_text(original)
        print(f'PASS: {relative}: backend/deps/UI invalidation={actual}', flush=True)

    backend = Path(baseline['backendSource'])
    frontend = Path(baseline['frontendSource'])
    for required in ['Cargo.toml', 'Cargo.lock', 'ledger-core/src/lib.rs',
                     'ledger-core/vendor/office-crypto/Cargo.toml',
                     'ledger-core/vendor/office-crypto/LICENSE',
                     'ledger-web/src/main.rs', 'ledger-tui/src/bin/categorize.rs']:
        assert (backend / required).is_file(), f'Missing backend input: {required}'
    for required in ['src/App.tsx', 'index.html', 'package.json', 'package-lock.json',
                     'tsconfig.json', 'tsconfig.app.json', 'tsconfig.node.json', 'vite.config.ts']:
        assert (frontend / required).is_file(), f'Missing frontend input: {required}'
    assert not (backend / 'ledger-web-ui').exists()
    assert not (frontend / 'tests').exists()
    print('PASS: filtered sources retain required build inputs and vendored license', flush=True)

    retention = nix(f'''let
      flake = builtins.getFlake {json.dumps(str(ROOT))};
      config = flake.nixosConfigurations.wheatley.config;
      artifacts = config.homelab.ledger.package.bin.cargoArtifacts;
    in builtins.elem (toString artifacts) (map toString config.system.extraDependencies)''')
    assert retention, 'Wheatley must retain dependency artifacts through garbage collection'
    print('PASS: Wheatley system retains dependency artifacts through GC', flush=True)
