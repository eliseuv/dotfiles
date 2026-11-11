import runpy
import unittest
from pathlib import Path

lint = runpy.run_path(str(Path(__file__).with_name('aven-lint.py')))['lint']


def fixture():
    tasks, contexts = [], {}
    for epic in ('a', 'b'):
        for suffix, kind, meta, description in (
            ('', 'project', {'track': 'project', 'repo': '/tmp/' + epic}, '## Goals\nG\n## Non-goals\nN'),
            ('p', 'poc', {'poc': 'P1'}, '## Objective\nO\n## Scope\nS\n## Acceptance\nA\n## Verification\nV'),
            ('c', 'checkpoint', {'cp': 'CP-1', 'poc': 'P1'}, '## Deliverables\nD\n## Acceptance\nA\n## Verification\nV'),
        ):
            tid = epic + suffix
            task = dict(id=tid, ref=tid, project='group', status='todo', is_epic=not suffix)
            parent = {'id': epic} if suffix else None
            task['epic_parent'] = parent
            tasks.append(task)
            contexts[tid] = dict(task={**task, 'description': description}, metadata={'kind': kind, **meta}, epic_parent=parent, notes=[], dependencies={'depends_on': [], 'blocks': []})
        contexts[epic + 'p']['dependencies']['depends_on'] = [{'id': epic + 'c', 'display_ref': epic + 'c', 'status': 'todo', 'deleted': False}]
    return tasks, contexts


class EpicRepos(unittest.TestCase):
    def test_two_epics_can_each_have_p1(self):
        self.assertEqual(lint(*fixture()), ([], []))

    def test_checkpoint_cannot_use_other_epics_poc(self):
        tasks, contexts = fixture()
        contexts['ap']['metadata']['poc'] = 'P2'
        errors, _ = lint(tasks, contexts)
        self.assertTrue(any('ac: checkpoint names poc=P1' in e for e in errors), errors)

    def test_missing_and_relative_repo_fail(self):
        for repo in ('', 'relative/path'):
            tasks, contexts = fixture()
            contexts['a']['metadata']['repo'] = repo
            self.assertTrue(any('a: epic' in e for e in lint(tasks, contexts)[0]))

    def test_plain_epic_needs_repo_too(self):
        tasks, contexts = fixture()
        contexts['a']['metadata'] = {'repo': '/tmp/a'}
        # Remove structured children: this is an organizational epic.
        tasks = [t for t in tasks if t['id'] == 'a']
        self.assertEqual(lint(tasks, contexts), ([], []))
        contexts['a']['metadata'].clear()
        self.assertTrue(lint(tasks, contexts)[0])

    def test_canceled_epic_does_not_need_repo(self):
        tasks, contexts = fixture()
        tasks = [dict(t, status='canceled') for t in tasks if t['id'] == 'a']
        contexts['a']['metadata'].pop('repo')
        self.assertEqual(lint(tasks, contexts), ([], []))

    def test_empty_project_needs_no_repo(self):
        self.assertEqual(lint([], {}), ([], []))


unittest.main()
