# Changelog

All notable changes are recorded in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning adheres to [Semantic Versioning](https://semver.org/).

> **ShioriSecretary** — a "magic bookmark" you slip into a Claude model (Opus/Fable/Mythos). The changelog of a serverless secretary agent that grants a secretary to any Claude model — subscription-only, no dedicated server required.

## [1.15.0] - 2026-09-02 — a mechanical net over bare numbers in deliverables: cast the net only where the misreading cost is asymmetric

When a number carries no provenance (is it measured, projected, or inherited?), the reader
cannot decide which numbers to trust. This release adds `lint-numbers`, which picks up these
"bare numbers" — but all it picks up is the presence of **a gauge token on the same line**,
and its target is narrowed to **deliverables only**.

### Mechanism

**The problem was the allocation of attention, not notation.** Bare numbers are not a
notational habit — fix them once and they recur in a window where the writer's attention went
elsewhere (in upstream operational measurements the bare rate swung widely, dropping and
relapsing). Therefore zero is not the target (the residue does not asymptotically vanish).
The net is not "a device for eradication" but "a device that makes you notice in the window
where attention drifted."

**It is cast on the deliverable side only because the misreading cost is asymmetric.** The
reader of a handoff is your own next window, and a misreading is corrected on the spot —
adding a second gate to a side where attention already suffices is additive bias. A
deliverable, by contrast, is read by the principal and third parties beyond them, and the
cost of the misreading does not come back to the writer.

**It looks at presence only because correctness does not appear in shape.** The moment you
start writing exclusion rules (dropping IDs and dates from the candidates), that becomes the
entrance to validity judgment, and a decision that should not live in the deterministic world
leaks into code. Every line containing a digit is a candidate, and the linter stops at rough
targeting. **False negatives > false positives** — a false positive costs one re-read, while
a false negative leads straight to the danger of "trusting the green", so no single-character
or high-frequency words are taken as gauge tokens (when in doubt, leave it out = fall to the
false-positive side).

### Added

- `lint-numbers <path>` — bare-number scan of a deliverable (source md). One JSON line on
  stdout (`path` / `number_lines` / `covered` / `bare` / `bare_lines`). read-only; touches
  no config / lease / registry. **Even zero bare lines emit one line** (a silent gauge cannot
  distinguish "forgot to run" from "all green"). A completed scan exits 0 regardless of bare
  lines — the binary result is a value inside the JSON, layering no new meaning onto the
  external contract of exit 0-4. Exit 2 only when the path cannot be read
- `scripts/domain/number_lint.py` — the pure line-scan function and the gauge-token constant
  (`GAUGE_TOKENS`, 20 words). Calibrating the vocabulary is an amendment to this single
  constant and never touches the code structure — **amend it to your own operating vocabulary**

### Changed

- `DESIGN.md` §3.13 (new) — the SSoT for the presence-only and deliverables-only rationale
- `SKILL.md` / `README.md` / `commands/shiori-secretary.md` — one row in the Subcommands
  table; a Failure Modes note in SKILL that bare detection does not ride the exit code
- `ROUTINE_PROMPT.md` — the pre-send checks gain "run `lint-numbers` against the **source md**
  of a deliverable and write a gauge into each bare line before sending" (both the send-reply
  and proactive-send paths). **Report the deliverable-side and handoff-side bare rates
  separately; never merge them** (different populations)
- `STRUCTURE.md` — `number_lint.py` under `domain/`
- Language parity: all of the above updated identically in `docs_en/` / `SKILL_en.md` /
  `README_en.md`

### Compatibility

**Backward compatible** (a new subcommand only; no change to the existing receive / send /
registry paths). Running the check is **the secretary's procedure**, not a hook in the send
path — no automatic block is built into `send-reply` / `proactive-send` (the judgment is not
moved to the deterministic side).

> **Migration for existing users**: (a) the code takes effect from **your next clone / plugin
> update**. (b) the secretary actually starts running `lint-numbers` in its pre-send checks
> only **after you re-register the ROUTINE_PROMPT body into your own cloud routine** (updating
> the md in the repo does not change the procedure of a running routine). Updating the routine
> is each user's own operation — this repo rewrites nobody's routine.

## [1.14.0] - 2026-08-28 — a `cancelled` terminal for TASKS: stop recording a withdrawal as "accomplished"

TASKS had a single terminal status, `done`. Whether a request was withdrawn or its requirement
simply evaporated, the only word available for closing it was "complete." You can paper over this
by noting "this was not an achievement" in `notes`, but since **a machine reads `status` while a
human reads `notes`**, that leaves a ledger whose two halves disagree.

### Mechanism

**The asymmetry was history, not design.** The tables added later all carry a word for the
non-achieved terminal — GOALS has `abandoned`, STEPS has `skipped`, SUBJECTS has `deprecated`.
The SecretaryRole template even says of STEPS: "mark it skipped when it is no longer needed
(**never delete it silently**)." The same thinking stopped at "mark it done when finished" on the
TASKS line only because TASKS is the oldest table, and the vocabulary that grew with the
role-evolution tables was never applied back to it.

**Each table takes the verb of its own domain.** A step is skipped, a goal is abandoned, and a
TASK — **a request originating from someone else** — is cancelled. Giving every table one shared
word would be less useful than giving each the word its semantics already imply.

**Nothing downstream needed a code change.** `archive_rotate.partition_for_archive` takes an
injected predicate and hard-codes no `"done"`, and orientation decides what is active from the
**allow-set** `ACTIVE_TASK_STATUSES` (open / in_progress / blocked) — so adding a terminal word
automatically closes the active side. No raw `status == "done"` comparison exists in the codebase
(the WAL `done` is a different domain).

### Added

- `cancelled` in `Task.status` — the terminal for a task closed without meeting its completion
  criteria. Like `done` it carries `closed_at`, and Archive and orientation treat it identically

### Changed

- `TASKS.template.json`: `status` / `closed_at` / `_archive_policy` updated for two terminals
- `SecretaryRole.template.md`: the TASKS line now says "never silently mark it done" (the same
  shape as the STEPS line)
- `DESIGN.md` §3.5 archive policy and `ROUTINE_PROMPT.md`'s "whose notes are omitted" widened
  from `done` to the terminals (`done` / `cancelled`)

### Compatibility

This widens the write side only. The fail-closed validation in `canonical_record` applies **to the
write paths alone** (read paths stay forward-compatible), so older code can still **read** a
`cancelled` record — it just cannot write one. Migration order: update the code, then write
`cancelled`. No rewrite of existing data is required.

## [1.13.0] - 2026-08-25 — strict, but only over production: 7% of the 1299 was the real thing

The previous release wired up type checking but stopped short of `strict = true`. Turning it on
produced **1299 diagnostics** — a number that made it look premature.

### Mechanism

**Only 92 of the 1299 (7%) were in production code.** The remaining 1207 were in the test layer:
no-untyped-def and no-untyped-call, i.e. mechanically adding `-> None` to test functions. That
buys almost nothing in bug detection while leaving every added annotation to be reviewed. pytest
is what guarantees the tests.

**The value of strict is on the production side.** A mechanical rewrite like `os.path.join` →
`Path(a) / b` turns a str into a Path. A path where a different type flows into `sys.path` while
the tests stay green can only be closed by a type checker — and it lives in production code.
Exempting the test layer leaves that net closed.

### Added

- `strict = true` (`[tool.mypy]`)
- `ignore_errors` for the test layer (`module = ["tests.*"]`) — the reasoning is kept in a comment

### Fixed

The 92 production diagnostics break down as type-arg 64 / no-untyped-def 22 / no-any-return 4 /
no-untyped-call 1 / assignment 1. Most were the mechanical `dict` → `dict[str, Any]`, but three
places gained real information:

- **Unannotated DI seams** (`sync` in `registry_cli`, `git` / `sink` in `wal_cli`, `gateway` in
  `composition`) — the injection points now state in the type what may be injected
- **`moonshine_transcriber._model`**, the lazy triple — "not loaded (None) or a triple" is now in the type
- **`_load_owned_lease`**'s return — written out as `tuple[SessionLease, JsonLeaseStore] | None`

The two places that collapse to `Any` (`record_cls.to_dict()` and `args.handler(args)`) use `cast`
to restore the contract in the type, with the reason in a comment. Handles without stubs
(pypdfium2 / moonshine_voice) are spelled `Any` — writing the real type would collapse to `Any`
anyway under `ignore_missing_imports`.

### Notes

- `read_json_arg` returns `Any`, not `dict`. `add` / `wal-append` pass a single record dict while
  `import` passes an array; the type is not determined here (the caller `_import_records` already
  narrows it)
- The bundled `precognitive-viewer` skill sits outside `mypy_path` and is unaffected (as before)

### Verification

mypy 92→0 / ruff All checks passed / pytest 914 passed (unchanged from the baseline)

## [1.12.0] - 2026-08-25 — wiring up type checking: the 18 that were hidden behind resolution failures

CI had linting (`ruff check` / `ruff format --check`) but **no type checking**. There was no
`[tool.mypy]` section either, and running `mypy scripts` locally produced 330 diagnostics.

### Mechanism

**312 of the 330 were resolution failures.** Without `mypy_path` / `explicit_package_bases`, the
project's own modules (`domain.*` and friends) are mistaken for third-party packages that are
installed but ship no stubs. Adding the settings alone takes it from **330 to 18**. Those 18 are
the real ones.

The very impression that "there are too many diagnostics to adopt type checking" was an artifact
of the missing configuration.

### Added

- `[tool.mypy]` in `pyproject.toml` — `mypy_path` / `explicit_package_bases`. Third-party packages
  without stubs (`moonshine_voice` / `openpyxl` / `pypdfium2` / `reportlab`) get
  `ignore_missing_imports` **scoped to those modules only** (applying it globally would silently
  swallow resolution failures in our own modules too)
- A `type-check` job in CI (`mypy scripts`). The mypy version is pinned for the same reason as ruff:
  this repository is one half of a dual-maintained codebase, and unequal versions make the
  diagnostics disagree

### Fixed

- `config.py` — `registry_dir` is a `Path` on the env branch and may be `None` on the config-file
  branch, so it is declared `Path | None`
- `json_state_store.py` — the `parse` argument of `load_json_or_default` is contracted to take
  `object` (the shape of the decoded value is the caller's responsibility); narrow to `dict` before
  subscripting (2 sites)
- `ffmpeg_preprocessor.py` — an `ndarray` behaves like a `Sequence` at runtime but is not one to the
  type system. **The contract (`to_float_pcm -> Sequence[float]`) is left unchanged**; the intent is
  written with `cast`
- `registry_cli.py` — `record_cls` is a value-object class whose concrete type differs per table
  (it carries `from_dict` / `to_dict`), so it is typed `type[Any]`
- `wal_cli.py` — `payload.get()` returns `Any | None`; it is settled to `str()` after the existing guard
- `test_orientation.py` — type annotations on the dict literal and on `**kw`

### Notes

- ⚠️ **`strict` was not enabled.** Measured at 1314 errors across 69 files, which is beyond the scope
  of "wire up type checking". Going strict is left as a separate piece of work
- **914 passed — identical before and after.** `ruff check` / `ruff format --check` are unchanged too

---

## [1.11.5] - 2026-08-25 — writing down, next to each check, what it does not see

The distribution-boundary test and the parity check were both put in place today, and there was nowhere to read what they look at and what they do not.
The limits go next to the machine (docstrings); what a person still has to look at goes into the pre-distribution checklist.
The missing `usecases/observability.py` and a space-separated line in the structure diagram were recovered along the way. **No code behavior has changed.**

### Changed

- **The docstring of `test_distribution_boundary.py` now states the limits of the net** — a single occurrence of a word in any tracked file turns it red (writing the word itself in the CHANGELOG etc. trips it, so describe it indirectly) / only two words are checked, so organization names, absolute paths and the upstream's domain vocabulary are out of scope / it depends on `git ls-files`, so it does not run from a tarball
- **The pre-distribution checklist in SECURITY (both editions) gains a "JA/EN document pairs" item** — for SECURITY, `test_security_doc_parity.py` permanently checks the section count, per-section bullet count and heading marker sequence; **bullet order, translation content and the other document pairs are checked by eye** (the check sees shape only)
- **STRUCTURE (both editions) aligned with what the check can see** — `usecases/observability.py` was missing from the diagram (exposed by the parent-completeness check once `/doc-check` was changed to split slash-joined lines). The space-separated `render/ transcribe/ audio/` line under `adapters/` cannot be read by the check, so it was expanded to one entity per line

### Migration (propagation to a running routine)

**None required** — this release touches only documentation and a test docstring (outside distribution rule (3)). CLI, schema and behavior are identical to 1.11.4.

## [1.11.4] - 2026-08-25 — putting the two files that had escaped the check onto the structure diagram

Slash-joined lines in the structure diagram are read by `/doc-check` as a partial listing, so the two implementation SSoT files behind SECURITY §4/§9 went undetected while missing from the diagram.
They are expanded so the machine can see them. **No code behavior has changed.**

### Changed

- **Expanded `scripts/domain/` in STRUCTURE (both editions) to one file per line and added `output_scan.py` / `rate_limit.py`** — slash-joined lines (`models.py / media.py / …`) could not be resolved as node names by `/doc-check`, which therefore treated `domain/` as a partial listing, so the two implementation SSoT files behind SECURITY §4/§9 went undetected while missing from the diagram. After the expansion the same check enforces the completeness of `domain/` mechanically (confirmed that the two files were reported as undrawn right after the expansion, before adding them)
- **`category` of the `_goal` fixture in `test_orientation.py` is now `money`** — when the title was aligned to "半年で貯蓄30万円" in 1.11.2, `category: "work"` was left behind. The tests do not inspect category, so no behavior is affected; the value now matches the same goal in `test_registry.py`

### Migration (propagation to a running routine)

**None** — this release touches documentation and a test fixture only (outside distribution rule (3)). CLI, schema, and behavior are identical to 1.11.3.

## [1.11.3] - 2026-08-25 — the same hole opened a third time, so the eye gives way to a check

The drift by which the English SECURITY comes away from the Japanese canon was found again in §1 / §2 while reviewing the §4 / §9 fix of 1.11.2 — that makes it the **third time**.
1.11.1 compared the heading count and 1.11.2 the marker sequence, lowering the layer the eye inspects one step at a time; the same hole was sitting in the very next layer down (the bullet count).
The plan for 1.11.2 had set "make it a device on the third occurrence" as the condition, so the eye is replaced here by a machine net. **No code behavior changes.**

### Added

- **A static check of SECURITY parity across the two languages, `scripts/tests/infrastructure/test_security_doc_parity.py`** — it cuts `docs/SECURITY.md` and `docs_en/SECURITY_en.md` into sections at `## ` headings and asserts three things agree: (1) the section count, (2) the number of bullets (lines starting with `- `) per section, and (3) the status-marker sequence in the heading (✅/⚠️/📋, compared with variation selectors dropped). On failure it lists **every** mismatch with the section name and the JA/EN counts. It looks at **shape only** and judges neither translation quality nor agreement in meaning (what a machine cannot decide is not brought in here). Its subject is likewise limited to the single SECURITY pair — widening it to other pairs across the two languages can wait until drift is observed there. It is a static check that imports no production code

### Fixed

- **`docs_en/SECURITY_en.md` §1 / §2 were missing bullets present in the canon** — three bullets were translated into positions corresponding to the Japanese canon (JA is unchanged): §1's "recording unauthorized access" (the single stderr line `[security] unauthorized_update_discarded ...`, never the body), and §2's "input normalization (`normalize_input`)" and "the scope is every external input surface" (the same normalize → flag order applied to an attachment's `rendered_text` and to the audio `transcript`). **A wording inconsistency in §7** was also unified, from `population scope` to `audience scope` (aligned with the existing wording in CHANGELOG_en)

### Migration (propagation to a running routine)

**None required** — this release touches only documentation and tests, and adds no validation that fires on the read path (outside the scope of distribution rule (3)). The CLI, the schemas, and the behavior are all identical to 1.11.2, and **no prompt body re-registration is needed**.

## [1.11.2] - 2026-08-25 — letting what the English SECURITY says about the implementation catch up with the implementation

The English SECURITY of this public distribution repository publicly declared defenses that were already implemented — the outbound machine scan and rate limiting — to be "not yet implemented".
The heading correspondence confirmed across the two languages in 1.11.1 (12/12) only looks at whether the headings match; it does not detect a section whose content has drifted away from the implementation.
Because the upstream has no `docs_en/` and the EN edition is a Shiori-specific document, nothing existed to force EN to follow an implementation update made to JA. **No code behavior changes.**

### Fixed

- **`docs_en/SECURITY_en.md` §4 / §9 had not followed the implementation** — §4 lacked the ✅ (machine scan) in its heading and was missing the `redact_outbound` items entirely (the four shape-determined kinds, replacement with `[REDACTED:<kind>]`, a detection that does not block the send and leaves a single stderr line, and application at both `SendReply` and `ProactiveSend`). §9 still carried the single item "not yet implemented (a design requirement)", while the implementation has existed since v1.9.0 (a per-chat_id sliding window). **Both sections were brought in line with the content and the status markers of the Japanese canon** (JA is unchanged)

### Changed

- **Upstream vocabulary left in `scripts/tests/usecases/test_orientation.py` moved to the distributed edition's existing wording** — a leftover from fixing the subject vocabulary of the same test in 1.11.1. The replacements are taken from existing pairs in other tests, inventing no new wording. The fixture and the assertion were fixed as a pair, so **behavior and the test count are unchanged**

### Migration (propagation to a running routine)

**None required** — this release touches only documentation and tests, and adds no validation that fires on the read path (outside the scope of distribution rule (3)). The CLI, the schemas, and the behavior are all identical to 1.11.1, and **no prompt body re-registration is needed**.

## [1.11.1] - 2026-08-25 — pinning the distribution-boundary promise with a definition and a permanent check

The promise this artifact keeps as something carved out of an upstream — the three distribution rules — was only ever referenced from the CHANGELOG; the definition itself lived nowhere.
Rule (2) rested on manual grep, and as of v1.11.0 upstream-specific appellations were in fact still sitting in the bundled divination data.
**Put the definition in SECURITY §8, and make the check a permanent test.** No code behavior changes.

### Added

- **A static check of the distribution boundary, `scripts/tests/infrastructure/test_distribution_boundary.py`** — it reads every file tracked by `git ls-files` and asserts that neither of the two upstream-specific appellations appears on any line (**with no exclusion rules**; every violation is listed as `path:line`). Because the distribution boundary is the tracked set, distribution-excluded directories such as `docs/devlog/` fall outside it naturally. The forbidden words are held as unicode escapes — the test is itself a tracked file, and writing them literally would match itself and stay red forever
- **A metadata consistency check between the bundled I-Ching spec and its data** — the `format` the spec transcribes is compared against `metadata.format` in the JSON. Replacing an appellation takes edits in both data and spec; fixing only one leaves the spec describing a format name that does not exist

### Changed

- **Upstream-specific appellations were removed from the bundled I-Ching data's `metadata` (`format` / `created_by`)** — **behavior is neutral** (the code never reads `metadata`), and the divination data itself — the 64 hexagrams and 384 lines — is unchanged
- **The subjects fixture vocabulary in `test_orientation.py` moved to the distributed edition's generic wording** — even as test data, operation-specific subjects expose the outline of what an operator handles (audience scope, SECURITY §7)
- **`docs_en/DESIGN_en.md` gained a table of contents, and the section structure of §3.8 was aligned with the Japanese canon** — the headings now correspond one-to-one across the two languages, so no section exists in only one of them
- **The three distribution rules are now written out in SECURITY §8** — until now they were only referenced from the CHANGELOG with no definition anywhere, leaving their content dependent on the memory of a release. The proper-noun item of the pre-distribution checklist now names the range the permanent check covers (persona and operating-entity names)

### Migration (propagation to a running routine)

**None required** — this release touches only documentation and tests, and adds no validation that fires on the read path (outside the scope of distribution rule (3)). The CLI, the schemas, and the behavior are all identical to 1.11.0, and **no prompt body re-registration is needed**.

## [1.11.0] - 2026-08-25 — one validation across every write path, and promises that could not be kept remain as dead

There are four paths that write into the canon of memory, yet only two of them were validated.
The remaining two — the WAL's entrance and the redo at startup — let a payload that `add` would reject pass straight into the canon.
The read side is fail-open and stays silent, and `settle` marking it done plus the 24h cleanup erase the evidence too. This is **a failure mode that raises no error**.

### Added

- **`wal-drop --kind --key`** — drops an intent that has become `dead` from the WAL and **must-succeed** pushes to the fixed branch (explicitly closing out a promise you have decided not to keep). **`pending` / `done` cannot be dropped** (a missing entry likewise exits 2). Leaving no opening for silently discarding a promise you have not kept is the design decision (the SSoT as secretary ethics is "word-deed consistency" in SecretaryRole)
- **`dead` was added to the WAL's state vocabulary** (`pending` / `done` / `dead`, with an optional field carrying the reason). The schema change is purely additive: an existing line without `reason` round-trips exactly as before. `dead` is not a target of the checkpoint cleanup and does not enter `reconcile` (the input to redo) — because it is **not a redo source but the record of an unkept promise**

### Changed

- **The four write paths now share a single validation gate** — `add` / `import` / `wal-append` / `wal-redo` all call `registry_cli.canonical_record` (the judgment on unknown top-level keys, out-of-vocabulary subjects and out-of-set categories, plus canonicalization through the value objects). Write the validation per path and every new path adds one more "only this one is lax" bypass. The behavior and stderr wording of `add` / `import` are unchanged (making the name public is a pure refactor)
- **`wal-append` (registry kinds) became fail-closed** (backward incompatible) — an invalid payload exits **2** (stderr `invalid <kind> wal payload: <reason>`) and stops **before anything is written to the log**. Because the WAL is a one-way path out to the remote via a must-succeed push, carrying an invalid payload through to redo leaves "an intent that is pushed yet never applied". Rejecting it at the entrance lets you rewrite it on the spot. The payload written is the canonical form (`from_dict` → `to_dict`; an omitted `subjects` lands as `[]`, and so on). `outbound` kinds have no value object and are unchanged
- **`wal-redo` now validates each intent and quarantines the failures as `dead`** — it does not write to the registry but moves the state across with a reason attached. stdout changed to `wal redo: redone=N resent=N kept=N dead=N` (**a 4-field form with `dead` added**; passages quoting the old 3-field form have been updated). What `dead` reports is **the total left in the log**, not the number quarantined this time — every remaining dead entry prints one line per startup to stderr as `wal redo: dead <kind> key=<key>: <reason>`. **The exit stays 0** and does not stop the startup path
- **No payload values are retained in the quarantine reason** — a validation exception message can contain the rejected value itself (a name or a fragment of a note, for individuals / profile), while `dead` persists indefinitely and prints to stderr on every startup. The exception type name plus the head of its message is truncated to **the existing topic width** before being recorded (no new threshold is invented). SECURITY §7 states this alongside the retention exception (held until `wal-drop`)
- **DESIGN §3.7 is marked in its heading as the SSoT for the WAL design rationale** (the same convention as §3.9 for the resend policy and §3.12 for the startup orientation). The relationship between write paths and validation, the meaning of `dead`, and the retention per state (pending unconditional / dead unconditional / done 24h) are consolidated in that section, with the other documents kept to a summary plus a pointer

### Migration (propagation to a running routine)

1. **No body re-registration is required** — the code and SKILL.md are read every session, so if your routine does a fresh clone each session, the update takes effect from the next session. **Only the ROUTINE_PROMPT wording needs the next batched re-registration** (it explains the procedure rather than carrying a value; the same shape as 1.10.3)
2. **pending entries written before 1.11.0 are validated at the first redo** — those that pass are applied to the registry as before, and those that do not become `dead`. The window of invalid payloads that older versions accepted loosely and stacked into the WAL is closed by this first redo. Read the stderr line `wal redo: dead <kind> key=<key>: <reason>` and either re-`add` the same key with a correct payload (the next redo's `settle` marks it done = self-healing) or close it out with `wal-drop --kind <kind> --key <key>`
3. **`wal-append` now rejects with exit 2** (backward incompatible) — a registry-kind payload does not pass unless it is **the very record** you would pass to `add` (including `created_at` / `updated_at`). Where the procedure read "the payload may be identical to the record passed to `add`", it now reads "must be identical". Nothing has been written to the log at the point of rejection, so make no external promise about that intent
4. **Downgrading below 1.11.0 silently discards `dead` lines** — an older loader skips `dead` as an unknown status with a `ValueError`, and the subsequent rewrite (done-marking / checkpoint) drops it for good. This direction is irreversible and cannot be guarded in code, so do not roll back while `dead` entries remain (work them off first, or set `WAL.jsonl` aside before going back)

## [1.10.3] - 2026-08-16 — a window invariant that only surfaces under failure, and two reading paths that fail quietly

One condition that appears to hold in normal operation and breaks only under failure (the window),
one guarantee that can be misread as covering more than it does (the WAL),
and one reference that can be misjudged as missing (a graduated handoff).
All three sit on the side of **failure modes that raise no error**.

### Fixed

- **The polling-window invariant underestimated the worst-case dwell time (the real cause of the SIGTERM)** — the default window of 540s rested on the assumption that "the worst-case dwell of one cycle = the long-poll `--timeout` (30s)", but what actually pushes past the window is the HTTP-layer retry budget. `watch` rounds the final cycle's long-poll to the remaining window (`poll_timeout` in `main.py`), but **only the long-poll argument gets rounded**; the `api_gateway` running inside it (`retry_count=2` / `request_timeout=40.0`, where **5xx retries immediately without sleeping** — attempts, not waits, consume the time) knows nothing about the window. The worst-case dwell is therefore not 30s but `(2+1) × 40 = 120s`, so `540 + 120 = 660 > 600` breaks. In normal operation no 5xx appears, so `540 + 30 = 570 < 600` looked satisfied — **a condition that surfaces only under failure**, discovered when a long-running session hit a run of 5xx and died with exit 143 (SIGTERM). **The default window is lowered from 540 to 450** (`450 + 3×40 + 30 (post-fetch margin) = 600`)
- **Do not stop this class of rot with a comment** — the window (`bootstrap.sh`) and the retry budget (`api_gateway`) live in separate files and know nothing of each other, so an invariant written as a note breaks silently the moment one side moves (and it did). `test_poll_window_invariant.py` now **pins the two actual values against each other**, so moving either side turns the suite red

### Changed

- **DESIGN §3.7 now states what the WAL actually covers** — `reconcile` / `settle` decide solely on the presence of `(kind, key)` and never inspect the payload, so **updating the content of an existing record (e.g. appending to the `notes` of an existing task) is not protected by the WAL**. Queuing an intent does not make it a redo candidate because the key already exists; worse, `settle` marks it done, so **it looks applied when it was never applied** (a false positive). The WAL closes the hole "the promised record does not exist"; the hole "the promised content is not in it" can only be closed by ordering (keeping the send and the record inside the same procedure, back to back)
- **DESIGN §3.12 and SKILL now state that a graduated reference resolves in two places** — references to handoffs are bare file names with no directory component, and `handoff-archive` moves the location without changing the name. After graduation the resolution order is "directly under `handoff/` → `archive/`", and **not being directly under it does not mean it is lost**
- **The invariant in ROUTINE_PROMPT was rewritten as the actual formula** (`max_duration + (retry_count+1) × request_timeout + post-fetch margin <= bash_timeout/1000`)

### Migration (propagation to a running routine)

1. **Correcting the window does not require re-registering the body** — the registered body only reads `$SHIORI_POLL_SET_SEC`; the value lives in `bootstrap.sh`. If your routine does a fresh clone each session, **the next session starts with 450** once the update is in place. If you inject `SHIORI_POLL_SET_SEC` explicitly through the Routine Environment, that wins — verify you do not
2. SKILL.md is also read every session, so the post-graduation reference discipline arrives by the same path. **Only the ROUTINE_PROMPT wording needs a body re-registration** (it explains the formula rather than carrying the value, so the next batched re-registration suffices)
3. Side effect: a shorter window means more polling turns in an idle session (26 → 32 for a 4h session; `MAX_TURNS` follows automatically since the window is part of its formula)

## [1.10.2] - 2026-08-12 — the startup procedure pointed at a path that does not exist (SKILL.md in Step 1)

### Fixed

- **The reference in ROUTINE_PROMPT Step 1 did not exist** — it read `<INSTALL_DIR>/SKILL.md`, but by the plugin layout SKILL.md lives at `skills/shiori-secretary/SKILL.md` and **has never existed at the repository root**. The secretary failed that Read on every startup and moved on to Step 2 without taking in the Subcommands / Failure Modes / env vars from the specification. Because **the procedure does not stop when the Read fails**, the failure survived unobserved (the same shape as the silent failure DESIGN §3.12 addresses, surfacing here on the procedure side). The English edition now points at `skills/shiori-secretary/SKILL_en.md`, matching how README_en refers to it

### Migration (a running routine needs to be re-registered)

1. **The registered cloud routine body still has the old path baked in** — fixing this file alone does not reach a running routine. Re-register the body with `schedule` (upsert) in `/shiori-secretary` (the procedure is in the "cloud routine lifecycle management" section of [ROUTINE_PROMPT_en.md](./ROUTINE_PROMPT_en.md))
2. Without re-registration it still **works as before** — only Step 1 fails and the procedure continues. The secretary simply keeps running without having read the specification (its grasp of the Subcommands rests on the startup orientation and on what it remembers from practice)

## [1.10.1] - 2026-08-11 — recovering what the twin had missed, and repairing the holes in the checks

No functional change. Fixes that **existed on only one side** of the dual maintenance with the parent TelegramSecretary were recovered in both directions, and the test net and the document hierarchy were put in order.

### Fixed

- **The docstring of `FfmpegAudioPreprocessor.to_float_pcm` contradicted the implementation** — it stated that "when there is no audio stream / decoding fails, an empty array is returned (it does not crash)", but since v1.3.1 the implementation raises `AudioDecodeError` (so that silence and a failed read are not mistaken for each other). This is **the kind of error that misleads whoever reads it**, so the description was brought in line with the implementation (a Raises section)
- **The digest narrowing table in DESIGN §3.5 had not followed v1.10.0** — `GOALS / STEPS` still read "no narrowing", contradicting the 8-row table in §3.12 of the same document. It now also states that §3.12 is the SSoT for the table-to-prescription mapping

### Added

- **13 tests for the wiring and the failure paths** — `build_git` / `build_sync` (the DI shared by registry and WAL), the fallback when the PDF renderer is absent, audio decoding that breaks partway (raise when not a single frame is obtained, return what was obtained when it is partial, and do not discard what was already obtained even when the flush fails), `Retry-After: 0` and negative values, recovery from a transport error, and three kinds of invalid input at the WAL write path. Coverage 96% → **97%** (`composition` / `http_retry` / `ffmpeg_preprocessor` at 100%)
- **A bandit security scan was added to CI** — the parent's CI had one from the start and only this repository lacked it. The scope is the whole of the Python being distributed (`scripts/` plus the bundled skill `skills/`), for the same reason ruff is run over `.` — do not leave a layer that ships without being checked

### Changed

- **A table of contents was added to DESIGN and the hierarchy of §3.8 was corrected** — subjects (the 8th table) had been nested under the section for abilities (the 4th table); it is now a section that places both tables side by side (the number §3.8 is kept, along with the references to it from other documents)

## [1.10.0] - 2026-08-11 — leaving no table without a lid (indexing subjects / steps, a cap for goals)

v1.9.0 brought three tables (individuals / abilities / profile) of the lidless side into the movable
range, but **three tables — subjects, goals and steps — were left with no prescription at all**. A table
without a prescription looks harmless until it grows, and then becomes the one that brings the silent
failure back (the data never landing in context while the command exits 0). The goal of this release is not
an immediate size reduction but the state where **all 8 tables carry a prescription and the size of the
digest is structurally bounded** — which cannot be proven while goals / steps stay lidless. The
prescription follows from the nature of the table: **a cap for a table whose single record is long, an
index or count narrowing for a table whose record count grows**. The table-to-prescription mapping is
**SSoT in the 8-row list of DESIGN §3.12**.

### Added

- **`orientation --goals-cap N`** — truncates the `notes` of goals at a byte limit (the same shape as `--profile-cap` / `--abilities-cap`, one line added to `_CAP_FIELDS`). Unset by default = full text, disclosed in the heading as `full, notes cap N bytes`. goals is on the **few records, long bodies** side, so its prescription is a cap
- **`orientation --steps-latest N`** — narrows the steps index to the N newest (the same shape as `--tasks-latest`, reusing `pick_latest_by_id`). Unset by default = all records; the heading reads `latest N of M, newest last`. **0 means "drop everything"** and does not flip back to unset (the decision is `is not None`, the same convention as the existing cap knobs)

### Changed

- **Indexing subjects (full JSON → the one-line index `id | label | aliases | status | note`)** — the vocabulary grows through `subjects add` = **a table whose count grows**, so the prescription is an index rather than a cap (a cap bites only on the length of a single record). The full JSON carried `created_at` / `updated_at`, **tens of bytes of zero value for this purpose**, on every record. **No count narrowing is added** — this is the list from which you choose "by which subject to retrieve knowledge", so reducing the population would leave words you cannot pick. What is narrowed is only the per-row weight, and the truncated column is `note` (its width is aligned with the default `DEFAULT_TOPIC_WIDTH` of knowledge's `topic` column = **no new number was invented**). `aliases` is joined with `/` and empty shows as `-` (a vanishing column shifts the reading and causes misreads — the same manner as `index_knowledge`)
- **Indexing steps (full JSON → the one-line index `id | goal_id | seq | status | title`)** — being the unit of backward planning from a goal, **`done` piles up fast by design** = a table whose count grows, so its prescription is the same "one line + count narrowing" as tasks. `notes` is not included (the reading path is `steps get --key`). The twist of **selecting the newest while ordering ascending by id** is resolved the same way as in tasks / knowledge (`newest last` appears only when narrowed)
- **A change of the default output (not a breaking change)** — the rendering of two sections, subjects and steps, changes (a **specification change**, treated the same as the three-column index of v1.9.0). **The other 6 sections stay byte-identical**, fixed by a regression test — that lock was written **before** the production change and confirmed green. Nothing in the schema, the data, or the exit-code contract was touched (both indexing and caps are display-only operations)
- **Follow-through in the contact documents** — `README.md` / `skills/shiori-secretary/SKILL.md` (two options added to the orientation option table), `DESIGN.md` §3.12 (**the 8-row table of nature → prescription added as SSoT**, the boundedness formula, and the current state of "the floor that cannot be narrowed" = what remains in the floor is the four capped tables plus the one-line task summaries), `ROUTINE_PROMPT.md` (the option enumeration and the per-table reading — **the enumeration of "the full text of the small tables" had been made false by the indexing**, so it was rewritten into the four capped tables [individuals / abilities / profile / goals] and the index side [subjects / steps]), `STRUCTURE.md` (what `orientation.py` projects). Synchronized in both Japanese and English

### Migration (not a breaking change, but the reading changes)

1. **Re-read subjects / steps if you relied on their full text** — the items that do not fit on an index row (the `created_at` / `updated_at` of subjects, the `notes` of steps) are pulled with `subjects get --key` / `steps get --key`. **No data was lost** — what dropped is the rendering, not the record
2. **In a window narrowed with `--steps-latest`, check the population in the heading** — the M of `latest N of M` discloses the total count, so what the narrowing dropped never vanishes from the screen
3. **Calibrate against your own environment with the four-step procedure laid down in v1.9.0** (measure → learn how much a single knob pays → combine → measure again) — the SSoT of that procedure is the corresponding section of `ROUTINE_PROMPT.md`, and this release merely merges the two new knobs into it. **How far to narrow is decided from measurements on your own data** (the contents of a registry differ per operator, so values that paid off elsewhere are not your answer)
4. **If you run a cloud routine, the prompt body must be re-registered** — an existing routine's body is a snapshot taken at registration, so changes to ROUTINE_PROMPT (the guidance for the new options, the reading path for subjects / steps) do not reach production by updating the repository alone. **Nothing breaks if you do not re-register** (the new knobs are unset = full text, all records, and a call from an old body keeps working) — what fails to arrive is only the guidance

### Notes

- **Not a single `cc-defer` was added** — with "leave no table without a lid" as the goal of this release, deferring a lidless table onto the ledger would leave the goal itself unmet
- **The upstream (TelegramSecretary) adopted values are not distributed** — the distributed edition ships "the calibration method, not the values" (rule (1) of the three distribution rules established in v1.9.0). For the same mechanism, the upstream burns measured values into its prompt body while the distributed edition keeps the defaults (no lid) and ships the four-step procedure — the asymmetry is by design

## [1.9.0] - 2026-08-11 — the subject axis (the 8th table), caps for the lidless tables, and fail-closed write paths

v1.8.0 put the instrument in place (the size report on stderr), but **the only things it could narrow
were three terms** — the knowledge index, the notes tail, and the handoff body — and it could not reach
the full text of the small tables or the one-line task summaries, i.e. "the floor that cannot be narrowed".
The other gap: the only axis for retrieving knowledge was `category` (the type of knowing), so **there was
no path to retrieve by subject** (accounting, clients, …). v1.8.0 tried to substitute a prefix convention on
`topic` (`[subject] body`), but **a convention drifts precisely because it is not enforced**. This release
lands two pillars: **caps for the lidless tables** (bringing the floor into the movable range) and
**the SUBJECTS vocabulary table** (the 8th table). Since the subject axis fattens the digest (the subjects
table is printed in full and the index gains a subject column), **the caps are a precondition for the axis**.

### ⚠️ Breaking change (read before upgrading)

**The write paths (`add` / `import`) now reject unknown top-level fields with exit 2 (fail-closed).**
Because `from_dict` used to copy only the known keys, a typo (`subjects` → `subject`) **never raised and
vanished in silence** — leaving you to discover later that "it was registered but is not there". This release
prints the key name to stderr (`unknown field(s): subject`) and fails on the spot. **An operation that had been
issuing `add` with unknown keys will break** (breaking is the point). The validation lives **only on the write
paths**; the read paths (`list` / `get` / `orientation`) stay forward compatible with a warning only — putting
the same validation on reads would make a single record with one unknown key take down the whole `list`.

**Migration (perform around the upgrade):**

1. **Stand up the SUBJECTS table (the 8th table)** — a missing 8th-table file **does not break anything**
   (a nonexistent table reads as an empty array, and the subjects section of `orientation` simply prints `[]`).
   The first `subjects add` creates `<registry_dir>/subjects/SUBJECTS.json` along with its directory, so
   normally nothing extra is required:

   ```bash
   python scripts/main.py subjects add --json '{"id": "経理", "label": "経理", "aliases": [], "status": "active", "note": "請求・支払・決算まわり", "created_at": "2026-08-11T00:00:00Z", "updated_at": "2026-08-11T00:00:00Z"}'
   ```

   If you would rather have the template's shape (`_record_schema` / `_growth_policy`) on hand first, copy
   `templates/SUBJECTS.template.json` to `<registry_dir>/subjects/SUBJECTS.json`. Either way the vocabulary
   starts empty and grows through `subjects add` (**grow it in depth, not in width** — the domains one deals
   with differ per operator, so no initial vocabulary is shipped). When `registry_sync` is enabled, `add`
   rides the commit&push
2. **Check for records carrying unknown fields** — if a table was populated by hand or by an old script, the
   first `add` / `import` will exit 2. Read the key name on stderr and either fix the typo or drop the
   unnecessary key (the read paths do not fail, so you can inspect the actual data with `list` first)
3. **Move from the topic prefix convention (`[subject] body`) to subjects** — the prefix convention proposed in
   the v1.8.0 Notes is **retired in this release**. Existing prefixes are not broken and remain readable, but to
   make them work for narrowing, declare the vocabulary with `subjects add` and move them into `subjects[]` via
   `knowledge add` (new records) or `import --json-file` (bulk write-back of existing ones). **No bulk conversion
   script is shipped** — which subject something belongs to is a judgment, not a conversion (the same reason as
   the v1.8.0 category migration)
4. **A running cloud routine needs its prompt body re-registered** — an existing routine's body is a snapshot
   taken at registration time, so the ROUTINE_PROMPT Step 5 changes (the new options, the reading path for
   subjects, the move to 8 tables) do not reach production from a repo edit alone

### Added

- **The `SUBJECTS` registry table (the 8th)** — the vocabulary table of subjects (`id` = the canonical slug / `label` / `aliases[]` / `status` ∈ {active, deprecated} / `note` / `created_at` / `updated_at`). **A closed vocabulary is code, an open vocabulary is data** — `category` stays a frozenset, while subjects live in a registry table (so that adding one subject does not demand a redeploy. DESIGN §3.8). `status=deprecated` is retirement rather than deletion: it stops new assignments without breaking the readability of existing records. **The wiring cost was one line of `REGISTRY_SPEC` plus `Config.subjects_path`**, and CRUD, the WAL kind, the table order in orientation, and the subparser all followed automatically (the demonstration of the table-driven claim §3.8 made for abilities)
- **`knowledge.subjects[]` (assigning subjects)** — an axis orthogonal to `category`. Values are matched against the **active ids** of the SUBJECTS table, and anything out of vocabulary or deprecated **exits 2 with the candidates enumerated** (the same UX as the v1.8.0 category validation). An empty array or omission is fine (backward compatible). The judgment is the Domain pure function `invalid_subjects(subjects, active_ids)` and the data supply is the Interface — dependencies stay inward-facing, and the judgment is testable from its arguments alone
- **`orientation --knowledge-subject <id>`** — narrows the index by element match on subjects (isomorphic to `--knowledge-category`: the population remains in the `N of M` heading, and 0 matches still exits 0 = narrowing is observation, not validation). The narrowing order is **category → subject → latest** (applying latest first would make it "0 records if none of the N newest carry the subject", which breaks the meaning of narrowing)
- **Four cap knobs on `orientation`** — `--profile-cap` / `--individuals-cap` / `--abilities-cap` (byte limits on **the dominant long-text field** of each table = `content` / `identity.context_notes` / `guidance`) and `--tasks-latest` (a cap on the number of one-line summaries; the notes follow along). The rounding reuses the existing `_truncate` (bytes, character boundaries, the marker inside the width, non-positive drops everything), so **no new rounding logic was written**. Applying the cap to one field instead of rounding the whole record's JSON keeps the structure intact and preserves the reading "even when rounded, the individual record is retrievable with `get --key`". **The default (unset) is full text and all records = non-breaking**, and the heading discloses it as `full, <field path> cap N bytes`. goals / steps have no knobs (add the same shape when bloat triggers it)
- **`<table> import --json-file` (the front door for full replacement)** — it grows on all 8 tables (`REGISTRY_SPEC`-driven). **Validate all, then replace all**: a single invalid record exits 2 and **replaces nothing** (no partial writes). Duplicate keys within the batch are rejected with exit 2 as well — unlike upsert, `replace_all` does not collapse duplicates, so letting them through would produce a table where "`get` returns only the first and `remove` deletes both". stderr carries the delta `imported knowledge: N -> M records (added: …, removed: …)`. The post-replacement sync is one commit (a table is one file)
- **`templates/SUBJECTS.template.json`** — a missing template for the 8th table alone would be a structural asymmetry. `records` is an empty array per the convention of the other tables, and the example words (accounting, clients, health) live in `_record_schema` (loading real data is the secretary's domain)

### Changed

- **The knowledge index gains a third column (`id | topic` → `id | subjects | topic`)** — subjects are joined with `/`, and an unset one shows as `-` (a vanishing column makes the reader shift columns and misread — the same reason as the due_date of `summarize_task`). **The added column sits outside `topic_width`** (if adding subjects shrank the rounding width of topic, how much of the index is readable would wobble with how subjects happen to be assigned). This means **the byte-identical contract of the default output is deliberately broken in exactly one place, the index line** (an approved specification change)
- **Retirement of the topic prefix convention (`[subject] body`)** — the convention placed in the v1.8.0 Notes is withdrawn: the text is removed from `SKILL.md` / `templates/KNOWLEDGE.template.json` and replaced with guidance toward subjects. **A convention drifts precisely because it is not enforced** (missed prefixes, spelling drift, and an unfinished backfill can coexist without anyone noticing) — a data structure that can be rejected at the write path beats a convention that cannot be validated. **The past sections (v1.8.0 and earlier) are historical record and were not rewritten**
- **Broader coverage in `test_templates`** — it previously validated only the three templates PROFILE / GOALS / STEPS for key-set equality between `_record_schema` and `to_dict()`, so **an uncovered table could drift without anyone noticing**. Extending it to all 8 templated tables surfaced, as predicted, **the pre-existing drift in the KNOWLEDGE template (`subjects` missing)**, and the template was aligned to the value object (the VO is the authority on schema). When a table is added, add a line here
- **Downstream documents follow** — `README.md` (8 tables, the full orientation option list), `DESIGN.md` (§3.1 eight tables / §3.5 the cap table on the digest side / §3.8 "why subjects became the 8th table" plus why only the write paths are fail-closed / §3.10 the table count / §3.12 the bounding formula, subject narrowing, and the recomputed floor), `ROUTINE_PROMPT.md` (a subjects line and the three-column index in the per-table reading path of Step 5, the four new knobs, eight tables, the wal-append kinds), `skills/shiori-secretary/SKILL.md`, `commands/shiori-secretary.md`, `STRUCTURE.md`, `SECURITY.md`, `SETUP.md`, `templates/{KNOWLEDGE,SUBJECTS,SecretaryRole}`, `bootstrap.sh` — all synchronized across both languages

### Notes

- **Every new knob defaults to no lid (full text, all records)** — this release only adds means of narrowing; the volume of the default output does not shrink or grow (it grows only by the subject column of the index and the subjects table itself). **Decide the narrowing values from your own data** — the instrument laid down in v1.8.0 (`orientation digest: N bytes` on stderr every window) and the procedure of narrowing once that value crosses the threshold carry the new knobs as they are (ROUTINE_PROMPT Step 5). **Operating the subject axis fattens the digest**, so watch the size report of the window in which you start assigning subjects
- **The vocabulary starts empty** — the distributed `SUBJECTS.template.json` ships `records` as an empty array and bundles no initial vocabulary (the domains one deals with differ per operator). The rough guide for adding a word ("consider tidying up once you pass 10") is **provisional** (a number placed before any operational track record); the primary source for calibration is your own measurements
- **`subjects` was added to the known-entry enumeration in `bootstrap.sh`** (without it, re-provisioning a registry that has subjects/ would always warn and skip). The pre-existing inconsistency that profile / goals / steps / artifacts were never enumerated is out of scope here — it fails on the safe side (the side that does not delete), so it is booked with a `cc-defer` carrying its escalation trigger

## [1.8.0] - 2026-08-10 — validating the allowed set, self-reporting the size, and a calibration procedure for the widths

v1.7.0 corrected the **unit** of the widths, but **nobody was measuring** whether those values
were enough on real data. Measured against the upstream operation, the default orientation
produced 72,724 bytes, and even a narrowed call still produced 45,802 — both inside the range
that gets diverted. The reason the miss went unnoticed is that the output size never surfaced
anywhere observable. This release adds three things: (1) reject what should be rejected in the
Domain, (2) make the size self-report to stderr every window, and (3) ship a procedure that
decides the widths from measurement with that instrument — **put the instrument in place first,
then calibrate**.

### ⚠️ Breaking change (read before upgrading)

**The `category` of knowledge is now closed over an allowed set of 10, and the validation fires on the read path as well.**
If even one record carries an out-of-set category, `knowledge list` / `orientation` **fail
entirely with exit 2** (the validation lives in the value object's `__post_init__`, so it fires
on reads too). In particular, **the `projects` / `clients` / `procedures` examples shipped in
`templates/KNOWLEDGE.template.json` up to v1.7.0 are all outside the allowed set** — if you
followed the template, you are almost certainly affected.

**Migration (perform before upgrading):**

1. Count your current categories (the registry lives at `<registry_dir>/knowledge/KNOWLEDGE.json`):

   ```bash
   python -c "import json,collections,sys; print(collections.Counter(r['category'] for r in json.load(open(sys.argv[1],encoding='utf-8'))['records']))" <registry_dir>/knowledge/KNOWLEDGE.json
   ```

2. Rewrite each out-of-set value **by hand** into one of the 10 (no bulk-replace script is
   shipped: a mechanical substitution breaks the correspondence of meaning — reclassifying is a
   judgment, not a conversion). Rough guide: a general rule of practice → `method` / knowledge of
   the target domain → `domain-insight` / operating the tooling itself → `harness` / a recorded
   observation → `observation` / a look-up → `research` / the result of analyzing data →
   `analysis` / a design decision → `design` / a principle or stance → `philosophy` / commercial
   know-how → `business` / a settled decision → `decision`
3. Confirm `orientation` exits 0 after the rewrite, then upgrade

If you were carrying a subject axis (a project, a client, …) in `category`, move it to the
`[subject] body` prefix on `topic` (e.g. `[accounting] monthly close procedure`) — **`category`
is reserved for the axis of the type of knowing**, and the two axes are not mixed.

### Added

- **Allowed-set validation for knowledge `category` (Domain)** — only the 10 pass: `observation` / `research` / `harness` / `domain-insight` / `analysis` / `design` / `method` / `philosophy` / `business` / `decision`. **The error message enumerates the allowed set** — the asymmetry with Identity / Goal (which report only the invalid value) is deliberate: since the party being rejected is a self-driving agent, the error text itself must carry enough information to pick the right word
- **Self-reported orientation output size (Interface)** — every run writes `orientation digest: N bytes` to stderr as **a single line, always**. Above `ORIENTATION_WARNING_BYTES = 25 * 1024` it appends the diversion risk and names the four narrowing options. The threshold is **provisional** (the conservative lower bound of the upstream operation's measured 25–39KB boundary, marked with `cc-defer` as awaiting calibration). Unlike `_warn_if_oversized` (the 200KB warning on list), **it does not go quiet below the threshold** — an instrument that stays silent on the safe side lets "exit 0 but the digest never landed" pass unobserved. stdout stays byte-identical and the exit code is unchanged (fail-open)

### Changed

- **`Knowledge.from_dict` now requires `category` (backward incompatible)** — the old implementation silently turned a missing value into `"general"` via `d.get("category", "general")` (**a fail-open that generated an out-of-set value in silence**). It is now `d["category"]`, so **a `knowledge add` without a category exits 2**. Failing is the point: that silent `"general"` was precisely the breeding ground for proliferating classifications and spelling drift
- **The `category` description in `templates/KNOWLEDGE.template.json`** — the old examples (`projects` / `clients` / `procedures`) were **all outside the allowed set**, so following them verbatim made `add` exit 2. Replaced with the enumeration of the 10 and "carry the subject axis in the topic prefix"
- **A width-calibration procedure in ROUTINE_PROMPT Step 5** — the call itself **stays at the bare defaults** (a fresh install has nothing to narrow). On top of that it now documents the order in which to narrow once the warning fires, plus the upstream registry measurements as a worked example (**no single knob reached the target** — even the strongest one alone, `--knowledge-latest 30`, produced 45,802 bytes; four terms at once produced 24,152). **Those four values are measurements against the upstream data, not the right answer for yours** — decide from the `orientation digest: N bytes` of your own window
- **Downstream documents follow** — `skills/shiori-secretary/SKILL.md` (the category constraint, the topic prefix convention, the stderr report), `DESIGN.md` §3.12 (the self-reported size, the floor that cannot be narrowed, why the allowed set is enforced on the read path), `README.md` (the option table) — all synchronized across both languages

### Notes

- **The topic prefix convention (zero code change)** — the subject axis of knowledge can be carried by shaping `topic` as `[subject] body`. Keep `category` for the axis of **the type of knowing** and do not mix the two. **It is a convention, not an enforcement** — neither the code nor the data requires the prefix, and when to start and whether to backfill existing topics is the secretary's discretion. Extending the schema with `tags` would start demanding a narrowing implementation as well, so it is kept in reserve as the escalation target for when the prefix proves insufficient
- **The floor that cannot be narrowed** — what remains with every knob at its minimum (the full small tables plus the one-line task summaries) measured 11,629 bytes upstream = 45% of the target. As goals / steps fill up the floor rises further, and at that point the small tables need a projection of their own (DESIGN §3.12)
- **An existing user's routine body is a snapshot taken at registration time** — reflecting the ROUTINE_PROMPT changes requires re-registering the routine

## [1.7.0] - 2026-08-09 — meshing orientation with real-world data (byte-based widths, count narrowing)

The bounded projection introduced in v1.5.0 **counted its widths in characters**. The diversion
threshold is in bytes, so on Japanese-dominant data the effective width inflated by the ratio of
1 character ≈ 2.47 bytes, the defaults emitted 99,037 bytes, and the silent failure recurred.
**Correct the unit without moving the numbers.**

### Added

- **`orientation --knowledge-latest N`** — caps the knowledge index at the **N newest entries** (ids are assigned in date order, so a larger id is newer). The heading reads `latest N of M, newest last` — **what is selected is the newest, what is ordered stays ascending by id** (the reading convention of the index is untouched; only the population shrinks), and that twist is resolved by **disclosing the reading** rather than by re-sorting. Combined with `--knowledge-category` it **narrows first and takes latest second**. Unspecified by default = all (backward compatible, heading unchanged)

### Changed

- **Widths corrected to UTF-8 bytes (`--notes-tail` / `--topic-width` / `--handoff-cap`)** — counted in the same unit as the diversion threshold. **Only the unit was corrected; the numbers are unchanged** — the calibration intent of v1.5.0 (handovers pile up in the last 3,000–4,000 characters of notes / a topic needs only an identifiable width) was an estimate from a "1 character = 1 byte" world, so it survives intact when re-read as bytes. Rounding stops at **character boundaries** (surrogates and combining marks are never split) and the truncation marker `…` (3 bytes) sits **inside** the width. `--handoff-latest` is a count and therefore outside the unit correction
- **`0` is accepted as a valid endpoint** — `--notes-tail 0` / `--handoff-latest 0` and friends can now drop the corresponding term (the old `or DEFAULT` idiom collapsed 0 into "unspecified" = **you set it and nothing happened**, in silence. Corrected to an `is None` test)

### Notes

- With no width options given, the default output is **narrower** than v1.5.0 on Japanese data (characters → bytes). That is a correction, not a regression — the old behavior counted in a different unit than the threshold

## [1.6.0] - 2026-08-09 — blocking the handover, stage two (the archive contract, graduation, digestion) and internal normalization

Stage one (v1.5.0) separated the handover into per-window blocks and cut "the amount read",
but **the population keeps growing** — blocks only pile up, and there was no cycle of
digestion (crystallizing reusable operational knowledge into knowledge) and graduation
(taking them out of the reading path). On top of that, "orientation does not read
`handoff/archive/`" was merely a side effect of the implementation (the non-recursive
`glob("*.md")`) — implicit behavior that a single change to recursive reading would silently
break. **Pin the contract with tests, then place graduation and digestion on top of it with
minimal code.**

### Added

- **The `handoff-archive <name>...` subcommand** — moves handover blocks whose digestion is finished into `handoff/archive/` and commits & pushes them through the existing `artifacts-sync` path (no new git code; git picks it up as a rename = history is not severed). **Validate all, then move all**, so no partial success is created — a name containing path components (traversal), a missing block, or an existing same-named file in archive moves nothing and exits 2. **There is no bulk sweep (`--before <date>` etc.)**: a mechanical archive that skips digestion causes the original traces to exit unintentionally, so graduation is always by explicit naming, receiving the secretary's digestion judgment
- **`orientation --knowledge-category <cat>`** — narrows the knowledge index by exact category match. The heading becomes `knowledge (N of M records, category=<cat>, index: id | topic)` — **the M−N records dropped by narrowing remain in the `of M`** (nothing is reduced silently). 0 matches still exits 0 (narrowing is observation, not validation). With the option unset, the output is byte-identical to v1.5.0
- **The digestion workflow as a procedure (ROUTINE_PROMPT step 11)** — "reread the undigested handoff, crystallize reusable operational knowledge into knowledge, then graduate the crystallized blocks with `handoff-archive`" is added to the candidates for free time (the autonomous turn), under the existing actionability gate and only as many as one turn can handle. **The selection of what to crystallize and what to graduate stays with the secretary's judgment** — what the code holds is only the move and the reading path

### Changed

- **Promotion of the archive contract (implicit implementation behavior → a tested contract)** — "orientation reads **only the `*.md` directly under `handoff/`** (no subdirectories, no non-`.md`)" is pinned by a regression test. The receptacle for graduation is the "outside of the reading path" that this non-recursive read creates, and it is not left as a promise made in documentation alone. DESIGN §3.12 (the SSoT for startup orientation) gains the contract, graduation, and category narrowing
- **Path resolution centralized into `Config.artifacts_path`** — the local derivation in `registry_cli` is removed (the same shape as the `*_path` property family)
- **Bounded reading of handoff** — instead of opening every block and then selecting, only the top `--handoff-latest` blocks in descending name order are opened (**the output is unchanged**, and read I/O no longer grows in proportion as blocks pile up)

### Notes

- Every change is a backward-compatible **addition** (an option, a subcommand, a property). That orientation's default output is byte-identical to v1.5.0 is pinned by a snapshot test
- Graduated blocks **do not disappear** (they remain in `handoff/archive/` and in the git history). The goal is to cut the amount read; the inviolability of the append-only ledger is preserved
- Because steps 11 / 14 changed, delivering this to production **requires re-registering the cloud routine's body** (repo edits alone do not reach it)

## [1.5.0] - 2026-08-09 — countering the silent failure of startup orientation (orientation) and blocking the handover (stage one)

Reading a bloated registry at startup pushed the output past the harness limit and got it
diverted, so the command **exited 0 while the data never landed in context** — a silent
failure of starting up believing you read what you did not, which recurred across 17 windows
(measured 1.6MB: knowledge 943KB / 187 records, tasks 741KB / 8 records, the dominant term
being a single record's 165K-character notes). The side-by-side `list` of the 7 tables is
replaced with a narrowed digest, and the linearly accumulating handover is separated into blocks.

### Added

- **The `orientation` subcommand** — a read-only projection that emits, in one command, the role judgment, per-table record counts / byte sizes, the full text of the small tables (individuals/abilities/profile/goals/steps), one-line task summaries and the notes tail of active tasks, the `id | topic` index of knowledge, and the latest handoff blocks. **The output volume is bounded independently of total notes length and total knowledge content** (records may fatten; the output does not). Widths are adjustable with `--notes-tail` (default 4000) / `--topic-width` (default 120) / `--handoff-latest` (default 3) / `--handoff-cap` (default 8000)
- **Handover handoff blocks (stage one)** — the write target moved from appending to a task's `notes` to `<registry_dir>/artifacts/handoff/<UTC datetime>_<session_id>.md`. **The session window itself becomes the block boundary**, and lexicographic descending order of the naming reads them newest-first. It carries neither schema nor CRUD (only the location and naming are standardized = the DESIGN §3.10 boundary is not violated)
- **The `artifacts-sync` subcommand** — commits & pushes the deliverables layer `artifacts/` through the existing sync path (no new git code). There is no write CLI; it is the two moves of the secretary's `Write` → `artifacts-sync`
- **The 200KB `list` warning** — when a single table's `list` output exceeds 200KB, one warning line goes to stderr (stdout and exit 0 unchanged = fail-open). It turns "silence" into "voice" without regressing existing paths
- **A startup pointer in `bootstrap.sh`** — one line naming `orientation` just before `ready`. **Knowledge that prevents the failure of step X belongs upstream of X** (writing it into the data layer has no effect, because the step that reads it is the one that fails)

### Changed

- **ROUTINE_PROMPT Step 5 / SKILL.md Daily Workflow** — the side-by-side `list` procedure is replaced with a single `orientation` shot plus individual `get --key`, and the optimistic claim that "all 7 tables together are only a few thousand tokens" is removed. The mechanism of the silent failure is written down as the why (eradicating the source of the misdirection)
- **A new §3.12 in `DESIGN.md` (SSoT for startup orientation)** — the mechanism of the silent failure, the upstream-placement principle, the boundedness of the output, and the handoff block boundary. Other documents are unified to a summary plus a pointer. §3.10 gains a note on "how far a conventioned use may go"
- **`SECURITY.md` §7** — the PII scope of handoff is the same shape as the WAL (Private separation, identical commit target). Because it is free-form, however, the output-leak scan discipline is explicitly applied to writes as well

### Notes

- **Existing notes are not rewritten** (the inviolability of the append-only ledger). `orientation` keeps reading legacy accumulation as well (active tasks only, the last `notes_tail` characters), so the migration is reversible, breaks no existing data, and the tail only shrinks
- The handover's **digestion (crystallization into knowledge) and graduation (archive) are the next stage** — this release's ceiling is separation alone, and the promotion trigger (measured orientation output above 100KB) is inscribed as a `cc-defer` in `registry_cli._read_handoff_blocks`
- `handoff_latest=3` / `handoff_cap=8000` are **provisional**, extrapolated from measurement (to be calibrated by the next window's measurement). `notes_tail=4000` / `topic_width=120` / the 200KB warning threshold come from operational measurement
- Because a registered routine's body is a snapshot taken at registration time, delivering the Step 5 replacement to production **requires re-registering the body** (repo edits alone do not reach it)

## [1.4.3] - 2026-08-02 — unjamming registry writes and recovering from watch interruption

Permanent fixes for two phenomena observed in live operation of the upstream TelegramSecretary,
propagated to this repository, which shares that codebase. Nothing changes in a behavior-restricting
direction.

### Fixed

- **Seed a clone-local ignore of `__pycache__/` into the registry worktree (`bootstrap.sh`)** — when the
  registry branch accidentally tracks `.pyc` files and a script under artifacts is executed, the
  recompilation diff remains unstaged, blocking the `pull --rebase` recovery on push conflict so that
  registry writes jam with exit 1 (the trigger is the simultaneous occurrence of a remote lead and a
  `.pyc` diff). After provisioning, `__pycache__/` is idempotently appended to the clone's
  `info/exclude` — it never touches the working tree, so `git status` stays clean, and it works whether
  or not the branch has its own `.gitignore`

### Added

- **Recovery procedure from a worker-process restart in ROUTINE_PROMPT "Failure modes"** — a turn cut
  off mid-watch is an interruption, not the end of the session (offset, lease, registry, and deadline
  all survive on the persistent side). Recover by re-sourcing the env snapshot → `lease renew` (NOT
  acquire) → resuming watch with the remaining window, and **do not redo bootstrap / lease acquire /
  orientation** (re-running bootstrap hands the owner to a new session_id, and an acquire against a
  lease you already hold can evict yourself via conflict (exit 4))

### Notes

- For an existing registry branch that already tracks `.pyc` files, a one-time cleanup with
  `git rm -r --cached <the directory>` (plus optionally a branch-side `.gitignore`) is recommended. The
  seeding guarantees "never track from now on"; it does not clean up what is already tracked
- The body of a registered routine is a snapshot taken at registration time, so reflecting the
  Failure-modes addition requires re-registering the body

## [1.4.2] - 2026-07-30 — polling window 580s → 540s (restoring the invariant)

An actual SIGTERM(143) was observed in the upstream TelegramSecretary, and the same default had
survived in this repository, which shares that codebase — so the fix is propagated here. Exactly
one line changes behavior.

### Fixed

- **Default of `SHIORI_POLL_SET_SEC` lowered from 580 to 540** — the invariant governing the polling
  window is `max_duration + timeout < bash_timeout/1000`, and the combination of defaults violated it
  at `580 + 30 = 610 > 600`. Under normal conditions the "round down to the remaining window" logic in
  `main.py` absorbs the final cycle, so the violation stays invisible; but when a Telegram 5xx retry
  stretches the long poll, the cycle runs past the window, hits the bash timeout, and dies with
  SIGTERM(143). 540 leaves a 30s margin that carries exactly that retry slack. **Only an
  env-overridable default changes** — the logic is untouched (the rounding remains value-independent)
- **Spelled out the invariant in the `bootstrap.sh` comment** — it previously said only "shorter than
  the bash timeout", leaving *how much* shorter implicit. Had the formula been written down, this
  violation would have been visible by eye

### Changed

- **Synced the `$SHIORI_MAX_TURNS` computation example to the new window length** — 24h≈507 / 4h≈84 →
  **24h≈520 / 4h≈86** (the comment example in `bootstrap.sh`, `docs/ROUTINE_PROMPT.md`, and the
  Japanese edition). The formula is unchanged; the idle floor `duration/POLL_SET_SEC` simply grows by
  the amount the window shrank. The residency note in the README moves from 580s to 540s as well
- What rises is only the ceiling of the daily total-volume rate cap; the `~15 messages/h` minimum
  guarantee is unaffected

## [1.4.1] - 2026-07-29 — sealing the surfaces past the allowlist (input, output, throughput)

The `allowlist` decides only *who can reach you*. Everything past it — the input surface, the output
surface, the throughput — was undefended, and part of that defense sat in `docs/SECURITY.md` labelled
"an operational responsibility" or "a design requirement" without ever being mechanized. This release
turns those four points into implementation. Nothing here changes behavior in the direction of
stopping traffic (detection, redaction, and a throttling window only).

### Added

- **Outbound leak scan** — bot tokens, PATs, secret env variable names and local absolute paths that
  slip into an outgoing body are detected by shape and redacted (`scripts/domain/output_scan.py`).
  Applied at both `SendReply` and `ProactiveSend` (`docs/SECURITY.md` §4 named both paths as in
  scope). **Sending itself is never blocked** — blocking silences the secretary, and an outage is
  likelier than the incident it guards against. The input side stops at a flag while the output side
  redacts, because sending is irreversible
- **A record of unauthorized access** — a discarded update now leaves one line behind, carrying its
  `chat_id` and timestamp (never the body). Without a trace there is no way to observe after the fact
  who reached the bot
- **Per-chat rate limiting** — a window emitting at most 30 messages per authorized chat in any 60
  seconds (`scripts/domain/rate_limit.py`). The allowlist narrows *who* but not *how much*, which
  left open a path where a runaway authorized device burns agent turns without bound. Rejected
  messages are not appended to history (the window keeps opening even mid-flood)

### Fixed

- **Text extracted from attachments and audio was bypassing the input defenses** — NFKC
  normalization and the injection-flag check were applied to the body `text` / `caption` only, so the
  `rendered_text` produced by markitdown / pdfplumber and the audio `transcript` reached the agent
  untouched. From an authorized chat, "write the instruction in an attached PDF rather than the
  message body" arrives with `injection_flags` still empty. **The agent reads an absent flag as
  "this input has been vetted", so the mere existence of the earlier defense was handing out false
  reassurance.** Extracted bodies are untrusted binary-derived text and rank as the same class of
  external input surface as `text`/`caption`, so the render UseCase now applies the same order
  (NFKC → flag check) and the emit side merges the result into the same top-level `injection_flags`
  as the body flags

### Security

- **Raised the `Pillow` floor in the media extras from 9.1 to 12.3** — versions carrying the PYSEC
  vulnerabilities accumulated across 9.1–12.2 could still be resolved. The media path decodes images
  and PDFs — external input — arriving from authorized chats through `pypdfium2`'s `to_pil()`, so a
  vulnerable version is shut out at the declaration. 12.3.0 declares `requires-python >=3.10` and
  ships cp310 wheels, so CI's 3.10/3.11/3.12 matrix stays intact
- **Brought `docs/SECURITY.md` in line with reality** — the items mechanized above were rewritten
  from "an operational responsibility" into descriptions of what is implemented

### Notes

- The Domain additions are two pure functions and nothing else (`output_scan` / `rate_limit`). The
  UseCase layer carries only the application points and the observation logging; the direction of
  dependency is unchanged. The observation log goes to stderr, since stdout is the emitter's
  dedicated channel
- The bundled `precognitive-viewer` skill is out of scope for this release (untouched)
- Tests **685 passed** (up from 651 in v1.4.0, +34)

## [1.4.0] - 2026-07-26 — exception names renamed for N818 compliance (breaking change)

### Breaking Changes

- **Renamed 4 exception classes to carry an `Error` suffix** — the N818 rule parked in `ignore` back in v1.3.2 has been lifted, and every offender it reports is now renamed. No compatibility aliases are provided (callers importing the old names break loudly — that is precisely what the minor bump announces)

| Old name | New name | Location |
|----------|----------|----------|
| `MediaSizeLimitExceeded` | `MediaSizeLimitExceededError` | `scripts/domain/exceptions.py` |
| `AttachmentNotFound` | `AttachmentNotFoundError` | `scripts/domain/exceptions.py` |
| `AttachmentTooLarge` | `AttachmentTooLargeError` | `scripts/domain/exceptions.py` |
| `_ConfigInvalid` | `_ConfigInvalidError` | `scripts/main.py` (an internal signal at the CLI boundary, not public API) |

- The blast radius is limited to callers importing `domain/exceptions.py` directly. CLI exit codes, env variable names, and the shape and values of the emitted JSON (`skip_reason="media_size_exceeded"` and friends) are all unchanged

### Changed

- **Dropped `ignore = ["N818"]` from pyproject** — exception naming is policed by CI from now on. The v1.3.2 ignore comment named 3 classes, but letting the machine do the counting produced 4: the internal signal `_ConfigInvalid` in `scripts/main.py` had slipped out of the hand-written enumeration. Even a "reasoned ignore" rots when the list of what it covers is maintained by hand
- **Propagated the new names through SECURITY.md / SKILL.md and their English editions** — the only surviving occurrences of the old names are the historical entries in this changelog (verified with `git grep`)

### Notes

- No behavioral changes. Tests 651 passed (unchanged from v1.3.2 — evidence that the rename preserved every existing contract)

## [1.3.2] - 2026-07-26 — wider lint rules and the establishment of a CI gate

### Added

- **Introduced CI (GitHub Actions)** — lint (`ruff check .` / `ruff format --check .`) and pytest now gate push/PR. ruff is pinned to `0.16.0` (formatting output depends on the ruff version, so unless it matches the twin repo TelegramSecretary the two drift apart; upgrades are performed deliberately, as a "raise the pin and re-apply" commit)

### Changed

- **Added `N` / `B` / `SIM` / `PTH` to the ruff select** — the previous `E4,E7,E9,F,I,UP` left open the path where "dangerous idioms pile up while CI stays green". It actually detected 5 B904, 4 SIM105, 6 PTH, 1 SIM114 and 1 SIM108. 16 of them were resolved without changing behavior; the remaining one (PTH105) was deliberately deferred for the reason given below. CI now stops any of them from creeping back in
- **Restored exception chaining (B904, 5 sites)** — `raise OSError(...)` in `config.py` became `... from exc`. The originating exception (`json.JSONDecodeError` / `ValueError`) had been severed from the traceback, making the root cause of an invalid config untraceable. The message strings are unchanged
- **Moved swallowed exceptions to `contextlib.suppress` (SIM105, 4 sites)** — tmp cleanup in atomic writes, `rebase --abort`, lease clear, and the best-effort `sendChatAction`. "Swallowing is the intent" is now legible from the syntax (behavior unchanged)
- **Unified path operations on pathlib (PTH, 5 sites)** — `os.unlink` / `open()` became `Path.unlink` / `Path.open`, including 2 sites in the bundled precognitive-viewer skill
- **Made `I` (import sorting) and `UP` (pyupgrade) permanent rules and applied them wholesale** — under the narrow select, legacy spellings such as `typing.Dict` / `Optional[X]` had survived undetected. `ruff format` was also applied to every Python source, fixing the formatting standard in a machine-readable form

### Notes

- **PTH105 (the `os.replace` in atomic writes, 1 site) is excluded via per-file-ignores on `scripts/adapters/atomic_io.py`** — switching to `Path.replace` turned 6 tests red on CI's Python 3.10. The 3.10 pathlib binds `os.replace` at import time through the accessor, so with `Path.replace` the crash-injection test's `monkeypatch.setattr(atomic_io.os, "replace", ...)` slips straight through and the invariant "a crash before publish leaves the old contents intact" goes unverified on 3.10. Verifiability was chosen over lint tidiness (`requires-python` is `>=3.10`)
- N818 (the `Error` suffix on exception names, 4 items) was registered in `ignore` with a stated reason and deferred. `MediaSizeLimitExceeded` / `AttachmentNotFound` / `AttachmentTooLarge` are public API referenced by name from SECURITY.md, SKILL.md, usecases and tests, so renaming them in a patch release would break callers. The rename is bundled into the next minor as a breaking change
- N803 / N806 / N999 in the bundled precognitive-viewer skill are excluded via per-file-ignores. The divination domain is written with Japanese identifiers (天 / 地 / 人 / 得卦 / 総格), and since Japanese draws no upper/lower case distinction these are structurally guaranteed false positives. N999 is the package name `PrecognitiveViewer` itself, which cannot be renamed because it is a public import path
- No behavioral changes. Tests 651 passed (no change in count — evidence that the refactor preserved the existing contracts)

## [1.3.1] - 2026-07-26 — telling audio decode failure apart from silence

### Fixed

- **Audio decode failures were masquerading as silence** — `FfmpegAudioPreprocessor` returned an empty array even for corrupted audio and files with no audio stream, so `MoonshineTranscriber` rounded them into the same `render_status="ok"` + empty transcript as genuine silence, leaving the secretary unable to detect the read failure. Undecodable input now raises the newly added `AudioDecodeError`, which is translated to `failed`. Decoding that succeeds with 0 samples (= genuine silence) still yields `ok`, and audio that decodes partway returns the partial samples

## [1.3.0] - 2026-06-12 — the Anego (big-sis) mode (P×A role evolution, 3 new registry tables, bundled triple-divination skill)

### Added

- **Data-driven role evolution (two orthogonal P×A axes, aka the Anego (big-sis) mode)** — the secretary's face evolves with the data you entrust: a **secretary** (baseline) → entrust a profile of the principal and she becomes a **butler** (P✓: anticipation informed by preferences) → entrust active goals and she becomes a **coach** (A✓: goal reverse-planning and picked-up project management) → both make her an **anego**, a reliable big-sister figure who knows you well and pushes you forward (P×A: both wheels of person understanding × accompaniment). When every goal is achieved the A axis comes down and she graduates naturally (anego→butler). The judgment is carried by the `derive_role` pure function + the `role-status` subcommand (deterministic), and only how to play the role lives in the SecretaryRole guidance — structurally eliminating the LLM's role self-attribution hallucination (DESIGN §3.11)
- **3 new registry tables (4→7)** — `PROFILE` (person understanding = the P axis; method ∈ precognitive_viewer/json_fortune/mbti/interview/observation/other, accumulation-first) / `GOALS` (goals = the A axis; category ∈ money/work/relationship/health/other = the four major consultation courses, date Archive keyed on closed_at) / `STEPS` (steps reverse-planned from a goal; goal_id required, seq-ordered, archived in tandem with the parent GOAL). The same-shaped CRUD subcommands, value-object validation, git persistence, and **WAL word-deed consistency** as the existing 4 tables apply automatically with nothing more than a `REGISTRY_SPEC` addition (following the abilities precedent of §3.8; UseCase/Adapter untouched). Added the templates `templates/{PROFILE,GOALS,STEPS}.template.json`
- **Bundled PrecognitiveViewer (the triple-divination skill, P-axis route ①)** — the formal-reading-report skill combining Japanese name divination (the seven-grid method) × I Ching (digital shin'eki) × tarot (Rider-Waite-Smith) is bundled as a distribution build at `skills/precognitive-viewer/` (origin: the Weave Project; proper nouns sanitized, real reading-report samples excluded, the Kajiwara-school source texts not bundled pending copyright confirmation). **All divination is local computation, deterministically reproducible, with no network I/O** (structurally guaranteed by `test_self_contained.py`). It is an independent package with no import relationship to the ShioriSecretary body, and use is **opt-in** via dynamic install into ABILITIES (`abilities add`) — it is not baked into the template, leaving the experience of users who don't use divination unchanged. The examiner name is injectable via `ReadingReportPresenter(examiner=...)` (no persona name baked into the distributed artifact)
- **Three listening routes for personalization** (SecretaryRole "Listening for personalization") — ① dynamic install of the bundled PrecognitiveViewer ② introducing JSON-emitting divination sites (e.g., senjutsu.jp — in-browser computation, no data sent externally. The JSON **the user obtains themselves** is interpreted by the secretary as the LLM; no parser is pinned, so it is robust to external format changes) ③ direct listening such as MBTI. All are recorded into PROFILE with their method, with the person's explicit consent
- **Accompaniment policy (the A axis)** (SecretaryRole "Accompaniment policy") — start with one course (don't dilute the accompaniment density); verbalize the goal in dialogue → make success_criteria measurable → decompose backward from target_date into STEPS; accompaniment nudges at startup orientation and during free time (under a grant) (reusing the existing proactive-send path; no new send mechanism). The boundaries are made explicit: health = not medical advice but lifestyle accompaniment / money = not investment advice but accompaniment of household-finance behavior
- **`role-status` subcommand** — emits the current role from PROFILE/GOALS as one JSON line. The startup orientation of ROUTINE_PROMPT Step 5 calls it once alongside the 7-table bulk load

### Changed

- **Extended ROUTINE_PROMPT Step 5 into a 7-table orientation** — added profile/goals/steps and `role-status` to the bulk load, and added "an accompaniment nudge for STEPS near their deadline" to the proactive candidates for free time (**a running routine requires re-registering the prompt body**)
- **Unified the `--kind` choices of wal-append to `REGISTRY_SPEC` derivation** — eliminating the dual bookkeeping of hand-growing the argparse enumeration on every table addition (main.py's registry subparser generation is likewise SSoT-derived)
- **Appended to SECURITY §7 the sensitive-PII item for PROFILE and the PII boundary of the divination routes** — PROFILE presumes the person's consent and Private separation; none of the three divination routes structurally sends PII from the secretary to the outside

### Notes

- Tests 562 → 649 (Domain 19 + Infrastructure 13 + template integrity 6 + the bundled-skill port 42 + self-containment 3, among others). No breaking changes to existing behavior (minor bump)

## [1.2.3] - 2026-06-10 — robustness fixes and internal refactoring from the post-release full review

### Fixed

- **Fixed media download network failures crashing watch and permanently losing every message in the batch** — only the size-limit exception was caught, so network-class exceptions (CDN 4xx, expired file_id, etc.) propagated and killed watch with a traceback. Because fetch advances the offset *before* download, the messages in the crashed batch (text included) could never be re-fetched. Network failures are now flagged as `skip_reason="download_failed"` (the "flag and emit, never block" principle); only `AuthFailureError` (401) propagates. The failure contract is now documented on the MediaDownloader Port.
- **Fixed captions bypassing NFKC normalization and injection flagging** — only `text` was normalized while captions were merged raw, so a full-width injection phrase in a photo caption (the most common input shape) never got flagged. Captions now pass through `normalize_input` before merging.
- **Aligned the `init-config` argparse default with the template default `14400`** — a leftover from the 1.2.1 unification sweep; only the no-flag invocation still wrote `7200` (2h).
- **Converted unhandled CLI tracebacks into explicit input errors (exit 2)** — registry add with neither `--json` nor `--json-file` (TypeError) or a missing `--json-file` path (FileNotFoundError), a missing `--text-file` for `send-reply`/`proactive-send`, and a malformed `--pages` for `render-pdf` all crashed with exit 1 (a false "transient" signal). They now return EXIT_CONFIG_INVALID with a clear message.

### Changed

- **Made every JSON store save/rewrite atomic (tmp + `os.replace`)** — truncate-then-write could lose the whole WAL or silently wipe a registry on mid-write crashes (e.g. the ~4h cloud routine container kill): corruption → `[]` fallback load → a one-record table pushed to the remote. Consolidated into the shared helper `adapters/atomic_io.py`, which also unifies the corruption-tolerant load.
- **Lease acquisition now uses exclusive creation (`O_CREAT|O_EXCL`)** — the load→check→save TOCTOU let two containers started by simultaneous crons both win the lease. The fresh-acquisition path goes through `try_create` (OS-level exclusive create), structurally limiting the winner to one (stale takeover and self-renewal unchanged).
- **git subprocesses get a timeout (90s) and `GIT_TERMINAL_PROMPT=0`** — blocking forever on a credential prompt froze the secretary's entire turn (WAL push is the send gate). A failed `pull --rebase` now best-effort runs `rebase --abort` before raising (preventing an unrecoverable rebase-in-progress tree). git stderr is scrubbed for URL-embedded credentials, closing the remaining PAT leak path.
- **bootstrap sanity-checks the registry worktree before re-provisioning** — a misconfigured `registry_dir` no longer gets silently `rm -rf`-ed (destructive re-provision is allowed only for absent/empty/known-registry-entries-only directories; worktree comparison uses physical paths to avoid symlink false mismatches).
- **Eliminated the duplicated dependency pins** — heavy dependencies moved to the `media` / `voice` extras in pyproject; bootstrap now runs `pip install -e ".[media,voice]"` per tier (pyproject is the single source of pins; bootstrap no longer restates them). Removed `main.py` from the coverage omit list to surface the real figure (95%).
- **Unified telegram retry logic and the 429 policy** — the duplicated retry loops in api_gateway / media_downloader are extracted into `http_retry.py`. The CDN path used to die instantly on 429, ignoring Retry-After; it now honors it like the Bot API path. Also removed unreachable code (`last_exc`) and the duplicated `DEFAULT_USER_AGENT`.
- **Dropped `tolist()` in the ffmpeg preprocessor** — converting long audio to a Python list could balloon to multiple GB. Samples are passed to the transcriber as an ndarray.
- **Internal refactoring (behavior-preserving)** — the duplicated lease verification in send-reply/proactive-send extracted to a helper in `usecases/outbound.py`; attachment validation (FS I/O) moved from domain to usecases (restoring domain purity); main.py's subparser×handlers-dict double bookkeeping replaced with `set_defaults(handler=)`; private-symbol cross-module imports resolved (DI assembly moved to composition under public names); WAL checkpoint now preserves chronological interleave order; registry remove promoted to the domain pure function `remove_by`; type validation for config `agent_name`/`private_dir`; defensive int cast for `message_id`; test-suite deduplication (time helper, fakes, Config builder); docstrings aligned with actual behavior.

### Added

- **LICENSE file (MIT)** — plugin.json / marketplace.json declared `"license": "MIT"` with no license text in the repo (legal hygiene for a public repository). Also added the `license` field to pyproject.

### Notes

- A batch fix based on the post-release full review (four parallel lenses: domain+usecases / adapters / infrastructure+CLI / distribution consistency). Development residue in the distributed docs (parent-repo abbreviations, personal memory references, ghost skill references, placeholder inconsistencies) was cleaned up in the same pass. No behavioral contract changes. Tests: 512 → 562 (+50).

## [1.2.2] - 2026-06-07 — happy-path settle for proactive-send (curing false outage apologies)

### Fixed

- **Fixed a bug where a proactive-send succeeded but was still duplicated on every startup, with the duplicate carrying a false outage apology** — `proactive-send` did not mark the outbound WAL as done after a successful send (it only renewed the lease), so the next startup's `wal-redo` resent the pending entry **unconditionally**. Because outbound has no external source of truth like the registry, it cannot tell at redo time "whether it was already sent," so even successfully sent messages became resend targets — and worse, the resend text asserted "the system had gone down, so…", claiming an outage that never actually happened (a double error: pretending it was unsent when it had already been delivered). DESIGN §3.9 assumed the existence of a happy-path settle ("if a crash occurs between a successful send and the done record, a duplicate may result"), but that done record was missing from the implementation.
- **Implemented happy-path settle** — `proactive-send` now marks the corresponding outbound intent as done + pushes immediately after a successful send (`domain.wal.settle_outbound` / `usecases.wal.SettleOutboundIntent` / `wal_cli.run_wal_settle_outbound`). What redo resends is now only "genuine interruptions that crashed in the window between successful send ↔ done record," and normally sent messages are never resent again. This is a settle for outbound that has no external source of truth, symmetric to the idempotency of the registry kind (reconcile/settle).
- **Neutralized the apology prefix** — Changed the old text asserting the cause of failure (`re: what I tried to send to …, the system had gone down so I'm resending just in case`) to neutral text that is not false whether sent or unsent (`I'm delivering, just in case, the content I tried to send to … (please disregard if it has already arrived)`).

### Changed

- **`proactive-send` now encapsulates the outbound WAL lifecycle** — Consolidated the procedure that previously had the agent run three commands (`wal-append --kind outbound`→`wal-push`→`proactive-send`) into a single `proactive-send` invocation (internally `append`(pending)→`push`(must-succeed pre-send gate)→send→`settle`(done)→`push`(best-effort)). By generating created_at internally and using it as the settle key, marking done no longer depends on the agent following the procedure. When `registry_sync` is disabled, only the send occurs (backward compatible). **Updated the outbound send procedure in ROUTINE_PROMPT** (re-registration of the cloud routine prompt body is required).
- **Save attachment paths and reply_to in the outbound WAL payload** — On resend, restore not just the body but also attachments and the thread target (previously only the body was kept and attachments were dropped). Within the PII scope of SECURITY §7 (body + attachment paths + chat_id + reply_to).

### Notes

- The SSoT for the resend policy is DESIGN §3.9. The idempotency of the registry kind (reconcile/settle) and the happy-path settle of the outbound kind are now symmetric.

## [1.2.1] - 2026-06-05 — alignment with the measured 4h of cloud routine

### Fixed

- **Corrected the 24h-residency example in SETUP.md "Designing the working window" to match measurements** — The continuous uptime of a cloud routine container is about 4h by measurement (platform-dependent, may vary), and the previous example ("once-daily cron + `session_duration_sec=86340`") fell silent until the next day after being cut off at the ceiling, so it did not achieve residency. Corrected to state that residency is achieved with "a window roughly equal to the measured ceiling (e.g., `14400`) + a cron at that interval run multiple times (e.g., every 4h = JST 0/4/8/12/16/20)."

### Changed

- **Changed the template default and quickstart example for `session_duration_sec` to `14400` (4h)** — Unified the default value in `config.template.json` and the `init-config` examples (README / commands) to the residency-oriented guideline of `14400`, matched to the measured ceiling of cloud routine (about 4h) (previously `7200`). Also documented the rationale for the default in the field description of `config.template.json`.
- **Unified the production residency example from a 2h window to a 4h window** — Updated the production settings in the README quickstart notes and the `$SHIORI_MAX_TURNS` computation example in ROUTINE_PROMPT to the measured 4h (`24h≈507・2h≈42` → `24h≈507・4h≈84`). The comment computation example in `bootstrap.sh` was synced as well (behavior and formula unchanged, example values only). The `580s` window (one polling cycle length) is independent of the session window and therefore unchanged.
- **Clarified the `MAX_SECONDS` comment in `session_config.py`** — Noted that `86400` (24h) is a validity guard ceiling for the value range and is a separate layer from the platform's actual session ceiling (about 4h by measurement) (value unchanged).
- **Extended the `wal-redo` contract to "resend only for the outbound kind"** — Extended the previous contract ("replies are not resent," exclusive to redo of the registry kind) to a form that bisects entries into the registry kind and the outbound kind. **The registry kind is unchanged** (reconcile→upsert→settle; pre-send crash portions are handled by offset re-fetch, so they are not resent), and only the outbound kind is resent once in an independent loop. Added `outbound` to the choices of `wal-append --kind`.

### Added

- **`proactive-send` subcommand (proactive outbound by the secretary)** — A bidirectional capability that handles proactive sends not tied to an inbound, in contrast to replies to received messages (`send-reply`). A sibling UseCase that removes the `OffsetStore` dependency and offset advance from `SendReply`, **offset-noninterfering** (offset is the read ledger exclusive to inbound, so it is not held as a dependency = structurally seals off the accident of "advancing and missing unread inbound"). The invariants of lease verification→attachment verification→send→lease renew are inherited from send-reply. The arguments are `--chat-id` (required) / `--text-file` (required) / `--owner` / `--file` (multiple allowed) / `--reply-to`, and it **does not have `--update-id`** (the difference from send-reply). The exit codes are identical to send-reply (0/1/2/3/4). The capability boundary (the secretary is inbound by default, outbound by verbal grant) is the SSoT in SecretaryRole, and the idempotency design for resend is the SSoT in DESIGN §3.9.
- **outbound resend for `wal-redo` (the outbound version of word-deed consistency)** — Because proactive-send is not tied to an inbound and has no offset safety net, WAL resend is its only idempotency guarantee. On startup, resend the pending of the outbound kind **exactly once** (prefixing the body with the originally scheduled send time + an apology prefix) and immediately `mark_done` (resend→immediate done to prevent an infinite resend loop; it has neither TTL nor content-hash dedup). The guarantee you can buy is at-least-once, and the design neutralizes duplicates not by technology but by harmlessly absorbing "recipient confusion" at the social layer (DESIGN §3.9). Write ahead with `wal-append --kind outbound` (`chat_id` required).

## [1.1.0] - 2026-06-04 — capability catalog (abilities)

### Added

- **`abilities` management table (the 4th registry table, on par with individuals/tasks/knowledge)** — A catalog of the capabilities (skills) the secretary can exercise. It has the same CRUD (`abilities {list|get|add|remove}`), value-object validation, and git persistence via `registry_sync`. Each record holds an invocation signal `trigger`, the skill entity path `skill_path`, and invocation `guidance`, and the secretary, before responding, looks up the relevant capability with `abilities list` and exercises the external skill (e.g., a fortune-telling request → generate a divination report with the divination skill → `send-reply --file`). Added the template `templates/ABILITIES.template.json`. **A WAL target** (uniform across the 4 tables, §3.8): because self-appending a capability can accompany "a reply declaring '○○ is possible' to the other party," it is protected with WAL write-ahead just like individuals/tasks/knowledge (`wal-append --kind abilities` accepted, and startup redo also reflects abilities; this prevents the word-deed inconsistency of declaring but failing to register due to a push miss).
- **ROUTINE_PROMPT "4-table orientation"** — Expanded step 12 to make explicit the positioning of the 4 tables (with whom · what was requested · how it was judged · what can be done), the operational policy of "not just accumulating but actively looking them up before responding," and the read wiring of abilities (`trigger` match → SKILL.md of `skill_path` → `guidance`). Self-appending a capability is guarded to be limited to actually existing skills (hallucination prevention).

### Changed

- **Generalization refactor for distribution (terminology and template alignment)** — Removed the trailing spaces (`agent␣`, 56 occurrences) produced by the bulk neutralization of proper names, unified the cloud routine notation, and replaced operation-specific proper names with neutral examples. Aligned the storage-location descriptions in the management-table templates (INDIVIDUALS/TASKS/KNOWLEDGE) to `<registry_dir>` (a reflection miss of the registry_dir separation), and unified the placeholders to the convention (`<AGENT_NAME>`/`<OWNER>`). Redirected the devlog references in code comments (invalid links not present in the distribution) to DESIGN §3.6.
- **DRY consolidation of the registry/wal CLI** — Derived `_WAL_KINDS` from all kinds in `_REGISTRY_SPEC` (the SSoT) to eliminate dual management, and shared `_service`/`_build_git`/`_read_json_arg`. Added abilities to the choices of `wal-append --kind` and aligned the CLI, wal_cli, and documentation. Tidied up redundant elements of `_NON_FF_MARKERS` and unused imports in tests.
- **Aligned the positioning of archive/splitting with the design** — Corrected DESIGN §2/§3.5 and STRUCTURE to state that "when and at what unit to split/archive" belongs to the world of importance (agent judgment) and is not executed deterministically and automatically (how information is held is decided by the subject of the information). Clarified the positioning of `archive_rotate.py` as a pure function (a tool).

### Notes

- A design that places capabilities in the data layer (Private git) and **extends without touching the running body**. Once the read wiring is put through, subsequent capability additions only require a Private push of `ABILITIES.json` (no re-registration of the cloud routine prompt body needed). Concrete capabilities are not baked into the distribution template (audience scope); operation-specific capabilities are placed in Private real data.

## [1.0.0] - 2026-06-03 — official release (word-deed consistency WAL)

### Added

- **WAL write-ahead before sending a reply (guarantee of word-deed consistency, when `registry_sync` is enabled)** — A Write-Ahead Log that brings to zero the consistency violation where a registry push miss causes a reply of "registered" to be sent while it is actually not registered. Before a reply that promises a change to internal state, it appends and pushes the intent to the WAL log (`registry_dir/wal/WAL.jsonl`, the same fixed branch as the registry) (**must-succeed** = if the push cannot succeed, send-reply is not issued either), and on startup it redoes unreflected intents to the registry (key-idempotent, **replies are not resent** = pre-send crash portions are handled by offset re-fetch, a division of roles). The log also serves as short-term memory of the last 24h of conversation context; pending is kept unconditionally and done is swept after 24h at the startup checkpoint. New CLI: `wal-append` / `wal-push` / `wal-redo`. A design that solves not durability (redundancy) but consistency (word-deed consistency) through **ordering**.

### Notes

- **0.x → 1.0.0 (declaring the public API stable)** — The understanding of received media content, staged PDF processing, voice STT, sending generated artifacts back, git persistence of management tables, and WAL, all built up from 0.1.0 (the first version on 2026-05-26), have come together, reaching a complete form distributable as a conversational secretary on a cloud routine. Following SemVer, the CLI subcommand group, exit codes (0–4), config.json schema, and emit schema (`v:2`) are stabilized as the public contract (subsequent breaking changes will be announced with a major bump).

## [0.13.0] - 2026-06-03 — git persistence of management tables

### Added

- **git persistence of management tables (`registry_sync` opt-in, disabled by default)** — Persists the management tables the secretary accumulates (INDIVIDUALS / TASKS / KNOWLEDGE) to a fixed branch (`registry_branch`, default `claude/shiori-registry`) and keeps them across the fresh clones of a cloud routine. On each update (add/remove), commit & push in an event-driven manner, and on startup fetch via `registry-sync`. The commit is local-immediate and the push is best-effort (transient failures are batched and resent at the next sync). To avoid breaking independent partial updates of multiple JSON files, **force is not used** (a normal push detects conflicts via non-fast-forward rejection, and only on the exception of an external update does it fall back to `pull --rebase`; the lease guarantees a single writer).
- **`registry-sync` subcommand** — On startup, fetches the management tables from the fixed branch (only when `registry_sync` is enabled; a no-op when disabled). A fetch failure is transient (start with the previous local state and retry next time).
- **Consolidated registry settings into config.json** — Added `registry_sync` / `registry_dir` / `registry_branch` (+ `registry_remote`) to config.json (purely 2-layer) as non-secret operational settings, reflected in the template `templates/config.template.json`. Also prepared the cloud routine startup procedure (startup fetch / update push in `ROUTINE_PROMPT.md`, the `schedule` body's write-back target `outcomes`) and the setup procedure in `SETUP.md`.

### Changed

- **Separated the storage location of the management tables from volatile state** — offset/lease/media (volatile, `state_dir`) and the management tables (persistent, `registry_dir`) have opposite persistence requirements, so they were physically separated. When `registry_dir` is unset, it falls back to `state_dir` and maintains the existing behavior (backward compatible).
- **Made `registry_dir` path resolution independent of the cloud routine execution cwd** — Resolving the relative `registry_dir` in config.json with `Path.resolve()` (cwd-based) would, because the registry subcommands run with the skill directory as cwd, resolve to a wrong path outside the Private clone (untracked by git) in a multi-repo parallel-clone structure. Unified to a scheme where bootstrap makes it absolute based on the startup cwd (the repository parent) and injects it into `SHIORI_REGISTRY_DIR`, with config loading preferring the env (the same shape as making the volatile `state_dir` absolute). When the env is absent, it resolves the config.json value as before (backward compatible for local operation).

### Verified

- **Verified registry persistence on real hardware (cloud routine)** — Registered a task via Telegram → updated its details, and confirmed the add commit reaching the fixed branch `claude/shiori-registry`, the upsert idempotency of `TASKS.json` (the same id is folded into one record with `created_at` preserved and `updated_at` updated), and restoration via startup fetch. Also confirmed the soundness of the push path (the commit reaches origin).

## [0.12.0] - 2026-06-03

### Changed

- **Changed the role of `SHIORI_MAX_TURNS` from "runaway insurance" to "daily total-volume rate cap" (dynamic computation linked to duration)** — Abolished the fixed `300` (premised on a 2h session, `2h/30s≈240+buffer`) and computed it from `session_duration_sec` as `idle floor(duration/POLL_SET_SEC) + a 15 msgs/h budget` (24h→about 507, 2h→about 42). It becomes a ceiling that "guarantees ≈15 msgs/h at minimum" and follows along even if you change `session_duration_sec`. Previously the 2h-premised 300 was reused for 24h operation, causing an inconsistency where it reached the deadline early on active days. The stop axis remains the deadline (clock time), and this cap doubles as the upper bound on daily total volume = runaway insurance (because it is a cumulative counter, front-loading is possible; it is not hourly leveling). If `SHIORI_MAX_TURNS` is explicitly set via env, it can be overridden as before; the rate constant is fixed at 15 msgs/h (`_shiori_msg_per_hour` in `bootstrap.sh`). For short durations (for testing, under about 1.4h), integer division makes the computation too small / 0 and `/goal` stops immediately, so a floor=30 is laid down.

## [0.11.1] - 2026-06-02

### Fixed

- **Resolved inconsistencies between documentation and implementation** — Filled in omissions in the Subcommands table (`watch --timeout` / `lease --ttl` / `poll --timeout`, all implemented). Corrected the management-table CRUD in STRUCTURE.md to match the implementation `list|get|add|remove` (there is no `update`; `add` is an upsert).

### Changed

- **Generalized the operational settings path to be based on `<INSTALL_DIR>` (placement- and junction-independent)** — Abolished bootstrap computing the repo root as `../..` (premised on a 2-level placement) and unified to `INSTALL_DIR`, which absolutely resolves from its own physical location. Removed operation-specific directory hierarchies from the ROUTINE_PROMPT / SETUP / bootstrap comments, and added a procedure to replace `<INSTALL_DIR>` with the actual placement path when generating the `schedule` body. Removed the derived `SHIORI_REPO_ROOT` from the env snapshot.

### Removed

- **Removed the unused `watch_loop.sh`** — Removed the pass-through wrapper that had become unnecessary with the shift to a design (plan D) where `/goal` calls `watch` directly (also tidied the mentions in STRUCTURE / DESIGN / exit_codes.py).

## [0.11.0] - 2026-06-02

### Added

- **Made into a plugins-weave marketplace plugin** — Distributing ShioriSecretary as a marketplace plugin of plugins-weave. The skill is at `skills/shiori-secretary/`, the slash command at `commands/shiori-secretary.md`, and `.claude-plugin/plugin.json` was added.
- **Single canonicalization of operational settings (config.json)** — Consolidated the placeholders that required hand-replacement (persona name, private_dir, etc.) into `config.json` (`<INSTALL_DIR>/config.json`, excluded by `.gitignore`). The template is `templates/config.template.json`, generated by `init-config`. Step 0 of ROUTINE_PROMPT dynamically loads `agent_name`/`private_dir` from config.json, so **duplication and hand-replacement of the prompt body is unnecessary**.
- **Made the duration configurable (`session_duration_sec`)** — Set the session window in config.json (range 1–86400 seconds, fail-fast). It serves three roles: production (working-window adjustment) / testing (shortened for fast keep-alive verification) / observation (measuring the cloud routine execution limit).
- **`show-config` / `init-config` subcommands** — Read-only display of the current settings (secret-masked, exit 0 even if unset) and generation of config.json (range validation + `--force` guard).
- **cloud routine lifecycle integration (`/shiori-secretary schedule` / `unschedule`)** — Turned registration, update, and stop of the resident routine itself into skill operations. `schedule` is an upsert (`RemoteTrigger create` or `get→modify→update` + `init-config`), and `unschedule` is an `enabled:false` stop (physical deletion is manual in the claude.ai UI). Avoidance of the RemoteTrigger schema traps (events v1 nesting, full replacement of session_context) references the built-in `schedule` skill as canonical. The SSoT for the procedure is ROUTINE_PROMPT.md.
- **Unified documentation naming** — Unified the old name `/secretary` (7 occurrences) in the documentation to the skill's real name `/shiori-secretary`.

### Changed

- **Organized settings into purely 2 layers** — env is secrets (bot token / authorized chats) + state_dir only, and the non-secret operational settings are single-canonicalized in config.json. `config.py` reads config.json directly (`from_env`→`from_sources`). The location of `config.json` is fixed directly under `<INSTALL_DIR>` (not pointed to by env = avoiding the chicken-and-egg problem).
- **Introduced a Composition Root** — Consolidated the assembly point of dependencies into one place (`infrastructure/composition.py`). Made settings loading fail-fast and unified the construction of the media-processing stack shared by `poll`/`watch`. Each CLI handler receives assembled dependencies and does not build them itself. The definition of exit codes is also single-canonicalized. CLI, exit codes, and output are an unchanged internal refactor.

### Removed

- **Abolished the 7200 default fallback of `SHIORI_SESSION_DURATION_SEC`** — `session_duration_sec` is required in config.json (a missing value is fail-fast). bootstrap locally obtains the duration from config.json to compute the deadline and does not emit the duration setting to env (purely 2-layer).

## [0.10.1] - 2026-05-31

### Verified

- Verified PDF on-demand extraction on real hardware (cloud routine). Confirmed the flow where a received PDF is automatically imaged and the agent proactively obtains the full text (`render-pdf --text`) or trailing pages (`--pages`) as needed, across text PDFs, scanned PDFs, multi-page, large page counts, and retention-period / output-leakage scanning.

## [0.10.0] - 2026-05-31 — PDF on-demand extraction

### Changed

- Unified to a scheme that **always images all pages** of a PDF (abolished branching the path based on the presence of a text layer). Structurally eliminated misjudgments due to a stamp identical across all pages or a thin text layer.

### Added

- `render-pdf` subcommand (`--text`=extract the text layer of all pages / `--pages N-M`=image the specified pages). On receipt, only the leading pages (default 20) are pre-imaged, and the full text or pages beyond the limit are lazily generated when needed to save tokens and disk.

## [0.9.0] - 2026-05-30 — imaging PDFs (Vision path)

### Added

- Image all pages of image PDFs (scans, drawings) and have the agent progressively interpret with Vision from the leading page. Separated imaging (deterministic, low cost) and Vision (judgment, high cost), and grasp the total with `page_count` to read only what is needed.
- Added an env for the upper bound on the number of imaged pages (`SHIORI_PDF_IMAGE_MAX_PAGES`, default 20).

### Notes

- Adopted Vision rather than OCR (because of the weight of drawings and photos, and for a common foundation with the subsequent video keyframe interpretation). Derived images are subject to retention-period cleanup.

## [0.8.1] - 2026-05-30

### Verified

- Verified PDF text extraction on real hardware. Confirmed reaching the PDF body without using the `Read` tool, cleanly extracting even PDFs prone to garbling, scanned PDFs honestly returning zero text layer, and strictly rejecting spoofed files.

## [0.8.0] - 2026-05-30 — PDF text extraction

### Added

- Extract the text layer of a PDF with pdfplumber and return the body placed in `rendered_text` (the third implementation of `MediaRenderer`). Reaches PDF content without depending on the `Read` tool. Zero text layer (scanned PDFs, etc.) honestly returns "no readable text" with an empty string.

### Notes

- Adopted pdfplumber (MIT, pure-python); pymupdf (AGPL) was not adopted due to distribution constraints. The internal library is swappable via the `MediaRenderer` Port.

## [0.7.5] - 2026-05-30

### Verified

- Verified transcription of audio and video on real cloud routine (Linux) hardware. Confirmed the introduction of the audio library, transcription of various audio / video formats, safe empty responses for silent / corrupted files, retention-period cleanup, and output-leakage scanning.

### Fixed

- Unified the handling of audio corruption / undecodability as "no audio (empty transcript)" rather than "failure" (safe-side without crashing). Documented in the description of `render_status` that the handling of failure differs per medium.

## [0.7.4] - 2026-05-29

### Verified

- Confirmed on real hardware that the resident session survives through the default window (about 2 hours) and terminates normally without forced termination firing.

### Fixed

- Fixed the risk that the final cycle of long polling exceeds the window expiry and is forcibly terminated by the shell timeout. Rounded the final cycle's wait to the remaining time and guaranteed the invariant that the process meets its natural termination first.

## [0.7.3] - 2026-05-29

### Fixed

- Handled the premise that the cloud routine shell has its environment variables volatilized on each invocation (only the current directory persists). Changed to a scheme where bootstrap writes the derived environment variables to a snapshot file and each step re-reads them at its beginning. This keeps the lease-owner and expiry variables consistent across all invocations.
- Resolved the problem where a relatively specified state directory turns into a nonexistent path due to a subshell's `cd`, by making it an absolute path and fixing it at bootstrap execution time (the default operation is unchanged).

## [0.7.2] - 2026-05-29

### Changed

- Made the audio bundle (the STT library) optional. On the premise that the required dependencies differ per media type, separated into three tiers: lightweight configuration (download only) / standard (document support) / audio support. The audio bundle can be excluded with `SHIORI_BUNDLE_VOICE=false`.
- Because the license of the audio STT library changes its commercial terms by annual-revenue scale, large-scale operations should handle it by excluding the audio bundle or switching to an alternative library.

## [0.7.1] - 2026-05-29

### Verified

- Confirmed on real hardware that, with foreground long polling, the cloud routine container is kept warm throughout the window and terminates normally at expiry. Confirmed the viability of the in-session keep-alive scheme.

### Fixed

- Resolved the problem where, on startup, the media-processing dependencies (document / audio libraries) were loaded all at once and crashed, by changing to lazy construction. Heavy dependencies are not loaded until media is received, keeping resident startup always light.

## [0.7.0] - 2026-05-29 — resident long polling (keep-alive + instant response)

### Added

- A keep-alive design that keeps the session warm during the default window (about 2 hours) while responding instantly to messages. On each turn, run a foreground `watch` once; on message receipt, reply immediately → restart; with no messages, block via long-poll until the window expiry (minimal wait cost).
- Added a window-expiry exit (`--max-duration`) and a message-receipt exit (`--exit-on-message`) to `watch`. Places the stop axis on the clock (deadline) and decouples the number of polls from judgment.

## [0.6.0] - 2026-05-28 — management tables + documentation system

### Added

- Built the secretary's 3 management tables (people INDIVIDUALS / requests TASKS / handling knowledge KNOWLEDGE) in Clean Architecture 4 layers. The canon is Private JSON, and the distribution is templates only (no personal data baked in = ensuring distributability).
- CLI subcommands for management-table CRUD (`individuals|tasks|knowledge`). The operating subject is the agent, the writes are deterministic I/O, and the entry point will be wrapped by `/shiori-secretary` in the future.
- Anti-bloat measures: TASKS / INDIVIDUALS are date-archived, and KNOWLEDGE is category-split (knowledge is not discarded because accumulation is its essence).
- Prepared the design documentation system (DESIGN / STRUCTURE / SECURITY).

## [0.5.1] - 2026-05-27

### Fixed

- Fixed a design inconsistency where the input source of the reply-thread feature (the original message ID) was not included in emit, so the agent could not obtain the value to pass to a thread reply.
- Sealed the path where, on the network-error route of a send failure, a URL containing the token leaked into the exception message (unified across all send/receive paths).

## [0.5.0] - 2026-05-27 — sending generated artifacts back

### Added

- Outbound media that sends agent-generated artifacts (images, reports, documents) back to Telegram. `send-reply --file` (multiple allowed, images auto-routed to photos and others to documents), `--reply-to` for a reply thread, and a typing indicator before sending. Sent attachments exceeding the size limit (default 50MB) are rejected before sending.
- The generation of the sent file is by the agent; the code is only deterministic sending and pre-send checks.

### Notes

- Implemented selectively on the axis of "the secretary's value is understanding the content of what is received," not "porting because it's in the official plugin." markdownv2 formatting, emoji reactions, and editing sent messages are deferred under a policy of adding them when needed.

## [0.4.0] - 2026-05-27 — transcription of audio and video

### Added

- Transcribe voice / audio / video with local STT and make them readable as the body. Audio is local inference and not sent externally (safe for confidential audio). Placed in the same frame as document Markdown-ization (`rendered_text`), with the emit schema unchanged.

### Notes

- Because the license of the STT library changes its commercial terms by annual-revenue scale, a contract or a switch to an alternative library (Apache-2.0 family) is required before production commercialization.

## [0.3.1] - 2026-05-27

### Fixed

- Explicitly added the write-side libraries used by test fixtures to the development dependencies. Fixed so that tests reproduce in a clean environment with only the declared dependencies (eliminating an implicit dependency on the development machine's accidental state).

## [0.3.0] - 2026-05-27 — reading document files

### Added

- Introduced a `MediaRenderer` abstraction that Markdown-izes and reads document files (docx / pptx / xlsx · HTML). Generalized received media to the flow of "render and the agent reads."
- Structured the rendering result's state (ok / passthrough / skipped / failed). Failures are flagged per individual medium and do not abort the whole.

### Notes

- Because Markdown-ization libraries are lenient and return something even for malformed byte sequences, judging whether the content is meaningful text is the responsibility of the agent side (a division of roles that pushes inference outside the code).

## [0.2.1] - 2026-05-27

### Added

- Wired retention-period cleanup of received media into the `watch` loop (automatically deleting expired files at a fixed interval). Also added a `cleanup-media` subcommand for manual execution.

## [0.2.0] - 2026-05-27 — received media support

### Added

- Support for receiving photos, documents, and captions. Download the media of authorized messages within the size limit and emit the meta information and local path. Captions are integrated into the body.
- A size limit on media (default 20MB, DoS defense) and a retention period (default 24 hours, preventing long-term residence of confidential documents). Heavy / Medium modes toggle whether to download.
- Implemented multi-layered redaction that does not leave file URLs containing the token in logs or exceptions.

## [0.1.2] - 2026-05-26

### Added

- Unified the session ID via an environment variable and organized operation so that `lease` / `watch` / `send-reply` share the same owner (no explicit `--owner` needed, override only in emergencies). Made bootstrap support both source and exec.

## [0.1.1] - 2026-05-26

### Fixed

- Fixed a design hole where the `watch` loop did not renew the lease while idle and could be seized by a parallel session during silent periods (auto-renew at the end of a cycle, self-terminate on seizure detection).
- Re-verify the lease owner before sending (double defense). Respect the rate limit (429) and `Retry-After`.

### Changed

- Unified the policy of publishing the tests of all layers as evidence of reliability.

## [0.1.0] - 2026-05-26 — first version

### Added

- Built the foundation in Clean Architecture 4 layers. Authorization (chat_id allowlist, IDOR prevention), monotonic increase of the offset (idempotency), heartbeat + TTL lease (parallel prevention, crash self-healing), input normalization, and a prompt-injection detection flag (recorded without blocking).
- CLI subcommands (`validate-config` / `lease` / `poll` / `watch` / `send-reply` / `test`) and a bootstrap script.
- Response generation is handled by the parent-process agent, and the code only does fetch / authorization / normalization / sending (a design principle of not multiply launching inference in subprocesses).
