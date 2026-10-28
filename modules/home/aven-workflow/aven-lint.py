"""Check aven's structural conventions (see conventions.md).

A port of the vault's `spec validate` rubric onto aven primitives. Requirement
coverage (`covers:` goal IDs) is deliberately not ported: goals are prose in the
scope epic now, and an ID cross-reference would need a second ID scheme.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

DRAFT_STATUSES = {"inbox", "backlog"}
CLOSED_STATUSES = {"done", "canceled"}
STALE_INBOX_DAYS = 30

POC_SECTIONS = ["Objective", "Scope"]
POC_PLANNED_SECTIONS = ["Acceptance", "Verification"]
CHECKPOINT_PLANNED_SECTIONS = ["Deliverables", "Acceptance", "Verification"]
SCOPE_SECTIONS = ["Goals", "Non-goals"]
UNIT_PLANNED_SECTIONS = ["Build", "Milestone", "Checkpoint"]


def run_aven(global_args, *args, missing_field_ok=False):
    result = subprocess.run(
        ["aven", *global_args, *args], capture_output=True, text=True
    )
    # Aven rejects a metadata filter on a key no task has ever used.
    if missing_field_ok and "unknown-metadata-field" in result.stderr:
        return []
    if result.returncode != 0:
        sys.exit(f"aven {' '.join(args)} failed:\n{result.stderr.strip()}")
    return json.loads(result.stdout)


def has_section(description, heading):
    pattern = rf"^##\s+{re.escape(heading)}\s*$\n(?P<body>.*?)(?=^##\s|\Z)"
    match = re.search(pattern, description or "", re.MULTILINE | re.DOTALL)
    return bool(match and match.group("body").strip())


def missing_sections(description, headings):
    return [h for h in headings if not has_section(description, h)]


def lint(tasks, contexts):
    errors, warnings = [], []
    by_id = {t["id"]: t for t in tasks}

    def kind_of(task_id):
        context = contexts.get(task_id)
        return context["metadata"].get("kind") if context else None

    # Projects with POCs or a curriculum must also carry a scope epic.
    projects_with_pocs, projects_with_scope = set(), set()

    for task in tasks:
        ref, status = task["ref"], task["status"]
        if status == "inbox":
            created = datetime.fromisoformat(task["created_at"].replace("Z", "+00:00"))
            if datetime.now(timezone.utc) - created > timedelta(days=STALE_INBOX_DAYS):
                warnings.append(f"{ref}: in inbox for over {STALE_INBOX_DAYS} days")

        context = contexts.get(task["id"])
        if context is None:
            continue
        kind = context["metadata"].get("kind")
        description = context["task"]["description"]
        planned = status not in DRAFT_STATUSES and status != "canceled"

        if kind == "scope":
            projects_with_scope.add(task["project"])
            if not task["is_epic"]:
                errors.append(f"{ref}: kind=scope must be an epic")
            for heading in missing_sections(description, SCOPE_SECTIONS):
                errors.append(f"{ref}: scope has no '## {heading}' section")

        elif kind == "poc":
            projects_with_pocs.add(task["project"])
            if not task["is_epic"]:
                errors.append(f"{ref}: kind=poc must be an epic")
            if "poc" not in context["metadata"]:
                errors.append(f"{ref}: POC has no 'poc' metadata ID")
            required = POC_SECTIONS + (POC_PLANNED_SECTIONS if planned else [])
            for heading in missing_sections(description, required):
                errors.append(f"{ref}: POC has no '## {heading}' section")
            children = context["epic_children"]
            checkpoints = [c for c in children if kind_of(c["id"]) == "checkpoint"]
            if planned and not checkpoints:
                errors.append(f"{ref}: POC has no checkpoints")
            if status == "done":
                unfinished = [c["ref"] for c in checkpoints if c["status"] not in CLOSED_STATUSES]
                if unfinished:
                    errors.append(f"{ref}: done with unfinished checkpoints {', '.join(unfinished)}")

        elif kind == "checkpoint":
            if "cp" not in context["metadata"]:
                errors.append(f"{ref}: checkpoint has no 'cp' metadata ID")
            parent = context["epic_parent"]
            if parent is None or kind_of(parent["id"]) != "poc":
                errors.append(f"{ref}: checkpoint is not in a kind=poc epic")
            elif status not in CLOSED_STATUSES and by_id[parent["id"]]["status"] in CLOSED_STATUSES:
                errors.append(f"{ref}: open checkpoint in closed POC {parent['ref']}")
            if planned:
                for heading in missing_sections(description, CHECKPOINT_PLANNED_SECTIONS):
                    errors.append(f"{ref}: checkpoint has no '## {heading}' section")
            if status == "done":
                if not any(n["body"].lstrip().startswith("Evidence:") for n in context["notes"]):
                    errors.append(f"{ref}: done without an 'Evidence:' note")
            for dependency in context["dependencies"]["depends_on"]:
                dep_kind = kind_of(dependency["id"])
                if dependency["status"] == "canceled":
                    errors.append(f"{ref}: prerequisite {dependency['display_ref']} was canceled; pick its replacement")
                elif dep_kind not in {"checkpoint", "question"}:
                    errors.append(f"{ref}: prerequisite {dependency['display_ref']} is neither a checkpoint nor a question")

        elif kind == "curriculum":
            projects_with_pocs.add(task["project"])
            if not task["is_epic"]:
                errors.append(f"{ref}: kind=curriculum must be an epic")

        elif kind == "unit":
            if "unit" not in context["metadata"]:
                errors.append(f"{ref}: unit has no 'unit' metadata ID")
            parent = context["epic_parent"]
            if parent is None or kind_of(parent["id"]) != "curriculum":
                errors.append(f"{ref}: unit is not in a kind=curriculum epic")
            if planned:
                for heading in missing_sections(description, UNIT_PLANNED_SECTIONS):
                    errors.append(f"{ref}: unit has no '## {heading}' section")

        elif kind == "question":
            if status not in CLOSED_STATUSES and not context["dependencies"]["blocks"]:
                warnings.append(f"{ref}: open question blocks nothing")

        if status == "done":
            open_blockers = [
                d["display_ref"] for d in context["dependencies"]["depends_on"]
                if d["status"] not in CLOSED_STATUSES and not d["deleted"]
            ]
            if open_blockers:
                errors.append(f"{ref}: done while blocked by {', '.join(open_blockers)}")

    for project in sorted(projects_with_pocs - projects_with_scope, key=str):
        errors.append(f"project {project}: has POCs or a curriculum but no kind=scope epic")

    return errors, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("-p", "--project", help="lint one project (default: inferred from cwd)")
    scope.add_argument("-A", "--all-projects", action="store_true")
    parser.add_argument("--db", help="aven database path")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    global_args = ["--db", args.db] if args.db else []
    list_args = ["list", "--all", "--json"]
    if args.project:
        list_args += ["--project", args.project]
    elif args.all_projects:
        list_args.append("--all-projects")

    tasks = [t for t in run_aven(global_args, *list_args) if not t["deleted"]]
    # Contexts are fetched only for structured tasks; metadata is absent from `list`.
    structured = run_aven(global_args, *list_args, "--has-metadata", "kind", missing_field_ok=True)
    contexts = {t["id"]: run_aven(global_args, "context", t["ref"], "--json") for t in structured if not t["deleted"]}

    errors, warnings = lint(tasks, contexts)

    if args.json:
        print(json.dumps({"ok": not errors, "errors": errors, "warnings": warnings}, indent=2))
    else:
        for error in errors:
            print(f"ERROR  {error}")
        for warning in warnings:
            print(f"warn   {warning}")
        if not errors and not warnings:
            print("ok")
        else:
            print(f"\n{len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
