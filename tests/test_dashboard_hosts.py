"""Host API regressions. Run: python3 -m unittest discover -s tests."""
import ast
import concurrent.futures
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import types
import unittest
import unittest.mock
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "modules/nixos/homelab/dashboard"
# svcctl.py imports host_pages.py, as it does from its store directory.
sys.path.insert(0, str(DASHBOARD))


def definitions(name):
    """Load server definitions without CLI setup or starting background workers."""
    tree = ast.parse((DASHBOARD / name).read_text())
    tree.body = [node for node in tree.body if isinstance(
        node, (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef))]
    namespace = {}
    exec(compile(tree, name, "exec"), namespace)
    return namespace


class ComparisonTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.ns = definitions("host_pages.py")
        self.ns.update(
            comparison_lock=threading.Lock(), comparison_locks={},
            diffs_dir=Path(self.temp.name),
            state={"host": {"report": {"generations": [
                {"number": n, "path": f"/nix/store/hash{n}-system"}
                for n in (1, 3, 8)]}}},
        )
        self.calls = []

        def report(host, verb, base, target):
            self.calls.append((host, verb, base, target))
            time.sleep(0.01)
            return {"base": int(base), "number": int(target),
                    "base_path": f"/nix/store/hash{base}-system",
                    "path": f"/nix/store/hash{target}-system", "changes": "pkg: 1 → 2"}
        self.ns["run_report"] = report

    def test_ordered_pairs_and_identical_generation(self):
        for base, target in ((1, 3), (1, 8), (8, 1), (3, 3)):
            result = self.ns["compare"]("host", base, target)
            self.assertEqual((result["base"], result["number"]), (base, target))
        self.ns["compare"]("host", 1, 8)
        self.assertEqual(len(self.calls), 4)

    def test_concurrent_requests_share_cache(self):
        with concurrent.futures.ThreadPoolExecutor() as pool:
            results = list(pool.map(lambda _: self.ns["compare"]("host", 1, 8), range(8)))
        self.assertEqual(len(self.calls), 1)
        self.assertTrue(all(result == results[0] for result in results))

    def test_cached_paths_keep_requested_generation_numbers(self):
        self.ns["compare"]("host", 1, 8)
        self.ns["state"]["host"]["report"]["generations"].append(
            {"number": 9, "path": "/nix/store/hash8-system"})
        result = self.ns["compare"]("host", 1, 9)
        self.assertEqual(result["number"], 9)
        self.assertEqual(len(self.calls), 1)

    def test_missing_or_collected_generation(self):
        with self.assertRaisesRegex(RuntimeError, "Generation unavailable"):
            self.ns["compare"]("host", 2, 8)
        self.ns["run_report"] = Mock(side_effect=RuntimeError("no generation 8"))
        with self.assertRaisesRegex(RuntimeError, "no generation"):
            self.ns["compare"]("host", 1, 8)
        self.assertEqual(list(Path(self.temp.name).iterdir()), [])

    def test_host_api_rejects_malformed_numbers(self):
        self.ns["hosts"] = {"host": {}}
        compare = self.ns["compare"] = Mock(return_value={"changes": ""})
        for path, status in (("/api/hosts/host/compare/1/8", 200),
                             ("/api/hosts/host/compare/1/8%3Bwhoami", 404),
                             ("/api/hosts/host/compare/-1/8", 404),
                             ("/api/hosts/unknown/compare/1/8", 404)):
            self.assertEqual(self.ns["get"](path)[0], status)
        compare.assert_called_once_with("host", 1, 8)

    def test_remote_report_uses_svcctl_login(self):
        ns = definitions("host_pages.py")
        remote = Mock(return_value=subprocess.CompletedProcess([], 0, '{"generations": []}', ""))
        ns.update(hosts={"host": {"hosts": ["host.tailnet", "host.local"], "user": "remote-control"}},
                  run_remote=remote, REPORT_TIMEOUT=60)
        self.assertEqual(ns["run_report"]("host", "generations"), {"generations": []})
        remote.assert_called_once_with(["host.tailnet", "host.local"], "generations",
                                       "remote-control", timeout=60)
        ns["run_remote"] = None
        with self.assertRaisesRegex(RuntimeError, "no SSH key"):
            ns["run_report"]("host", "generations")


class RemoteLoginTests(unittest.TestCase):
    def setUp(self):
        self.ns = definitions("svcctl.py")
        self.run = Mock()
        self.ns.update(
            ssh_key="test-key",
            subprocess=types.SimpleNamespace(run=self.run, TimeoutExpired=subprocess.TimeoutExpired),
        )

    def test_timeout_reaches_every_attempt(self):
        self.run.side_effect = [subprocess.CompletedProcess([], 255, "", "no route"),
                                subprocess.CompletedProcess([], 0, "ok", "")]
        result = self.ns["remote_any"](["host.tailnet", "host.local"], "generations", timeout=60)
        self.assertEqual(result.stdout, "ok")
        self.assertEqual([call.kwargs["timeout"] for call in self.run.call_args_list], [60, 60])
        self.assertEqual(self.run.call_args.args[0][-2:], ["remote-control@host.local", "generations"])
        self.run.reset_mock(side_effect=True)
        self.run.return_value = subprocess.CompletedProcess([], 0, "", "")
        self.ns["remote_any"](["host"], "switch-status")
        self.assertEqual(self.run.call_args.kwargs["timeout"], 20)

    def test_connection_shared_only_with_a_runtime_directory(self):
        self.run.return_value = subprocess.CompletedProcess([], 0, "", "")
        with unittest.mock.patch.dict("os.environ", {"RUNTIME_DIRECTORY": "/run/svcctl"}):
            self.ns["remote"]("host", "status x")
        command = self.run.call_args.args[0]
        self.assertIn("ControlPath=/run/svcctl/ssh-%C", command)
        self.assertIn("ControlMaster=auto", command)
        # Options before the destination, the verb last.
        self.assertEqual(command[-2:], ["remote-control@host", "status x"])
        with unittest.mock.patch.dict("os.environ", clear=True):
            self.ns["remote"]("host", "status x")
        self.assertFalse(any("Control" in arg for arg in self.run.call_args.args[0]))

    def test_every_name_timing_out_raises(self):
        self.run.side_effect = subprocess.TimeoutExpired("ssh", 20)
        with self.assertRaises(subprocess.TimeoutExpired):
            self.ns["remote_any"](["a", "b"], "switch-status")
        self.assertEqual(self.run.call_count, 2)


class HostRoutingTests(unittest.TestCase):
    def test_host_pages_need_no_header(self):
        ns = definitions("svcctl.py")
        pages = Mock(get=Mock(return_value=(200, {"host": "h"})))
        ns["host_pages"] = pages
        handler = types.SimpleNamespace(path="/api/hosts/h", guarded=lambda: False, reply=Mock())
        ns["Handler"].do_GET(handler)
        pages.get.assert_called_once_with("/api/hosts/h")
        handler.reply.assert_called_once_with(200, {"host": "h"})


class SwitchLogTests(unittest.TestCase):
    def setUp(self):
        self.ns = definitions("svcctl.py")
        self.run = Mock(return_value=subprocess.CompletedProcess([], 0, b"build output", b""))
        self.remote = Mock(return_value=subprocess.CompletedProcess([], 0, "remote output", ""))
        self.ns.update(
            switchable={"Local": {"hosts": []}, "Remote": {"hosts": ["remote"], "user": "remote-control"}},
            ssh_key="test-key", SWITCH_UNIT="dotfiles-switch.service",
            HOME_SWITCH_UNIT="dotfiles-home-switch.service", remote_any=self.remote,
            subprocess=types.SimpleNamespace(run=self.run, TimeoutExpired=subprocess.TimeoutExpired),
        )

    def request(self, name, guarded=True):
        handler = types.SimpleNamespace(path=f"/api/svc/switch-log/{name}",
                                        guarded=lambda: guarded, reply=Mock())
        self.ns["Handler"].do_GET(handler)
        return handler.reply

    def test_local_fixed_unit_and_remote_verb(self):
        reply = self.request("Local")
        self.assertEqual(reply.call_args.args[1]["output"], "build output")
        command = self.run.call_args.args[0]
        self.assertIn("--unit=dotfiles-switch.service", command)
        self.assertIn("--unit=dotfiles-home-switch.service", command)
        self.assertIn("--lines=300", command)
        self.assertIn("--boot", command)
        self.request("Remote")
        self.remote.assert_called_once_with(["remote"], "switch-log", "remote-control")

    def test_bound_output(self):
        self.run.return_value.stdout = b"x" * (256 * 1024 + 100)
        body = self.request("Local").call_args.args[1]
        self.assertTrue(body["truncated"])
        self.assertEqual(len(body["output"]), 256 * 1024)

    def test_errors_and_header_guard(self):
        self.assertFalse(self.request("Local", guarded=False).called)
        self.assertEqual(self.request("Unknown").call_args.args[0], 404)
        self.run.return_value = subprocess.CompletedProcess([], 1, b"", b"permission denied")
        self.assertEqual(self.request("Local").call_args.args[0], 502)
        self.run.side_effect = subprocess.TimeoutExpired("journalctl", 15)
        self.assertEqual(self.request("Local").call_args.args[0], 504)
        self.remote.return_value = subprocess.CompletedProcess([], 1, "", "remote-control: refused")
        self.assertEqual(self.request("Remote").call_args.args[0], 502)


class SwitchStartTests(unittest.TestCase):
    def setUp(self):
        self.ns = definitions("svcctl.py")
        self.watched = []
        self.ns.update(
            switchable={"Local": {"hosts": []}, "Remote": {"hosts": ["remote"], "user": "remote-control"}},
            SWITCH_ACTIONS={"switch": "dotfiles-switch.service",
                            "home-switch": "dotfiles-home-switch.service"},
            SWITCH_STATUS=None, pending_switch={}, remote_switch={}, remote_switch_detail={},
            start_switch_watch=self.watched.append,
            time=types.SimpleNamespace(monotonic=lambda: 0.0),
        )

    def post(self, action, name):
        started = subprocess.CompletedProcess([], 0, "", "")
        handler = types.SimpleNamespace(path=f"/api/svc/{action}/{name}", guarded=lambda: True,
                                        reply=Mock(), host_action=Mock(return_value=started))
        self.ns["Handler"].do_POST(handler)
        return handler

    def test_home_switch_remote_verb_and_tracking(self):
        handler = self.post("home-switch", "Remote")
        target, verb, local = handler.host_action.call_args.args
        self.assertEqual(verb, "home-switch")
        self.assertEqual(local, ["systemctl", "--no-block", "start", "dotfiles-home-switch.service"])
        self.assertEqual(self.ns["remote_switch"]["Remote"], "switching")
        self.assertIn("Remote", self.ns["pending_switch"])
        self.assertEqual(self.watched, ["Remote"])

    def test_full_switch_unchanged(self):
        handler = self.post("switch", "Local")
        self.assertEqual(handler.host_action.call_args.args[1:],
                         ("switch", ["systemctl", "--no-block", "start", "dotfiles-switch.service"]))
        self.assertEqual(self.watched, [])


class SwitchTrackingTests(unittest.TestCase):
    def setUp(self):
        self.ns = definitions("svcctl.py")
        self.clock = [100.0]
        self.ns.update(
            pending_switch={}, SWITCH_START_GRACE=60,
            time=types.SimpleNamespace(monotonic=lambda: self.clock[0]),
        )

    def status(self, active, invocation="", last=None, result="success"):
        return json.dumps({"ActiveState": active, "Result": result,
                           "InvocationID": invocation, "last": last})

    def track(self, output):
        return self.ns["track_switch"]("Host", *self.ns["parse_switch"](output))

    def test_parse_json_and_legacy(self):
        parse = self.ns["parse_switch"]
        self.assertEqual(parse("active\nsuccess\n"), ("switching", None, None))
        self.assertEqual(parse("failed\nexit-code\n"), ("failed", None, None))
        self.assertEqual(parse("inactive\nsuccess\n")[0], "idle")
        # Unloaded after a failed run: Result is back to success, InvocationID
        # empty; only the unit's own status knows.
        failed = {"invocation": "a", "stage": "build", "result": "exit-code", "message": "error: x"}
        self.assertEqual(parse(self.status("inactive", last=failed)), ("failed", failed, "a"))
        running = {"invocation": "b", "stage": "build"}
        self.assertEqual(parse(self.status("activating", "b", running)), ("switching", running, "b"))
        # A new run that hasn't written its status yet shows the old one's as none.
        self.assertEqual(parse(self.status("activating", "c", failed)), ("switching", None, "c"))
        self.assertEqual(parse("garbage")[0], "unknown")

    def test_previous_run_not_taken_for_the_new_one(self):
        old = {"invocation": "a", "stage": "pull", "result": "exit-code"}
        self.ns["begin_switch"]("Host", self.status("inactive", last=old))
        self.assertEqual(self.track(self.status("inactive", last=old)), ("switching", None))
        new = {"invocation": "b", "stage": "home", "result": "success"}
        self.assertEqual(self.track(self.status("inactive", last=new))[0], "idle")
        self.assertNotIn("Host", self.ns["pending_switch"])

    def test_new_run_failing_is_reported(self):
        self.ns["begin_switch"]("Host", self.status("inactive"))
        self.assertEqual(self.track(self.status("activating", "b", {"invocation": "b", "stage": "build"}))[0],
                         "switching")
        failed = {"invocation": "b", "stage": "build", "result": "exit-code", "message": "error: x"}
        self.assertEqual(self.track(self.status("failed", "b", failed, "exit-code")), ("failed", failed))

    def test_switch_that_never_starts(self):
        self.ns["begin_switch"]("Host", self.status("inactive"))
        self.clock[0] += 61
        state, detail = self.track(self.status("inactive"))
        self.assertEqual(state, "failed")
        self.assertIn("didn't start", detail["message"])

    def test_legacy_host_is_trusted_after_the_grace(self):
        self.ns["begin_switch"]("Host", "")
        self.assertEqual(self.track("failed\nexit-code\n")[0], "switching")
        self.clock[0] += 61
        self.assertEqual(self.track("inactive\nsuccess\n")[0], "idle")
        self.ns["begin_switch"]("Host", "")
        self.track("active\nsuccess\n")
        self.assertEqual(self.track("failed\nexit-code\n")[0], "failed")


if __name__ == "__main__":
    unittest.main()
