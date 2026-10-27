import json
import os
from pathlib import Path
import subprocess
import tempfile
import sys

MODULE = Path(__file__).with_name('deploy.nix')
CLIENT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home()/'Projects/project/ledger/scripts/deploy.sh'

def run(*args, **kwargs):
    return subprocess.run(args, text=True, check=True, capture_output=True, **kwargs).stdout

with tempfile.TemporaryDirectory(prefix='ledger-deploy-test-') as directory:
    root = Path(directory)
    state = root/'state'
    state.mkdir()
    (state/'protocol-version').write_text('1\n')
    dotfiles = root/'dotfiles'
    (dotfiles/'pkgs/ledger-web').mkdir(parents=True)
    mock = root/'mock/bin'
    mock.mkdir(parents=True)
    def executable(name, body):
        target = mock/name
        target.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body)
        target.chmod(0o755)
    executable('git', 'echo "$TEST_REV"\n')
    executable('id', 'echo 1000\n')
    executable('just', '''
if [ "$1" = pin-service ]; then
  [ "${FAIL_PIN:-0}" = 0 ] || exit 12
  printf '{"rev":"%s"}\\n' "${PIN_REV:-$TEST_REV}" > pkgs/ledger-web/pin.json
else
  [ "${FAIL_BOOKKEEPING:-0}" = 0 ] || exit 13
fi
''')
    executable('nixos-rebuild', 'echo activated > "$TEST_ROOT/activated"; [ "${FAIL_BUILD:-0}" = 0 ]\n')
    executable('curl', '[ "${FAIL_HEALTH:-0}" = 0 ] || exit 22; echo "[]"\n')
    executable('systemctl', 'exit 0\n')
    executable('su', 'exec /bin/sh -c "$4"\n')
    executable('sleep', ':\n')
    jq = Path(run('which', 'jq').strip()).resolve().parent.parent
    expression = f'''let
      module = import {MODULE} {{
        config = {{
          my.dotfiles.path = "{dotfiles}";
          my.host.primaryUser = "test";
          my.host.name = "wheatley";
          users.users.test.home = "{root}/home";
          homelab.services.ledger.port = 3001;
          nix.package = "{root}/mock";
        }};
        pkgs = {{
          writeShellScript = name: body: body;
          jq = "{jq}";
          git = "{root}/mock";
          coreutils = "{root}/mock";
          just = "{root}/mock";
          nixos-rebuild = "{root}/mock";
          curl = "{root}/mock";
          systemd = "{root}/mock";
        }};
      }};
    in {{
      script = module.systemd.services.ledger-deploy.serviceConfig.ExecStart;
      activation = module.system.activationScripts.ledgerDeployHook;
      restartIfChanged = module.systemd.services.ledger-deploy.restartIfChanged;
    }}'''
    module = json.loads(run('nix-instantiate', '--eval', '--strict', '--json', '--expr', expression))
    assert module['restartIfChanged'] is False
    script = module['script'].replace('/run/ledger-deploy', str(state)).replace('/run/wrappers/bin/su', str(mock/'su'))
    server = root/'server.sh'
    server.write_text(script)
    # The activation output contains the hook body in place of the mock
    # writeShellScript's return value.
    hook = module['activation'].split('install -Dm755 ', 1)[1].rsplit(f' {root}/home/Services/ledger/.git/hooks/post-receive', 1)[0]
    hook = hook.replace('/run/ledger-deploy', str(state))
    hookfile = root/'hook.sh'
    hookfile.write_text(hook)
    for file in (server, hookfile):
        run('bash', '-n', str(file))
        lint = subprocess.run(['shellcheck', '-s', 'bash', str(file)], text=True, capture_output=True)
        assert lint.returncode == 0, lint.stdout + lint.stderr
    zeros = '0'*40
    rev = 'a'*40
    run('bash', str(hookfile), input=f'{zeros} {rev} refs/heads/feature\n')
    assert not (state/'trigger').exists()
    run('bash', str(hookfile), input=f'{rev} {zeros} refs/heads/main\n')
    assert not (state/'trigger').exists()
    run('bash', str(hookfile), input=f'{zeros} {rev} refs/heads/main\n')
    queued_rev, request = (state/'trigger').read_text().split()
    assert queued_rev == rev and len(request) == 36
    print('PASS: hook ignores feature branches/deletions and queues main with a request ID')
    base_env = dict(os.environ, PATH=f'{mock}:'+os.environ['PATH'], TEST_ROOT=str(root), TEST_REV=rev)
    cases = [({}, 'succeeded', 'bookkeeping', True),
             ({'FAIL_PIN':'1'}, 'failed', 'pin', False),
             ({'PIN_REV':'b'*40}, 'failed', 'pin', False),
             ({'FAIL_BUILD':'1'}, 'failed', 'activate', True),
             ({'FAIL_HEALTH':'1'}, 'failed', 'health', True),
             ({'FAIL_BOOKKEEPING':'1'}, 'succeeded-with-warning', 'bookkeeping', True),
             ({'TEST_REV':'b'*40}, 'failed', 'pin', False)]
    for overrides, expected, phase, activated in cases:
        (root/'activated').unlink(missing_ok=True)
        result = subprocess.run(['bash', str(server)], env=base_env|overrides, capture_output=True, text=True)
        status = json.loads((state/'status.json').read_text())
        assert status == dict(rev=rev, request=request, state=expected, phase=phase), (overrides, result.stderr, status)
        assert (result.returncode == 0) == expected.startswith('succeeded'), (overrides, result.stderr)
        assert (root/'activated').exists() == activated
        print(f'PASS: {overrides or "normal deployment"} -> {expected} ({phase})')
    print('All deployment hook and pipeline scenarios passed.')

    # Exercise the client with real local Git pushes; substitute only the
    # expensive checks, systemd and the API outside this isolated fixture.
    clientbin = root/'client-bin'
    clientbin.mkdir()
    def client_executable(name, body):
        file = clientbin/name
        file.write_text('#!/usr/bin/env bash\nset -euo pipefail\n'+body)
        file.chmod(0o755)
    client_executable('just', 'echo "$1" >> "$TEST_ROOT/checks"\n')
    client_executable('npm', 'echo "npm $*" >> "$TEST_ROOT/checks"\n')
    client_executable('systemctl', 'exit 0\n')
    client_executable('curl', 'echo "[]"\n')
    client_executable('sleep', '''
read -r rev request < "$TEST_ROOT/state/trigger"
jq -n --arg rev "$rev" --arg request "$request" --arg state "${RESULT_STATE:-succeeded}" \\
  '{rev:$rev, request:$request, state:$state, phase:"health"}' > "$TEST_ROOT/state/status.json"
''')
    clientrepo = root/'client'
    servicerepo = root/'service'
    realgit = run('which', 'git').strip()
    def git(*args, repo=clientrepo):
        return run(realgit, '-C', str(repo), *args)
    clientrepo.mkdir()
    git('init', '-b', 'main')
    git('config', 'user.name', 'Test')
    git('config', 'user.email', 'test@example.invalid')
    (clientrepo/'scripts').mkdir()
    (clientrepo/'ledger-web-ui').mkdir()
    clientfile = clientrepo/'scripts/deploy.sh'
    body = CLIENT.read_text().replace('state_dir=/run/ledger-deploy', f'state_dir={state}')
    body = body.replace('service_repo="$HOME/Services/ledger"', f'service_repo={servicerepo}')
    clientfile.write_text(body)
    clientfile.chmod(0o755)
    (clientrepo/'README').write_text('initial\n')
    git('add', '.')
    git('commit', '-m', 'initial')
    run(realgit, 'clone', str(clientrepo), str(servicerepo))
    git('config', 'receive.denyCurrentBranch', 'updateInstead', repo=servicerepo)
    git('config', 'receive.denyNonFastForwards', 'true', repo=servicerepo)
    git('remote', 'add', 'deploy', str(servicerepo))
    receive = servicerepo/'.git/hooks/post-receive'
    receive.write_text('#!/usr/bin/env bash\n'+hook)
    receive.chmod(0o755)
    env = dict(os.environ, PATH=f'{clientbin}:'+os.environ['PATH'], TEST_ROOT=str(root))
    (state/'protocol-version').unlink()
    result = subprocess.run(['bash', str(clientfile)], capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'activate the updated host config' in result.stderr, result.stderr
    (state/'protocol-version').write_text('1\n')
    print('PASS: client refuses to push to an outdated deployment watcher')
    initial = git('rev-parse', 'HEAD').strip()
    (clientrepo/'README').write_text('release\n')
    result = subprocess.run(['bash', str(clientfile)], capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'commit or stash' in result.stderr, result.stderr
    assert not (root/'checks').exists()
    print('PASS: client rejects dirty development checkout before checks or push')
    git('add', 'README')
    git('commit', '-m', 'release')
    result = subprocess.run(['bash', str(clientfile)], capture_output=True, text=True, env=env)
    assert result.returncode == 0 and 'deployed and healthy' in result.stdout, result.stderr
    assert git('rev-parse', 'HEAD') == git('rev-parse', 'HEAD', repo=servicerepo)
    first_request = (state/'trigger').read_text().split()[1]
    print('PASS: client checks, fast-forwards Services/main and waits for matching health result')
    result = subprocess.run(['bash', str(clientfile)], capture_output=True, text=True, env=env)
    assert result.returncode == 0, result.stderr
    assert first_request != (state/'trigger').read_text().split()[1]
    print('PASS: retry of unchanged commit queues a fresh request')
    result = subprocess.run(['bash', str(clientfile)], capture_output=True, text=True, env=env|{'RESULT_STATE':'succeeded-with-warning'})
    assert result.returncode == 0 and 'Warning:' in result.stdout, result.stderr
    print('PASS: bookkeeping warning is shown without claiming application deployment failed')
    result = subprocess.run(['bash', str(clientfile)], capture_output=True, text=True, env=env|{'RESULT_STATE':'failed'})
    assert result.returncode != 0 and 'health failed' in result.stderr, result.stderr
    print('PASS: matching failed request returns nonzero with diagnostic command')
    result = subprocess.run([realgit, '-C', str(clientrepo), 'push', '--force', 'deploy', f'{initial}:refs/heads/main'], capture_output=True, text=True)
    assert result.returncode != 0 and 'non-fast-forward' in result.stderr, result.stderr
    assert git('rev-parse', 'HEAD') == git('rev-parse', 'HEAD', repo=servicerepo)
    print('PASS: receiving repository rejects forced non-fast-forward deployment')
    (servicerepo/'uncommitted').write_text('dirty\n')
    result = subprocess.run(['bash', str(clientfile)], capture_output=True, text=True, env=env)
    assert result.returncode != 0 and 'Services/ledger has uncommitted' in result.stderr, result.stderr
    print('PASS: client refuses a dirty Services checkout')
    print('All deployment client scenarios passed.')
