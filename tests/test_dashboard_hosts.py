"""Host API regressions. Run: python3 -m unittest discover -s tests."""
import ast
import concurrent.futures
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import types
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "modules/nixos/homelab/dashboard"


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
        self.ns = definitions("hostctl.py")
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
            handler = types.SimpleNamespace(path=path, reply=Mock())
            self.ns["Handler"].do_GET(handler)
            self.assertEqual(handler.reply.call_args.args[0], status)
        compare.assert_called_once_with("host", 1, 8)


class SwitchLogTests(unittest.TestCase):
    def setUp(self):
        self.ns = definitions("svcctl.py")
        self.run = Mock(return_value=subprocess.CompletedProcess([], 0, b"build output", b""))
        self.remote = Mock(return_value=subprocess.CompletedProcess([], 0, "remote output", ""))
        self.ns.update(
            switchable={"Local": {"hosts": []}, "Remote": {"hosts": ["remote"], "user": "remote-control"}},
            ssh_key="test-key", SWITCH_UNIT="dotfiles-switch.service", remote_any=self.remote,
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


if __name__ == "__main__":
    unittest.main()
