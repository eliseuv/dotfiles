---
name: human-handoff
description: File the steps only the user can do - adding secrets, deploying or switching hosts, logging in through a browser, touching hardware, approving anything outside the agent's reach - as a kind=manual aven task with exact, verified, ordered instructions. Use when the user asks for a handoff, a checklist, instructions or a task for their remaining steps, and to offer one in a single line whenever finished work still depends on such steps.
---

# human-handoff

Turn "what's left for you" into a task the user can follow weeks later without
this session: every command exact, every step ending in what they should see,
and every trap named before the step that springs it. Conventions live in
`~/.claude/includes/aven-conventions.md`; this skill files a `kind=manual`
task.

## 0. Offer, don't impose

When work ends and steps remain that only the user can do, say so in one line
("Want a `kind=manual` task for the deploy steps?") and stop. Create nothing
unless they say yes or asked for it in the first place. Steps you could do
yourself are not handoff material: do them, or say why you didn't.

## 1. Collect the steps

From the session, list everything still standing between the work and done:

- **Only the user can**: choose or enter a secret, run something needing
  their credentials or `sudo` on another machine, deploy, log in to a UI,
  click through an approval, touch hardware, decide something left open.
- **Gated on them**: things you can finish once they report back (a key, an
  ID, a URL from the deployed service). Those become "send the agent X" steps,
  with what the agent then does.
- **Follow-ups that wait on an outside event** ("once rattmann joins the
  tailnet"). Keep them, marked conditional, at the end.

Order them as they must actually be run. Then look for **hazards**: places
where the obvious order or a reflex breaks something. Look especially for
automation that acts on its own (auto-deploys pulling a branch, cron jobs,
sync), values that only take effect on first start, irreversible deletes,
and steps that leave a host unbuildable or unreachable in between.

## 2. Verify before writing

A handoff with one wrong path is worse than none: the user hits it alone.
Check every concrete thing you write against the real system, not memory:

- paths (a `DynamicUser` service's state lives in `/var/lib/private/<name>`)
- command and recipe names (`just --list`, `--help`)
- branch names and push state (`git status -sb`)
- unit names, ports, hostnames, addresses (the config that sets them)
- what a successful step prints or shows, ideally observed in this session

If something can't be checked from here, say so in that step ("unverified:
…") rather than presenting it as fact.

**Never write a secret value.** Use a placeholder, say where the value goes
and how to make one (`openssl rand -base64 24`). Public keys, emails and
addresses are not secrets.

## 3. Write the task

Title: an imperative under ~60 characters that names the outcome ("Bring up
Beszel in place of Netdata"), not "manual steps".

Description, all four sections, each non-empty ("None." is a valid body):

```markdown
<One or two sentences: what is done, what isn't, and why it stops at the user.>

## Context

What changed and where (files, commits, pushed or not), and the state the
user starts from. Enough to act without the session.

## Hazards

Each trap as a bold rule plus its reason, e.g. **Push only after step 1** —
wheatley's dotfiles-switch pulls origin/master, so its switch fails before
the secrets exist.

## Steps

1. **<Outcome of the step>**
   <exact command or action, in a fenced block when it's a command>
   <what to observe when it worked; what it means if it didn't>

## Afterwards

Cleanup, conditional follow-ups, and anything to send back to the agent
(and what the agent does with it). Notes on behaviour worth knowing later.
```

Repeat the most important hazard at the step where it bites, not only in
`## Hazards`.

## 4. File and link it

```sh
aven add "<title>" --status todo [--project <key>] \
  --metadata kind=manual --description-stdin <<'EOF'
<description>
EOF
```

Pass `--project` only when cwd doesn't already map to the project the work
belongs to. Then link it:

- the work belongs to a project epic → `aven epic add <ref> <epic>`
- it gates a checkpoint → `aven dep add <checkpoint> <ref>`, so the checkpoint
  can't go `done` before the user has done their part
- it finishes another open task → `aven related add <ref> <task>`

If the project has a project epic, run `aven-lint --epic <epic>`; otherwise
`aven-lint --project <key>`. Fix what it reports for this task.

When the user reports back, do the agent side of `## Afterwards`, then close
the task with a note of what was observed (`Evidence:` when it gates a
checkpoint).

## 5. Report

One line with the ref and title, then the one hazard that matters most right
now, such as unpushed commits that mustn't go out yet. Don't repeat the steps
in chat: the task is the handoff.
