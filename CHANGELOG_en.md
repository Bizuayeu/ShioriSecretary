# Changelog

All notable changes are recorded in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versioning adheres to [Semantic Versioning](https://semver.org/).

> **ShioriSecretary** — a "magic bookmark" you slip into a Claude model (Opus/Fable/Mythos). The changelog of a serverless secretary agent that grants a secretary to any Claude model — subscription-only, no dedicated server required.

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
- **Unified the production residency example from a 2h window to a 4h window** — Updated the production settings in the README quickstart notes and the `$TS_MAX_TURNS` computation example in ROUTINE_PROMPT to the measured 4h (`24h≈507・2h≈42` → `24h≈507・4h≈84`). The comment computation example in `bootstrap.sh` was synced as well (behavior and formula unchanged, example values only). The `580s` window (one polling cycle length) is independent of the session window and therefore unchanged.
- **Clarified the `MAX_SECONDS` comment in `session_config.py`** — Noted that `86400` (24h) is a validity guard ceiling for the value range and is a separate layer from the platform's actual session ceiling (about 4h by measurement) (value unchanged).

### Added

- **`proactive-send` subcommand (proactive outbound by the secretary)** — A bidirectional capability that handles proactive sends not tied to an inbound, in contrast to replies to received messages (`send-reply`). A sibling UseCase that removes the `OffsetStore` dependency and offset advance from `SendReply`, **offset-noninterfering** (offset is the read ledger exclusive to inbound, so it is not held as a dependency = structurally seals off the accident of "advancing and missing unread inbound"). The invariants of lease verification→attachment verification→send→lease renew are inherited from send-reply. The arguments are `--chat-id` (required) / `--text-file` (required) / `--owner` / `--file` (multiple allowed) / `--reply-to`, and it **does not have `--update-id`** (the difference from send-reply). The exit codes are identical to send-reply (0/1/2/3/4). The capability boundary (the secretary is inbound by default, outbound by verbal grant) is the SSoT in SecretaryRole, and the idempotency design for resend is the SSoT in DESIGN §3.9.
- **outbound resend for `wal-redo` (the outbound version of word-deed consistency)** — Because proactive-send is not tied to an inbound and has no offset safety net, WAL resend is its only idempotency guarantee. On startup, resend the pending of the outbound kind **exactly once** (prefixing the body with the originally scheduled send time + an apology prefix) and immediately `mark_done` (resend→immediate done to prevent an infinite resend loop; it has neither TTL nor content-hash dedup). The guarantee you can buy is at-least-once, and the design neutralizes duplicates not by technology but by harmlessly absorbing "recipient confusion" at the social layer (DESIGN §3.9). Write ahead with `wal-append --kind outbound` (`chat_id` required).

### Changed

- **Extended the `wal-redo` contract to "resend only for the outbound kind"** — Extended the previous contract ("replies are not resent," exclusive to redo of the registry kind) to a form that bisects entries into the registry kind and the outbound kind. **The registry kind is unchanged** (reconcile→upsert→settle; pre-send crash portions are handled by offset re-fetch, so they are not resent), and only the outbound kind is resent once in an independent loop. Added `outbound` to the choices of `wal-append --kind`.

## [1.1.0] - 2026-06-04 — capability catalog (abilities)

### Added

- **`abilities` management table (the 4th registry table, on par with individuals/tasks/knowledge)** — A catalog of the capabilities (skills) the secretary can exercise. It has the same CRUD (`abilities {list|get|add|remove}`), value-object validation, and git persistence via `registry_sync`. Each record holds an invocation signal `trigger`, the skill entity path `skill_path`, and invocation `guidance`, and the secretary, before responding, looks up the relevant capability with `abilities list` and exercises the external skill (e.g., a fortune-telling request → generate a divination report with the divination skill → `send-reply --file`). Added the template `templates/ABILITIES.template.json`. **A WAL target** (uniform across the 4 tables, §3.8): because self-appending a capability can accompany "a reply declaring '○○ is possible' to the other party," it is protected with WAL write-ahead just like individuals/tasks/knowledge (`wal-append --kind abilities` accepted, and startup redo also reflects abilities; this prevents the word-deed inconsistency of declaring but failing to register due to a push miss).
- **ROUTINE_PROMPT "4-table orientation"** — Expanded step 12 to make explicit the positioning of the 4 tables (with whom · what was requested · how it was judged · what can be done), the operational policy of "not just accumulating but actively looking them up before responding," and the read wiring of abilities (`trigger` match → SKILL.md of `skill_path` → `guidance`). Self-appending a capability is guarded to be limited to actually existing skills (hallucination prevention).

### Changed

- **Generalization refactor for distribution (terminology and template alignment)** — Removed the trailing spaces (`agent␣`, 56 occurrences) produced by the bulk neutralization of proper names, unified the cloud routine notation, and replaced operation-specific proper names (PrecognitiveViewer / Expertises, etc.) with neutral examples. Aligned the storage-location descriptions in the management-table templates (INDIVIDUALS/TASKS/KNOWLEDGE) to `<registry_dir>` (a reflection miss of the registry_dir separation), and unified the placeholders to the convention (`<AGENT_NAME>`/`<OWNER>`). Redirected the devlog references in code comments (invalid links not present in the distribution) to DESIGN §3.6.
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

- **git persistence of management tables (`registry_sync` opt-in, disabled by default)** — Persists the management tables the secretary accumulates (INDIVIDUALS / TASKS / KNOWLEDGE) to a fixed branch (`registry_branch`, default `claude/ts-registry`) and keeps them across the fresh clones of a cloud routine. On each update (add/remove), commit & push in an event-driven manner, and on startup fetch via `registry-sync`. The commit is local-immediate and the push is best-effort (transient failures are batched and resent at the next sync). To avoid breaking independent partial updates of multiple JSON files, **force is not used** (a normal push detects conflicts via non-fast-forward rejection, and only on the exception of an external update does it fall back to `pull --rebase`; the lease guarantees a single writer).
- **`registry-sync` subcommand** — On startup, fetches the management tables from the fixed branch (only when `registry_sync` is enabled; a no-op when disabled). A fetch failure is transient (start with the previous local state and retry next time).
- **Consolidated registry settings into config.json** — Added `registry_sync` / `registry_dir` / `registry_branch` (+ `registry_remote`) to config.json (purely 2-layer) as non-secret operational settings, reflected in the template `templates/config.template.json`. Also prepared the cloud routine startup procedure (startup fetch / update push in `ROUTINE_PROMPT.md`, the `schedule` body's write-back target `outcomes`) and the setup procedure in `SETUP.md`.

### Changed

- **Separated the storage location of the management tables from volatile state** — offset/lease/media (volatile, `state_dir`) and the management tables (persistent, `registry_dir`) have opposite persistence requirements, so they were physically separated. When `registry_dir` is unset, it falls back to `state_dir` and maintains the existing behavior (backward compatible).
- **Made `registry_dir` path resolution independent of the cloud routine execution cwd** — Resolving the relative `registry_dir` in config.json with `Path.resolve()` (cwd-based) would, because the registry subcommands run with the skill directory as cwd, resolve to a wrong path outside the Private clone (untracked by git) in a multi-repo parallel-clone structure. Unified to a scheme where bootstrap makes it absolute based on the startup cwd (the repository parent) and injects it into `TELEGRAM_SECRETARY_REGISTRY_DIR`, with config loading preferring the env (the same shape as making the volatile `state_dir` absolute). When the env is absent, it resolves the config.json value as before (backward compatible for local operation).

### Verified

- **Verified registry persistence on real hardware (cloud routine)** — Registered a task via Telegram → updated its details, and confirmed the add commit reaching the fixed branch `claude/ts-registry`, the upsert idempotency of `TASKS.json` (the same id is folded into one record with `created_at` preserved and `updated_at` updated), and restoration via startup fetch. Also confirmed the soundness of the push path (the commit reaches origin).

## [0.12.0] - 2026-06-03

### Changed

- **Changed the role of `TS_MAX_TURNS` from "runaway insurance" to "daily total-volume rate cap" (dynamic computation linked to duration)** — Abolished the fixed `300` (premised on a 2h session, `2h/30s≈240+buffer`) and computed it from `session_duration_sec` as `idle floor(duration/POLL_SET_SEC) + a 15 msgs/h budget` (24h→about 507, 2h→about 42). It becomes a ceiling that "guarantees ≈15 msgs/h at minimum" and follows along even if you change `session_duration_sec`. Previously the 2h-premised 300 was reused for 24h operation, causing an inconsistency where it reached the deadline early on active days. The stop axis remains the deadline (clock time), and this cap doubles as the upper bound on daily total volume = runaway insurance (because it is a cumulative counter, front-loading is possible; it is not hourly leveling). If `TS_MAX_TURNS` is explicitly set via env, it can be overridden as before; the rate constant is fixed at 15 msgs/h (`_ts_msg_per_hour` in `bootstrap.sh`). For short durations (for testing, under about 1.4h), integer division makes the computation too small / 0 and `/goal` stops immediately, so a floor=30 is laid down.

## [0.11.1] - 2026-06-02

### Fixed

- **Resolved inconsistencies between documentation and implementation** — Filled in omissions in the Subcommands table (`watch --timeout` / `lease --ttl` / `poll --timeout`, all implemented). Corrected the management-table CRUD in STRUCTURE.md to match the implementation `list|get|add|remove` (there is no `update`; `add` is an upsert).

### Changed

- **Generalized the operational settings path to be based on `<INSTALL_DIR>` (placement- and junction-independent)** — Abolished bootstrap computing the repo root as `../..` (premised on a 2-level placement) and unified to `INSTALL_DIR`, which absolutely resolves from its own physical location. Removed operation-specific directory hierarchies from the ROUTINE_PROMPT / SETUP / bootstrap comments, and added a procedure to replace `<INSTALL_DIR>` with the actual placement path when generating the `schedule` body. Removed the derived `TELEGRAM_SECRETARY_REPO_ROOT` from the env snapshot.

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

- **Abolished the 7200 default fallback of `TS_SESSION_DURATION_SEC`** — `session_duration_sec` is required in config.json (a missing value is fail-fast). bootstrap locally obtains the duration from config.json to compute the deadline and does not emit the duration setting to env (purely 2-layer).

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
- Added an env for the upper bound on the number of imaged pages (`TELEGRAM_SECRETARY_PDF_IMAGE_MAX_PAGES`, default 20).

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

- Made the audio bundle (the STT library) optional. On the premise that the required dependencies differ per media type, separated into three tiers: lightweight configuration (download only) / standard (document support) / audio support. The audio bundle can be excluded with `TELEGRAM_SECRETARY_BUNDLE_VOICE=false`.
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

- Unified the policy of publishing the tests of all Expertises as evidence of reliability.

## [0.1.0] - 2026-05-26 — first version

### Added

- Built the foundation in Clean Architecture 4 layers. Authorization (chat_id allowlist, IDOR prevention), monotonic increase of the offset (idempotency), heartbeat + TTL lease (parallel prevention, crash self-healing), input normalization, and a prompt-injection detection flag (recorded without blocking).
- CLI subcommands (`validate-config` / `lease` / `poll` / `watch` / `send-reply` / `test`) and a bootstrap script.
- Response generation is handled by the parent-process agent, and the code only does fetch / authorization / normalization / sending (a design principle of not multiply launching inference in subprocesses).
