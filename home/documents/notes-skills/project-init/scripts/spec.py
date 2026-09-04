#!/usr/bin/env python3
"""spec.py — query and mutate PROJECT_SPEC.md.

Single-file, stdlib-only. The spec is the source of truth; this tool never
reserializes the whole document. All mutations are surgical line edits, so
human prose, comments and formatting survive untouched.

Run `spec.py grammar` for the file format.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys
from dataclasses import dataclass, field as dc_field
from typing import Any

DEFAULT_PATH = "PROJECT_SPEC.md"

# ID prefix -> (section slug, human name)
KINDS = {
    "G": ("goals", "Goals"),
    "NG": ("non-goals", "Non-Goals"),
    "C": ("constraints", "Constraints"),
    "R": ("requirements", "Requirements"),
    "D": ("decisions", "Decisions"),
    "A": ("assumptions", "Assumptions"),
    "Q": ("open-questions", "Open Questions"),
    "RK": ("risks", "Risks"),
    "M": ("milestones", "Milestones"),
}

STATUSES = {
    "G": {"proposed", "accepted", "dropped"},
    "NG": {"accepted", "dropped"},
    "C": {"proposed", "accepted", "dropped"},
    "R": {"draft", "specified", "accepted", "implemented", "dropped"},
    "D": {"proposed", "accepted", "superseded", "dropped"},
    "A": {"unconfirmed", "confirmed", "refuted"},
    "Q": {"open", "answered", "dropped"},
    "RK": {"open", "mitigated", "accepted", "closed"},
    "M": {"planned", "active", "done", "dropped"},
}

DEFAULT_STATUS = {
    "G": "proposed", "NG": "accepted", "C": "proposed", "R": "draft",
    "D": "proposed", "A": "unconfirmed", "Q": "open", "RK": "open", "M": "planned",
}

# Fields whose values are ID lists, used for reference integrity checks.
REF_FIELDS = ("blocks", "refs", "covers", "satisfies", "supersedes", "from")

HEADING_RE = re.compile(r"^###\s+([A-Z]{1,2}-\d+)\s*(?:[—–-]\s*)?(.*)$")
SECTION_RE = re.compile(r"^##\s+(?:\d+\.\s*)?(.+?)\s*$")
MARKER_RE = re.compile(r"^<!--\s*items:\s*([A-Z]{1,2})\s*-->\s*$")
FIELD_RE = re.compile(r"^-\s+([a-z_]+):\s*(.*)$")
ANSWER_RE = re.compile(r"^>?\s*ANSWER:\s*(.*)$")


def parse_value(raw: str) -> Any:
    raw = raw.strip()
    if raw == "" or raw in ("~", "TBD", "unknown"):
        return None
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        return [p.strip() for p in inner.split(",") if p.strip()]
    return raw


def render_value(val: Any) -> str:
    if val is None:
        return ""
    if isinstance(val, (list, tuple)):
        return "[" + ", ".join(str(v) for v in val) + "]"
    return str(val)


@dataclass
class Item:
    id: str
    kind: str
    title: str
    heading_line: int  # 0-based index of the '### ' line
    end_line: int  # exclusive
    fields: dict[str, Any] = dc_field(default_factory=dict)
    field_lines: dict[str, int] = dc_field(default_factory=dict)
    last_field_line: int = -1
    body: str = ""
    answer: str = ""
    answer_line: int = -1

    def status(self) -> str | None:
        return self.fields.get("status")

    def to_dict(self, with_body: bool = False) -> dict[str, Any]:
        d: dict[str, Any] = {"id": self.id, "kind": self.kind, "title": self.title}
        d.update(self.fields)
        if self.kind == "Q":
            d["answer"] = self.answer or None
        if with_body:
            d["body"] = self.body
        return d


class Spec:
    def __init__(self, path: str):
        self.path = path
        if not os.path.exists(path):
            die(f"no spec at {path!r} — run `spec.py init` first")
        with open(path, encoding="utf-8") as fh:
            self.lines = fh.read().split("\n")
        self.meta: dict[str, Any] = {}
        self.meta_lines: dict[str, int] = {}
        self.items: list[Item] = []
        self.section_markers: dict[str, int] = {}  # kind -> marker line idx
        self.sections: list[tuple[str, int]] = []
        self._parse()

    # ---------- parsing ----------
    def _parse(self) -> None:
        lines = self.lines
        i = 0
        if lines and lines[0].strip() == "---":
            i = 1
            while i < len(lines) and lines[i].strip() != "---":
                m = re.match(r"^([a-z_]+):\s*(.*)$", lines[i])
                if m:
                    self.meta[m.group(1)] = parse_value(m.group(2))
                    self.meta_lines[m.group(1)] = i
                i += 1
            i += 1

        heads: list[tuple[int, str, str]] = []
        for n in range(i, len(lines)):
            line = lines[n]
            mk = MARKER_RE.match(line)
            if mk:
                self.section_markers[mk.group(1)] = n
                continue
            if line.startswith("## "):
                sm = SECTION_RE.match(line)
                if sm:
                    self.sections.append((sm.group(1), n))
                continue
            hm = HEADING_RE.match(line)
            if hm:
                heads.append((n, hm.group(1), hm.group(2).strip()))

        for idx, (ln, iid, title) in enumerate(heads):
            end = len(lines)
            for j in range(ln + 1, len(lines)):
                if lines[j].startswith("## ") or HEADING_RE.match(lines[j]):
                    end = j
                    break
            self.items.append(self._build_item(ln, iid, title, end))

    def _build_item(self, ln: int, iid: str, title: str, end: int) -> Item:
        kind = iid.split("-")[0]
        it = Item(id=iid, kind=kind, title=title, heading_line=ln, end_line=end)
        n = ln + 1
        while n < end:
            line = self.lines[n]
            fm = FIELD_RE.match(line)
            if fm:
                it.fields[fm.group(1)] = parse_value(fm.group(2))
                it.field_lines[fm.group(1)] = n
                it.last_field_line = n
                n += 1
                continue
            if line.strip() == "" and it.last_field_line >= 0:
                n += 1
                continue
            break
        body_lines: list[str] = []
        ans_lines: list[str] = []
        in_answer = False
        for j in range(n, end):
            line = self.lines[j]
            am = ANSWER_RE.match(line)
            if am and not in_answer:
                in_answer = True
                it.answer_line = j
                if am.group(1).strip():
                    ans_lines.append(am.group(1).strip())
                continue
            if in_answer:
                ans_lines.append(re.sub(r"^>\s?", "", line))
            else:
                body_lines.append(line)
        it.body = "\n".join(body_lines).strip()
        it.answer = "\n".join(ans_lines).strip()
        return it

    # ---------- lookup ----------
    def get(self, iid: str) -> Item:
        for it in self.items:
            if it.id.upper() == iid.upper():
                return it
        die(f"no such item: {iid}")

    def by_kind(self, kind: str) -> list[Item]:
        return [i for i in self.items if i.kind == kind]

    def ids(self) -> set[str]:
        return {i.id for i in self.items}

    def next_id(self, kind: str) -> str:
        nums = [int(i.id.split("-")[1]) for i in self.by_kind(kind)]
        return f"{kind}-{max(nums) + 1 if nums else 1}"

    # ---------- mutation ----------
    def save(self) -> None:
        with open(self.path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(self.lines))

    def touch(self) -> None:
        today = datetime.date.today().isoformat()
        if "updated" in self.meta_lines:
            self.lines[self.meta_lines["updated"]] = f"updated: {today}"
        self.meta["updated"] = today

    def set_field(self, it: Item, key: str, val: Any) -> None:
        line = f"- {key}: {render_value(val)}"
        if key in it.field_lines:
            self.lines[it.field_lines[key]] = line
        else:
            at = it.last_field_line + 1 if it.last_field_line >= 0 else it.heading_line + 1
            self.lines.insert(at, line)
            self._reparse()

    def set_meta(self, key: str, val: Any) -> None:
        line = f"{key}: {render_value(val)}"
        if key in self.meta_lines:
            self.lines[self.meta_lines[key]] = line
        else:
            self.lines.insert(1, line)
        self._reparse()

    def append_body(self, it: Item, text: str) -> None:
        at = it.end_line
        while at > it.heading_line + 1 and self.lines[at - 1].strip() == "":
            at -= 1
        self.lines[at:at] = ["", text]
        self._reparse()

    def add_item(self, kind: str, title: str, fields: dict[str, Any], body: str = "") -> str:
        if kind not in self.section_markers:
            die(f"no section marker '<!-- items: {kind} -->' in {self.path}")
        iid = self.next_id(kind)
        marker = self.section_markers[kind]
        at = len(self.lines)
        for n in range(marker + 1, len(self.lines)):
            if self.lines[n].startswith("## "):
                at = n
                break
        while at > marker + 1 and self.lines[at - 1].strip() == "":
            at -= 1
        block = [f"### {iid} — {title}"]
        for k, v in fields.items():
            block.append(f"- {k}: {render_value(v)}")
        if body:
            block += ["", body]
        if kind == "Q":
            block += ["", "> ANSWER:"]
        self.lines[at:at] = [""] + block
        self._reparse()
        return iid

    def log(self, msg: str) -> None:
        idx = None
        for name, ln in self.sections:
            if name.lower().startswith("changelog"):
                idx = ln
        if idx is None:
            return
        at = len(self.lines)
        for n in range(idx + 1, len(self.lines)):
            if self.lines[n].startswith("## "):
                at = n
                break
        while at > idx + 1 and self.lines[at - 1].strip() == "":
            at -= 1
        self.lines.insert(at, f"- {datetime.date.today().isoformat()} — {msg}")
        self._reparse()

    def _reparse(self) -> None:
        text = "\n".join(self.lines)
        self.meta, self.meta_lines, self.items = {}, {}, []
        self.section_markers, self.sections = {}, []
        self.lines = text.split("\n")
        self._parse()


def die(msg: str) -> None:
    print(f"spec: {msg}", file=sys.stderr)
    sys.exit(2)


# ---------- output ----------
def emit(rows: list[dict[str, Any]], as_json: bool, cols: list[str] | None = None) -> None:
    if as_json:
        print(json.dumps(rows, indent=2))
        return
    if not rows:
        print("(none)")
        return
    cols = cols or ["id", "status", "title"]
    rows = [{c: str(r.get(c) or "").replace("\n", " ")[:110] for c in cols} for r in rows]
    widths = {c: max(len(c), *(len(str(r.get(c) or "")) for r in rows)) for c in cols}
    for r in rows:
        print("  ".join(str(r.get(c) or "").ljust(widths[c]) for c in cols).rstrip())


# ---------- commands ----------
def cmd_init(args) -> int:
    if os.path.exists(args.file) and not args.force:
        die(f"{args.file} exists (use --force)")
    tpl = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "TEMPLATE.md")
    tpl = args.template or os.path.normpath(tpl)
    with open(tpl, encoding="utf-8") as fh:
        text = fh.read()
    text = text.replace("{{PROJECT}}", args.project)
    text = text.replace("{{DATE}}", datetime.date.today().isoformat())
    with open(args.file, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"created {args.file}")
    return 0


def cmd_ls(args) -> int:
    sp = Spec(args.file)
    items = sp.items
    if args.kind:
        kinds = {k.upper() for k in args.kind}
        items = [i for i in items if i.kind in kinds]
    if args.status:
        want = set(args.status)
        items = [i for i in items if i.status() in want]
    if args.not_status:
        bad = set(args.not_status)
        items = [i for i in items if i.status() not in bad]
    for expr in args.where or []:
        k, _, v = expr.partition("=")
        items = [i for i in items if str(i.fields.get(k, "")) == v or
                 (isinstance(i.fields.get(k), list) and v in i.fields[k])]
    if args.mentions:
        t = args.mentions.upper()
        items = [i for i in items
                 if any(t in (i.fields.get(f) or []) for f in REF_FIELDS)]
    if args.unresolved:
        items = [i for i in items if any(v is None for v in i.fields.values())]
    rows = [i.to_dict(with_body=args.body) for i in items]
    emit(rows, args.json, args.columns.split(",") if args.columns else None)
    return 0


def cmd_get(args) -> int:
    sp = Spec(args.file)
    it = sp.get(args.id)
    if args.json:
        print(json.dumps(it.to_dict(with_body=True), indent=2))
    else:
        print("\n".join(sp.lines[it.heading_line:it.end_line]).rstrip())
    return 0


def cmd_add(args) -> int:
    sp = Spec(args.file)
    fields: dict[str, Any] = {}
    for expr in args.set or []:
        k, _, v = expr.partition("=")
        fields[k] = parse_value(v)
    kind = args.kind.upper()
    fields.setdefault("status", DEFAULT_STATUS.get(kind, "draft"))
    if kind == "Q":
        fields["status"] = "open"
        fields.setdefault("asked", datetime.date.today().isoformat())
    iid = sp.add_item(kind, args.title, fields, args.body or "")
    sp.touch()
    if not args.quiet:
        sp.log(f"added {iid}: {args.title}")
    sp.save()
    print(iid)
    return 0


def cmd_set(args) -> int:
    sp = Spec(args.file)
    it = sp.get(args.id)
    changes = []
    for expr in args.assign:
        k, _, v = expr.partition("=")
        old = it.fields.get(k)
        sp.set_field(it, k, parse_value(v))
        it = sp.get(args.id)
        changes.append(f"{k}: {render_value(old) or '∅'} -> {v}")
    if args.append_body:
        sp.append_body(it, args.append_body)
    sp.touch()
    if changes and not args.quiet:
        sp.log(f"{it.id} {'; '.join(changes)}")
    sp.save()
    print(f"{it.id}: " + "; ".join(changes) if changes else f"{it.id} updated")
    return 0


def cmd_inbox(args) -> int:
    """Questions the human has answered but the agent has not yet processed."""
    sp = Spec(args.file)
    rows = []
    for it in sp.by_kind("Q"):
        if it.status() == "open" and it.answer:
            d = it.to_dict()
            d["blocks"] = render_value(it.fields.get("blocks"))
            rows.append(d)
    emit(rows, args.json, ["id", "blocks", "title", "answer"])
    return 0


def cmd_pending(args) -> int:
    """Questions still awaiting a human answer."""
    sp = Spec(args.file)
    rows = [i.to_dict() for i in sp.by_kind("Q") if i.status() == "open" and not i.answer]
    emit(rows, args.json, ["id", "title"])
    return 0


def blocking_map(sp: "Spec") -> dict[str, list[str]]:
    """target ID -> list of unanswered question IDs stalling it."""
    out: dict[str, list[str]] = {}
    for q in sp.by_kind("Q"):
        if q.status() != "open" or q.answer:
            continue
        for tgt in q.fields.get("blocks") or []:
            out.setdefault(tgt.upper(), []).append(q.id)
    for it in sp.items:
        for src in it.fields.get("blocked_by") or []:
            try:
                q = sp.get(src)
            except SystemExit:
                continue
            if q.kind == "Q" and q.status() == "open" and not q.answer:
                out.setdefault(it.id, []).append(q.id)
    return {k: sorted(set(v)) for k, v in out.items()}


def cmd_blocked(args) -> int:
    sp = Spec(args.file)
    bm = blocking_map(sp)
    rows = []
    for it in sp.items:
        if it.id in bm:
            d = it.to_dict()
            d["blocked_by"] = ", ".join(bm[it.id])
            rows.append(d)
    for tgt, qs in bm.items():
        if tgt not in sp.ids():
            rows.append({"id": tgt, "status": "MISSING", "title": "(dangling target)",
                         "blocked_by": ", ".join(qs)})
    emit(rows, args.json, ["id", "status", "blocked_by", "title"])
    return 0


def cmd_resolve(args) -> int:
    sp = Spec(args.file)
    q = sp.get(args.id)
    if q.kind != "Q":
        die(f"{q.id} is not a question")
    if not q.answer and not args.force:
        die(f"{q.id} has no answer yet (use --force to close it anyway)")
    sp.set_field(q, "status", "answered")
    q = sp.get(args.id)
    if args.into:
        sp.set_field(q, "resolved_into", args.into.upper())
    sp.touch()
    sp.log(f"resolved {q.id}" + (f" into {args.into.upper()}" if args.into else ""))
    sp.save()
    print(f"{q.id} -> answered")
    return 0


def cmd_log(args) -> int:
    sp = Spec(args.file)
    sp.touch()
    sp.log(args.message)
    sp.save()
    print("logged")
    return 0


COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
LEADING_COMMENT_RE = re.compile(r"\s*(<!--.*?-->)", re.S)


def find_prose_section(sp: "Spec", prefix: str) -> tuple[int, int] | None:
    """(heading line, end line) of a prose section, matched by name prefix."""
    start = None
    for name, ln in sp.sections:
        if name.lower().startswith(prefix):
            start = ln
    if start is None:
        return None
    end = len(sp.lines)
    for n in range(start + 1, len(sp.lines)):
        if sp.lines[n].startswith("## "):
            end = n
            break
    return start, end


def prose_section(sp: "Spec", prefix: str) -> tuple[int, int]:
    found = find_prose_section(sp, prefix)
    if found is None:
        die(f"no {prefix.capitalize()} section in {sp.path}")
    return found


def prose_content(sp: "Spec", prefix: str) -> str:
    """A prose section's body with its guidance comment removed.

    Guidance lives in HTML comments rather than italic placeholder text so that
    "has the human written anything here yet" stays decidable. An earlier
    template used `- **Last session:** —` placeholders, which are non-empty
    text, and that made the empty-handoff check unfireable on every real spec.
    """
    found = find_prose_section(sp, prefix)
    if found is None:
        return ""
    start, end = found
    return COMMENT_RE.sub("", "\n".join(sp.lines[start + 1:end])).strip()


def set_prose(sp: "Spec", prefix: str, content: str) -> None:
    """Replace a prose section's content, preserving its guidance comment."""
    start, end = prose_section(sp, prefix)
    body = "\n".join(sp.lines[start + 1:end])
    m = LEADING_COMMENT_RE.match(body)
    block = [""] + (m.group(1).split("\n") if m else [])
    if content:
        block += [""] + content.split("\n")
    sp.lines[start + 1:end] = block + [""]
    sp._reparse()


def cmd_handoff(args) -> int:
    sp = Spec(args.file)
    start, end = prose_section(sp, "handoff")
    if args.set is None:
        print("\n".join(sp.lines[start:end]).rstrip())
        return 0
    set_prose(sp, "handoff", args.set)
    sp.touch()
    sp.save()
    print("handoff updated")
    return 0


def cmd_directions(args) -> int:
    """The user's half of the channel: free prose in, typed items out.

    `> ANSWER:` carries replies to questions the agent asked. This carries what
    the user brought unprompted — a one-line request, a paragraph of
    second-guessing, a phased plan. Neither substitutes for the other, so a
    session reads both. Drain it by folding each line into a typed item and
    removing it here; it accumulates between sessions and empties during them.
    """
    sp = Spec(args.file)
    content = prose_content(sp, "directions")
    if args.set is None and args.add is None and not args.clear:
        print(content if content else "(empty)")
        return 0
    if args.add is not None:
        new = (content + "\n" if content else "") + f"- {args.add}"
    elif args.clear:
        new = ""
    else:
        new = args.set
    set_prose(sp, "directions", new)
    sp.touch()
    sp.save()
    print("directions updated")
    return 0


def cmd_status(args) -> int:
    sp = Spec(args.file)
    out: dict[str, Any] = {
        "project": sp.meta.get("project"),
        "status": sp.meta.get("status"),
        "updated": sp.meta.get("updated"),
        "counts": {},
        "answered_awaiting_processing": len(
            [i for i in sp.by_kind("Q") if i.status() == "open" and i.answer]),
        "awaiting_human": len(
            [i for i in sp.by_kind("Q") if i.status() == "open" and not i.answer]),
        "unresolved_fields": len([i for i in sp.items if any(v is None for v in i.fields.values())]),
        "directions_undrained": len(
            [l for l in prose_content(sp, "directions").split("\n") if l.strip()]),
    }
    for k, (_, name) in KINDS.items():
        items = sp.by_kind(k)
        if items:
            out["counts"][name] = len(items)
    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print(f"{out['project']}  [{out['status']}]  updated {out['updated']}")
        for name, n in out["counts"].items():
            print(f"  {name:<16} {n}")
        print(f"  answers to process: {out['answered_awaiting_processing']}")
        print(f"  awaiting human:     {out['awaiting_human']}")
        print(f"  directions to fold: {out['directions_undrained']}")
    return 0


def cmd_validate(args) -> int:
    sp = Spec(args.file)
    errors: list[str] = []
    warns: list[str] = []
    ids = sp.ids()

    seen: set[str] = set()
    for it in sp.items:
        if it.id in seen:
            errors.append(f"{it.id}: duplicate ID")
        seen.add(it.id)
        if it.kind not in KINDS:
            errors.append(f"{it.id}: unknown kind '{it.kind}'")
            continue
        st = it.status()
        if st is None:
            errors.append(f"{it.id}: missing status")
        elif st not in STATUSES[it.kind]:
            errors.append(f"{it.id}: status '{st}' not in {sorted(STATUSES[it.kind])}")
        if not it.title:
            errors.append(f"{it.id}: empty title")
        for f in REF_FIELDS:
            for ref in it.fields.get(f) or []:
                if ref not in ids:
                    errors.append(f"{it.id}.{f}: dangling reference {ref}")

    def live(kind: str) -> list[Item]:
        return [i for i in sp.by_kind(kind) if i.status() not in ("dropped", "superseded")]

    for it in live("G"):
        if not it.fields.get("metric"):
            errors.append(f"{it.id}: goal has no measurable 'metric'")
    for it in live("R"):
        if not it.fields.get("acceptance") and "acceptance" not in it.body.lower():
            errors.append(f"{it.id}: requirement has no acceptance criteria")
        if not it.fields.get("covers"):
            warns.append(f"{it.id}: not linked to any goal via 'covers'")
    for it in live("A"):
        if not it.fields.get("confidence"):
            errors.append(f"{it.id}: assumption missing 'confidence'")
        if not it.fields.get("impact_if_wrong"):
            errors.append(f"{it.id}: assumption missing 'impact_if_wrong'")
    for it in live("D"):
        if not it.fields.get("options"):
            errors.append(f"{it.id}: decision records no rejected options")
        if not it.fields.get("chosen"):
            errors.append(f"{it.id}: decision has no 'chosen' value")
        if not it.body:
            warns.append(f"{it.id}: decision has no rationale body")
    for it in live("RK"):
        if not it.fields.get("mitigation"):
            warns.append(f"{it.id}: risk has no mitigation")
    for it in live("M"):
        if not it.fields.get("covers"):
            errors.append(f"{it.id}: milestone lists no requirements in 'covers'")

    if not live("NG"):
        errors.append("Non-Goals section is empty — scope is unbounded")
    if not live("G"):
        errors.append("no goals defined")

    bm = blocking_map(sp)
    first_ms = [i for i in live("M") if str(i.fields.get("order")) == "1"] or live("M")[:1]
    for ms in first_ms:
        for tgt in sorted(set(ms.fields.get("covers") or []) | {ms.id}):
            if tgt in bm:
                errors.append(
                    f"{tgt} (in {ms.id}, the first milestone) is blocked by "
                    f"unanswered {', '.join(bm[tgt])}")
    for q in sp.by_kind("Q"):
        if q.status() == "open" and q.answer:
            warns.append(f"{q.id}: answered but not yet processed (run `spec.py inbox`)")

    if find_prose_section(sp, "handoff") and not prose_content(sp, "handoff"):
        warns.append("Handoff section is empty")
    undrained = [l for l in prose_content(sp, "directions").split("\n") if l.strip()]
    if undrained:
        warns.append(f"Directions has {len(undrained)} undrained line(s) — fold each "
                     f"into an item and remove it (`spec.py directions`)")

    if args.json:
        print(json.dumps({"ok": not errors, "errors": errors, "warnings": warns}, indent=2))
    else:
        for e in errors:
            print(f"ERROR  {e}")
        for w in warns:
            print(f"warn   {w}")
        if not errors and not warns:
            print("ok — spec passes the rubric")
        elif not errors:
            print(f"\nok with {len(warns)} warning(s)")
        else:
            print(f"\n{len(errors)} error(s), {len(warns)} warning(s)")
    if errors:
        return 1
    return 1 if (warns and args.strict) else 0


def cmd_grammar(args) -> int:
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references", "GRAMMAR.md")
    with open(os.path.normpath(p), encoding="utf-8") as fh:
        print(fh.read())
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="spec.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-f", "--file", default=os.environ.get("SPEC_FILE", DEFAULT_PATH))
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("init", help="create a spec from the template")
    p.add_argument("project")
    p.add_argument("--template")
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_init)

    p = sub.add_parser("ls", help="list/filter items")
    p.add_argument("kind", nargs="*", help="ID prefixes, e.g. Q R D")
    p.add_argument("--status", action="extend", nargs="+")
    p.add_argument("--not-status", action="extend", nargs="+")
    p.add_argument("--where", action="extend", nargs="+", metavar="KEY=VAL")
    p.add_argument("--mentions", metavar="ID", help="items referencing this ID")
    p.add_argument("--unresolved", action="store_true", help="items with empty fields")
    p.add_argument("--columns")
    p.add_argument("--body", action="store_true")
    p.set_defaults(fn=cmd_ls)

    p = sub.add_parser("get", help="print one item verbatim")
    p.add_argument("id")
    p.set_defaults(fn=cmd_get)

    p = sub.add_parser("add", help="append a new item, allocating the next ID")
    p.add_argument("kind")
    p.add_argument("title")
    p.add_argument("--set", action="extend", nargs="+", metavar="KEY=VAL")
    p.add_argument("--body")
    p.add_argument("--quiet", action="store_true", help="skip changelog entry")
    p.set_defaults(fn=cmd_add)

    p = sub.add_parser("set", help="surgically edit fields on an item")
    p.add_argument("id")
    p.add_argument("assign", nargs="+", metavar="KEY=VAL")
    p.add_argument("--append-body")
    p.add_argument("--quiet", action="store_true")
    p.set_defaults(fn=cmd_set)

    p = sub.add_parser("inbox", help="answered questions not yet processed")
    p.set_defaults(fn=cmd_inbox)

    p = sub.add_parser("pending", help="questions awaiting a human answer")
    p.set_defaults(fn=cmd_pending)

    p = sub.add_parser("blocked", help="items blocked by unanswered questions")
    p.set_defaults(fn=cmd_blocked)

    p = sub.add_parser("resolve", help="close a question after folding it in")
    p.add_argument("id")
    p.add_argument("--into", help="ID of the D/R item that captures the answer")
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_resolve)

    p = sub.add_parser("log", help="append a changelog entry")
    p.add_argument("message")
    p.set_defaults(fn=cmd_log)

    p = sub.add_parser("handoff", help="read or rewrite the handoff block")
    p.add_argument("--set")
    p.set_defaults(fn=cmd_handoff)

    p = sub.add_parser("directions", help="the user's free-prose input channel")
    p.add_argument("--set", help="replace the content")
    p.add_argument("--add", metavar="TEXT", help="append one line")
    p.add_argument("--clear", action="store_true", help="drop it all once folded in")
    p.set_defaults(fn=cmd_directions)

    p = sub.add_parser("status", help="one-screen summary")
    p.set_defaults(fn=cmd_status)

    p = sub.add_parser("validate", help="check against the rubric")
    p.add_argument("--strict", action="store_true", help="warnings are failures")
    p.set_defaults(fn=cmd_validate)

    p = sub.add_parser("grammar", help="print the file format reference")
    p.set_defaults(fn=cmd_grammar)

    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    try:
        import signal
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # play nicely with `| head`
    except (ImportError, AttributeError, ValueError):
        pass
    sys.exit(main())
