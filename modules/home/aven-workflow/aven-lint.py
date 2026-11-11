"""Check aven's structural conventions (see conventions.md).

A port of the vault's `spec validate` rubric onto aven primitives. Requirement
coverage (`covers:` goal IDs) is deliberately not ported: goals are prose in the
project epic now, and an ID cross-reference would need a second ID scheme.
"""

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

DRAFT_STATUSES = {"inbox", "backlog"}
CLOSED_STATUSES = {"done", "canceled"}
STALE_INBOX_DAYS = 30

POC_SECTIONS = ["Objective", "Scope"]
POC_PLANNED_SECTIONS = ["Acceptance", "Verification"]
CHECKPOINT_PLANNED_SECTIONS = ["Deliverables", "Acceptance", "Verification"]
PROJECT_SECTIONS = ["Goals", "Non-goals"]
TRACKS = {"project", "learning"}
# Superseded by kind=project epics; flagged until migrated or canceled.
RETIRED_KINDS = {"scope", "curriculum"}
UNIT_PLANNED_SECTIONS = ["Build", "Milestone", "Checkpoint"]
MANUAL_PLANNED_SECTIONS = ["Context", "Hazards", "Steps", "Afterwards"]


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

    def kind_of(task_id):
        context = contexts.get(task_id)
        return context["metadata"].get("kind") if context else None

    def project_epic_of(context):
        """The parent's context when the parent is a kind=project epic, else None."""
        parent = context["epic_parent"]
        if parent is None or kind_of(parent["id"]) != "project":
            return None
        return contexts[parent["id"]]

    pocs_by_label = {}  # (parent epic ID, "P1") -> context of the POC task

    for task in tasks:
        context = contexts.get(task["id"])
        if context and context["metadata"].get("kind") == "poc" and "poc" in context["metadata"]:
            parent = context["epic_parent"]
            key = (parent["id"] if parent else None, context["metadata"]["poc"])
            if key in pocs_by_label:
                errors.append(f"{task['ref']}: duplicate poc={key[1]} in the same epic")
            pocs_by_label[key] = context

    for task in tasks:
        ref, status = task["ref"], task["status"]
        if status == "inbox":
            created = datetime.fromisoformat(task["created_at"].replace("Z", "+00:00"))
            if datetime.now(timezone.utc) - created > timedelta(days=STALE_INBOX_DAYS):
                warnings.append(f"{ref}: in inbox for over {STALE_INBOX_DAYS} days")

        context = contexts.get(task["id"])
        if task["is_epic"] and status != "canceled":
            repo = context["metadata"].get("repo", "") if context else ""
            if not repo.strip():
                errors.append(f"{ref}: epic needs repo=<absolute-path> metadata")
            elif not Path(repo).is_absolute():
                errors.append(f"{ref}: epic repo must be an absolute path")
        if context is None:
            continue
        kind = context["metadata"].get("kind")
        description = context["task"]["description"]
        planned = status not in DRAFT_STATUSES and status != "canceled"

        if kind in RETIRED_KINDS and status != "canceled":
            errors.append(f"{ref}: kind={kind} is retired; its content belongs on the kind=project epic")

        elif kind == "project":
            if not task["is_epic"]:
                errors.append(f"{ref}: kind=project must be an epic")
            if context["metadata"].get("track") not in TRACKS:
                errors.append(f"{ref}: project epic needs track=project or track=learning")
            for heading in missing_sections(description, PROJECT_SECTIONS):
                errors.append(f"{ref}: project epic has no '## {heading}' section")
            if status == "active" and not any(n["body"].lstrip().startswith("Handoff:") for n in context["notes"]):
                warnings.append(f"{ref}: active project epic has no 'Handoff:' note")

        elif kind == "poc":
            if task["is_epic"]:
                errors.append(f"{ref}: kind=poc must be a task, not an epic")
            parent = project_epic_of(context)
            if parent is None or parent["metadata"].get("track") != "project":
                errors.append(f"{ref}: POC is not in a track=project project epic")
            if "poc" not in context["metadata"]:
                errors.append(f"{ref}: POC has no 'poc' metadata ID")
            required = POC_SECTIONS + (POC_PLANNED_SECTIONS if planned else [])
            for heading in missing_sections(description, required):
                errors.append(f"{ref}: POC has no '## {heading}' section")
            label = context["metadata"].get("poc")

            def is_own_checkpoint(candidate):
                if candidate["project"] != task["project"] or kind_of(candidate["id"]) != "checkpoint":
                    return False
                candidate_context = contexts[candidate["id"]]
                same_poc = candidate_context["metadata"].get("poc") == label
                same_epic = candidate_context["epic_parent"] == context["epic_parent"]
                return same_poc and same_epic

            checkpoints = [t for t in tasks if is_own_checkpoint(t)]
            if planned and not checkpoints:
                errors.append(f"{ref}: POC has no checkpoints")
            depends_on = {d["id"] for d in context["dependencies"]["depends_on"]}
            for checkpoint in checkpoints:
                if checkpoint["status"] != "canceled" and checkpoint["id"] not in depends_on:
                    errors.append(f"{ref}: POC does not depend on its checkpoint {checkpoint['ref']}")
            if status == "done" and not any(n["body"].lstrip().startswith("Evidence:") for n in context["notes"]):
                errors.append(f"{ref}: done without an 'Evidence:' note")

        elif kind == "checkpoint":
            if "cp" not in context["metadata"]:
                errors.append(f"{ref}: checkpoint has no 'cp' metadata ID")
            parent = project_epic_of(context)
            if parent is None or parent["metadata"].get("track") != "project":
                errors.append(f"{ref}: checkpoint is not in a track=project project epic")
            label = context["metadata"].get("poc")
            poc = pocs_by_label.get((parent["task"]["id"] if parent else None, label))
            if label is None:
                errors.append(f"{ref}: checkpoint has no 'poc' metadata naming its POC")
            elif poc is None:
                errors.append(f"{ref}: checkpoint names poc={label}, which no kind=poc task carries")
            elif status not in CLOSED_STATUSES and poc["task"]["status"] in CLOSED_STATUSES:
                errors.append(f"{ref}: open checkpoint in closed POC {poc['task']['ref']}")
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
                elif dep_kind not in {"checkpoint", "question", "poc", "manual"}:
                    errors.append(f"{ref}: prerequisite {dependency['display_ref']} is not a checkpoint, POC, question or manual task")

        elif kind == "unit":
            if "unit" not in context["metadata"]:
                errors.append(f"{ref}: unit has no 'unit' metadata ID")
            parent = project_epic_of(context)
            if parent is None or parent["metadata"].get("track") != "learning":
                errors.append(f"{ref}: unit is not in a track=learning project epic")
            if planned:
                for heading in missing_sections(description, UNIT_PLANNED_SECTIONS):
                    errors.append(f"{ref}: unit has no '## {heading}' section")

        elif kind == "goal":
            # Membership is `related` links: an epic would take members out of
            # their own project epic, since a task has only one epic parent.
            if task["is_epic"]:
                errors.append(f"{ref}: kind=goal must be a task linked with 'aven related', not an epic")
            members = [r for r in context["related"] if not r["deleted"]]
            if status not in CLOSED_STATUSES and not members:
                warnings.append(f"{ref}: open goal has no related tasks")
            if status == "done":
                unfinished = [r["display_ref"] for r in members if r["status"] not in CLOSED_STATUSES]
                if unfinished:
                    errors.append(f"{ref}: goal done with unfinished related tasks {', '.join(unfinished)}")

        elif kind == "manual":
            if task["is_epic"]:
                errors.append(f"{ref}: kind=manual must be a task, not an epic")
            if planned:
                for heading in missing_sections(description, MANUAL_PLANNED_SECTIONS):
                    errors.append(f"{ref}: manual task has no '## {heading}' section")

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

    return errors, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    scope = parser.add_mutually_exclusive_group()
    scope.add_argument("-p", "--project", help="lint one project (default: inferred from cwd)")
    scope.add_argument("-A", "--all-projects", action="store_true")
    scope.add_argument("--epic", help="lint one epic and its children")
    parser.add_argument("--db", help="aven database path")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    global_args = ["--db", args.db] if args.db else []
    list_args = ["list", "--all", "--json"]
    if args.epic:
        list_args.append("--all-projects")
    elif args.project:
        list_args += ["--project", args.project]
    elif args.all_projects:
        list_args.append("--all-projects")

    tasks = [t for t in run_aven(global_args, *list_args) if not t["deleted"]]
    # All epics need repo metadata, including epics without a kind.
    structured = run_aven(global_args, *list_args, "--has-metadata", "kind", missing_field_ok=True)
    needing_context = {t["id"]: t for t in structured if not t["deleted"]}
    needing_context.update({t["id"]: t for t in tasks if t["is_epic"]})
    contexts = {tid: run_aven(global_args, "context", t["ref"], "--json")
                for tid, t in needing_context.items()}

    if args.epic:
        epic = run_aven(global_args, "show", args.epic, "--json")
        if not epic["is_epic"] or epic["deleted"]:
            parser.error("--epic must name a nondeleted epic")
        epic_ids = {epic["id"], *(child["id"] for child in epic["epic_children"])}
        tasks = [t for t in tasks if t["id"] in epic_ids]

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
