"""Check cache invalidation using real Nix derivations, without building or switching."""
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
        }}''')

    baseline = evaluate()
    cases = [
        ('ledger-web/src/main.rs', '\n// Application source cache regression probe.\n', False),
        ('ledger-core/src/lib.rs', '\n// Library source cache regression probe.\n', False),
        ('ledger-core/vendor/office-crypto/src/lib.rs', '\n// Local dependency source probe.\n', False),
        ('Cargo.lock', '\n# Lockfile cache regression probe.\n', True),
        ('ledger-web/Cargo.toml', '\n[features]\ncache-regression-probe = []\n', True),
    ]
    for relative, suffix, invalidates in cases:
        path = source / relative
        original = path.read_text()
        try:
            path.write_text(original + suffix)
            changed = evaluate()
            assert changed['bin'] != baseline['bin'], f'{relative}: application did not invalidate'
            assert (changed['deps'] != baseline['deps']) == invalidates, f'{relative}: wrong dependency invalidation'
        finally:
            path.write_text(original)
        action = 'invalidates' if invalidates else 'reuses'
        print(f'PASS: {relative} change {action} dependency cache', flush=True)

    retention = nix(f'''let
      flake = builtins.getFlake {json.dumps(str(ROOT))};
      config = flake.nixosConfigurations.wheatley.config;
      artifacts = config.homelab.ledger.package.bin.cargoArtifacts;
    in builtins.elem (toString artifacts) (map toString config.system.extraDependencies)''')
    assert retention, 'Wheatley must retain dependency artifacts through garbage collection'
    print('PASS: Wheatley system retains dependency artifacts through GC', flush=True)
