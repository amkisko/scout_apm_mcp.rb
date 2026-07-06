<!-- pray:0 ignore-comments -->

# Agent context

Do not edit managed blocks in `AGENTS.md` or provisioned files under `.agents/`.
To change shared guidance, update `Prayfile` and run `pray install`.

## Shared instructions

<!-- pray:5f23b29e -->
## Shared prayers

This project uses [pray](https://github.com/kiskolabs/pray) to install and lock shared inference input from the amkisko prayers distribution.

Install the CLI:

```sh
cargo install --git https://github.com/kiskolabs/pray --locked pray
```

Initialize or update managed input:

```sh
pray install
pray plan
pray apply
pray verify
```

Declare dependencies in `Prayfile`. Do not edit managed spans in `AGENTS.md` or `.agents/skills/`.

To refresh shared guidance after publishers release new versions:

```sh
pray update
pray plan
pray apply
```

Distribution source for amkisko-wide packages: [amkisko/prayers](https://github.com/amkisko/prayers).
<!-- pray:5f23b29e -->

<!-- pray:5ef025d3 -->
- when fixing or refactoring code, add or update tests first to expose the current bug/regression path (or missing contract), then implement the fix, then run focused and broader checks, and do not ship behavior changes without proving before/after via specs;
- test only executable logic and user-facing behavior; tests should affect coverage metrics;
- avoid tests that only assert implementation details; avoid file/page content/ordering/regex assertions; avoid duplicating tests;
- user interface texts should never mention implementation technical details;
- prefer files around <=150 LOC when cohesion allows, but never split coherent logic purely to satisfy line count; split only when it improves ownership, readability, and reviewability;
- do not use abbreviations and short names for variables, methods, classes, etc. unless it is a very common abbreviation or short name;
- avoid explanatory comments, but allow intent comments for non-obvious constraints, invariants, concurrency edges, or external contract requirements;
- keep the idea that code reflects user experience, so readability, structure, and clarity are product qualities, not optional polish;
- pull request description should include answers to questions: what problem is solved, why it matters, how the solution works, and any relevant context; if the change is non-trivial, include reproduction steps or a changelog entry with intent;
- pull request checklist: changelog entry with intent or reproduction steps when relevant, test coverage, and quality checks done;
- suggest updating docs/changelog with a short summary and PR link only when the change is significant enough to be mentioned; changelog files should use `docs/changelogs/#{date +"%Y%m%d%H%M%S"}_<title>.md`;
- when documenting ideas, issues, user requests, new features, bugfixes, chores, etc., use `docs/issues/#{date +"%Y%m%d%H%M%S"}_<title>.md`;
- validation output must list exact commands run and observed results, and never claim tests pass unless they were executed and passed;
- ignore style-only dust unless it harms correctness, operability, maintainability, or auditability under realistic load.
<!-- pray:5ef025d3 -->

<!-- pray:b2a3d4d7 -->
## Minimal implementation

Efficient means the smallest correct change, not careless or under-tested.

Before writing code, stop at each step until one applies:
- does the feature need to exist at all (YAGNI)?
- does the language stdlib or framework for this tree already cover it?
- does an existing implementation or dependency already solve it?
- can the change be one line; if so, make it one line?
- only then write the minimum code that works.

Rules:
- match the language of the directory you are changing (see Preferred stack and tools above);
- no abstractions unless the request or clear reuse needs them;
- no new dependency when stdlib, the framework for this tree, or an installed dependency suffices;
- no boilerplate the task did not ask for;
- deletion over addition; boring over clever; fewest files that stay readable (see file size guidance above);
- when a request sounds overbuilt, ask whether a simpler existing path already covers it;
- when two stdlib approaches are the same size, pick the edge-case-correct one; less code is not an excuse for a flimsier algorithm;
- document deliberate shortcuts with an intent comment: name the known ceiling (global lock, O(n²) scan, naive heuristic) and the upgrade path when that ceiling matters.

Not optional even when minimizing scope:
- input validation at trust boundaries;
- error handling that prevents data loss;
- security and accessibility (see UI/UX checks);
- calibration against real hardware and production drift when the platform ideal is not the spec;
- anything explicitly requested in the task or ticket;
- tests for non-trivial behavior per @spec/README.md and the testing bullets above; trivial one-liners need no new spec.
<!-- pray:b2a3d4d7 -->

<!-- pray:2b9051df -->
## Finite state machines

- model lifecycles with explicit finite state machines when status, allowed transitions, and side effects matter; prefer named states and guarded transitions over scattered conditionals and implicit enums alone;
- finite state machines are not only for workflow logic: they can compactly represent ordered sets or maps of strings supporting fast prefix, suffix, and fuzzy search; consider tries and automata when matching catalogs, codes, routes, or searchable vocabularies at scale.
<!-- pray:2b9051df -->

<!-- pray:7317586a -->
## Branch naming

Use kebab-case after the prefix.

Prefixes:

- `feature/<title>` — new capability
- `patch/<title>` — bugfix or chore
- `trunk/<title>` — release candidate or integration work before `main`
- `plan/<title>` — exploration or ideation

Examples:

- `feature/user-access-control`
- `patch/fix-translation`
- `trunk/2026w15`
- `trunk/2026-august-pack`
- `plan/auth-redesign-notes`
- `plan/2026-q2-roadmap`
<!-- pray:7317586a -->

<!-- pray:889f4e4f -->
---
name: changelog-update
description: Update CHANGELOG.md and docs/changelogs in amkisko house style. Use when editing changelogs, preparing releases, or syncing engineering notes into product-facing release text.
---

# Changelog update

## Two layers

1. `docs/changelogs/` — engineering draft: intent, reproduction steps, implementation notes, pull request links.
2. `CHANGELOG.md` — product-facing release notes: describe what people see and can do, not how it is built.

File name for new engineering notes: `docs/changelogs/#{YYYYMMDDHHMMSS}_<title>.md` with kebab-case title.

## Audience split

| Layer | Reader | Voice |
|-------|--------|-------|
| `CHANGELOG.md` | users, operators, product owners | outcome, screen, workflow; plain language |
| `docs/changelogs/` | engineers and reviewers | classes, files, trade-offs, links |

`CHANGELOG.md` may name an operator surface when that is the user-visible place, but still describe the workflow benefit, not internal adapter or job names.

## When to write

- user-visible features, fixes, and breaking behavior: yes;
- library upgrades, internal refactors, dev-only tooling: no unless they change a public contract or operator workflow users rely on;
- do not invent behavior; gather facts from `docs/changelogs/`, git diff, or commits since the last release tag.

## CHANGELOG.md shape

```markdown
# CHANGELOG

## X.Y.Z (YYYY-MM-DD)

- Add ...
- Fix ...
```

Rules:

- title line is `# CHANGELOG` only;
- use ISO date in parentheses on version headings when the repository follows that convention;
- unordered list with `- ` only;
- bullets stay imperative, concrete, and short;
- no marketing language;
- no negation-first hooks.

## Workflow

1. capture engineering detail in `docs/changelogs/` when the change is significant enough to mention;
2. distill user-visible outcomes into `CHANGELOG.md` when cutting a release;
3. read once for marketing odor, once for negation-led sentences, once for stray em dashes;
4. keep version headings and release tags aligned when the repository uses tagged releases.

## Relationship to pull requests

Pull request descriptions answer what problem is solved, why it matters, how the solution works, and relevant context. Changelog bullets are slightly more user-facing than commit titles but still concrete, not promotional.
<!-- pray:889f4e4f -->

<!-- pray:c711ab37 -->
---
name: engineering-audit
description: Audit code with an evidence-first, pipeline-aware review format.
---

# Engineering audit

Use when asked for an engineering audit, systems review, hot-path analysis, Big-O review, or pipeline-style inspection.

Read `engineering-audit.md` in this skill directory for dimensions, stage checks, finding format, and ranking.

## Quick reference

Pipeline:

```text
ingress → app logic → cache → database → queue → worker → external API → egress
```

Order findings by danger, then certainty, then impact, then fix cost. Present the smallest credible fix before structural rewrite. Separate missing coverage from futile coverage.
<!-- pray:c711ab37 -->

<!-- pray:c7597e52 -->
## Writing and changelog prose checks

Read once for marketing odor, once for negation-led sentences, once for stray em dashes, and once for paragraphs that break on clause instead of on scene; keep live notes and metadata honest and plain.
- repo docs under docs/issues, docs/tasks, and docs/changelogs: plain prose readable without a rendered preview—no markdown tables, bold, italic, or other styling; prioritize factual accuracy over presentation.
<!-- pray:c7597e52 -->
