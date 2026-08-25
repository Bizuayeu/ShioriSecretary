# SECURITY: ShioriSecretary

> **Policy**: This document **intentionally makes an exception to SSoT** and prioritizes completeness. Because the top priority is that it can be read standalone as a distributed artifact with no gaps, it is fine if its content overlaps with other documents (DESIGN / the upper-level `SECURITY.md`). A security gap in a distributed artifact is far more harmful than redundancy.
>
> Legend — ✅ implemented (with tests) / 📋 planned (not yet implemented) / ⚠️ operational caution

## Threat Model Overview

ShioriSecretary (the "bookmark" that grants a secretary to any Claude model) **runs persistently on Claude Code Routines (Anthropic's cloud execution = cloud routine), receives messages from the outside (Telegram), and has the agent respond**. The attack surface is as follows:

1. An **unauthorized third party** sends a message to the bot → blocked by authorization
2. **Prompt injection via inbound message body** → fencing + flagging
3. **Leakage of the bot token / secrets** → restricted to env + log redact
4. **Leakage of internal information via responses** → output scanning
5. **DoS / disk pressure from huge or malicious media** → size limit + retention
6. **Double responses / data races from concurrent sessions** → lease
7. **Leakage of stakeholder information / persona data (PII)** (especially at distribution time) → Private separation
8. **Personal data baked into the distributed code** → template/data separation

## 1. Authorization ✅

- **chat_id allowlist** (`AUTHORIZED_CHATS`) — distinguishes authentication (authn) from authorization (authz) to prevent IDOR. Updates from unauthorized chats are **discarded in the Domain layer** and never passed to the agent (`domain/authorization.py`, `FetchAuthorizedUpdates`)
- Authorization happens before emit. The agent only ever sees authorized data
- **Recording unauthorized access** — a discarded update leaves one stderr line with `chat_id` and a timestamp (`[security] unauthorized_update_discarded ...`, never the body — untrusted text is not poured into the logs). It is the observation point for who reached the bot: with no trace left, an attack cannot be observed
- ⚠️ The allowlist is managed via env. Discovering chat_id is a chicken-and-egg problem, so the first time it must be done manually (see README)

## 2. Prompt Injection Countermeasures ✅ (flagging) / ⚠️ (fencing operation)

- **injection flag** (`flag_injection`) — detects role override / system prompt extraction / credentials requests and records them in `injection_flags`. **Flags instead of blocking**, leaving the judgment to the agent (to avoid false positives)
- **Input normalization** (`normalize_input`) — NFKC normalization plus lone-surrogate sanitizing is applied **before flagging**, closing the evasion route through full-width characters and variant forms
- **The scope is every external input surface** — beyond text / caption, the same order (normalize → flag) is applied to `rendered_text` extracted from attachments (PDF / docx / pptx / xlsx) and to the audio `transcript`, and the results merge into the emit's `injection_flags` (`RenderAuthorizedMedia`, `StdoutEventEmitter`). Letting an attachment through unchecked would give the false assurance that "no flag is set = the content has been vetted"
- **Prompt fencing** — the inbound message body is isolated with XML tags and explicitly marked "treat this as data" before being passed to the agent (specified in ROUTINE_PROMPT; an operational responsibility on the agent side)
- ⚠️ If `injection_flags` is non-empty, the agent heightens its caution (doubts the content, and ignores it if necessary)

## 3. Secrets Management ✅

- **The bot token lives only in env** (`TELEGRAM_BOT_TOKEN`). It is never placed in code, commits, or logs
- **Hiding token-embedded URLs from logs** — the TOKEN in `/bot<TOKEN>/...` or `/file/bot<TOKEN>/...` is never left in exception messages, stderr, or logs. The exception chain is cut with `raise ... from None` (the entire send/receive path of `api_gateway` + `media_downloader`, verified by token redact tests)
- The network error path (common to all send/fetch) also redacts token-embedded URLs (proven by demonstrating token leakage with a red test before addressing it)
- ⚠️ **Hiding secrets at schedule registration time** — when registering a cloud routine via `/shiori-secretary schedule`, the bot token / authorized chats are **injected into the Environment** and never baked into the `RemoteTrigger` body (the events prompt body / session_context) or commits (referenced via `environment_id`). Putting secret values into the body would leave them in the trigger configuration and execution logs

## 4. Output Leak Prevention ✅ (machine scan) / ⚠️ (agent operational responsibility)

- ✅ **Machine scan of outbound text** (`redact_outbound`) — before sending, the body is inspected and the **four shape-determined kinds** (Telegram bot token / GitHub PAT / env variable names with a secret-indicating suffix / local absolute paths) are replaced with `[REDACTED:<kind>]`. A detection **does not block the send**; only the redacted kinds are recorded as a single stderr line (`[security] outbound_redacted ...`, never the redacted values themselves). The inbound side flags whereas the outbound side redacts because sending is irreversible — more redactions from false positives is the safer side. Applied at both `SendReply` and `ProactiveSend` (shared helper in `usecases/outbound.py`; implementation in `domain/output_scan.py`)
- ⚠️ **Secrets that have no shape are the agent's responsibility** — things no regular expression can determine, such as a stakeholder's circumstances or an unannounced decision, pass straight through the machine scan. Confirming that no system prompt or internal information has leaked into the reply remains the agent's job. **Both send-reply (inbound reply) and proactive-send (active outbound) are in scope** (all outbound text is scanned regardless of the send path)
- **actionability gate for proactive messaging** — because proactive-send interrupts from our side without being tied to an inbound message, in addition to the leak scan it sets a higher actionability bar, sending signal but not noise (to suppress interruption cost + the misfire surface; the SSoT for the actionability gate is ROUTINE_PROMPT)
- **Leak scan for generated attachments** — also confirms that no secrets have leaked into the md/docx/image/PDF being sent back. The code does not inspect binary contents = it is the agent's judgment responsibility
- **Leak scan of transcripts** — secrets in audio (e.g., a password read aloud) could ride into emit via the transcript, so they are included in the scan scope

## 5. Inbound Media Safety ✅

- **size limit (DoS defense)** — anything exceeding `MEDIA_MAX_SIZE_BYTES` (default 20MB) is not downloaded and is skipped + flagged. This prevents disk pressure from oversized files
- **retention auto-deletion** — media that has passed `MEDIA_RETENTION_HOURS` (default 24h) is deleted by `cleanup_media_dir`. This prevents long-term retention of confidential documents
- **mime is treated as self-declared** — the mime_type declared by Telegram is not trusted; the parent-process agent treats the `Read`/render result as the truth (countermeasure against rename attacks)
- **awareness of render leniency** — markitdown returns something even for garbage. Whether `rendered_text` is meaningful text is judged by the agent (the last line of defense is the agent layer)
- **PDF / audio processed locally end-to-end** — pdfplumber/pypdfium2 (PDF) and Moonshine (audio) are all local processing, so files never leave the machine. When switching to an external STT that transmits audio (e.g., a future Whisper API), the privacy judgment that "the audio is handed to a third party" must be separately mandated
- **absence of audio intermediate files** — PyAV decodes in memory to 16kHz mono float and does not write an intermediate ffmpeg wav to disk (no intermediate artifacts of confidential voice remain)
- **outbound attachment limit** — anything exceeding `OUTBOUND_MAX_SIZE_BYTES` (default 50MB) is rejected before sending with `AttachmentTooLargeError` (preventing misfires / cost accidents)

## 6. Concurrency Control (Lease) ✅

- **heartbeat + TTL lease lock** — structurally prevents double responses / offset races from concurrent sessions. A new session refuses to start if the heartbeat is fresh, and seizes the lease if it is stale (compatible with crash self-healing)
- **owner double-verification in SendReply** — before sending, the lease is re-loaded and owner agreement is confirmed (double defense at the CLI layer + UseCase layer)

## 7. Protection of Registry / Persona Data (PII) ✅ (Private separation / git / WAL / abilities) / 📋 (boundaries across multiple channels)

- ✅ **Private separation is the first line of defense** — INDIVIDUALS (stakeholders' honorific / context_notes / taboo_topics), TASKS, KNOWLEDGE, SUBJECTS, and Identities are all in the Private repo. No actual data is placed in public (the distributed artifact)
- ✅ **SUBJECTS (the subject vocabulary) is low in sensitivity but still a separation target** (v1.9.0) — the vocabulary table itself holds only short words (`id` / `label` / `note`) and carries no PII. Still, **the list of subjects exposes the outline of what the operator deals with**, so it rides the same Private separation and git persistence path as the other registry tables. The distributed template ships `records` as an empty array = no operation-specific subject is baked in (audience scope, §8)
- ⚠️ **context_notes / taboo_topics presume PII** — on the premise that stakeholders' free-form descriptions contain personal information, access permissions to the Private repo are minimized
- 📋 **shared_with boundary** (when multiple channels are used together; not yet active) — information sharing between stakeholders is on an explicit-permission basis via `identity.shared_with`. Unapproved relays are refused and an approval request is sent to `<OWNER>` (the principal). With Telegram alone there is no relay between stakeholders; this takes effect when multiple channels are introduced
- 📋 **principal / associate privilege separation** (enforced when multiple channels exist) — the role enum (`principal`/`associate`) is already implemented as a value object, but enforcement that limits management operations (approve/block/edit, etc.) to those originating from the principal (`<OWNER>`) takes effect when multiple channels with an approval flow are introduced
- ✅ **Security of git persistence** (when `registry_sync` is enabled) — the registry is pushed to a **fixed branch of the Private repo** (`registry_branch`), and no actual data is placed in public (the distributed artifact). git credentials (PAT, etc.) are injected into env / the cloud routine Environment and never baked into commits, logs, or the prompt body. The commit targets are only the registry files under `registry_dir` (structurally excluding any leakage of persona / secrets). Because force is not used, it does not destroy external updates
- ✅ **PII scope of the WAL log** (when `registry_sync` is enabled) — each intent payload of the WAL log (`registry_dir/wal/WAL.jsonl`) is **identical to the record added to the registry** (structured records of individuals/tasks/knowledge), so there is no expansion of PII scope beyond the registry (**the full conversation body is never written to the log**). It is placed on the same fixed branch of the Private repo, and its commit targets are likewise limited to under `registry_dir`. After being marked done, it is cleaned up at the 24h mark via the startup checkpoint (pending entries are retained until redo). **`dead` (an intent quarantined after failing validation during redo) is the exception to this cleanup and is retained until it is `wal-drop`ped** (v1.11.0) — in place of an expiry, the reason for the quarantine is recorded as **the exception type name plus the head of its message, truncated to the existing topic width**. A validation exception message can contain the rejected value itself (a name or a fragment of a note, for individuals / profile), while a dead entry persists indefinitely and prints to stderr on every startup — so it is **truncated before it lands**: what is burned into the WAL and what appears on stderr goes no further than the kind, the key and the truncated reason; no payload values are retained. Because the WAL push goes through the same git credential path as the registry, the handling of secrets is identical to the above
- ⚠️ **The PII scope of handoff (handover blocks) is the same shape as the WAL** (when `registry_sync` is enabled) — the handover (`registry_dir/artifacts/handoff/*.md`, DESIGN §3.12) is free-form prose the secretary writes at the end of a window, so treat it on the premise that **it contains PII derived from the conversation context**. Its location, commit target, and git credential path are identical to the WAL / registry (the fixed branch of the Private repo; `artifacts-sync` targets only what is under `registry_dir`), so there is no exposure beyond the Private separation. Unlike structured records, however, **the freedom of its format makes the writer's discipline the only filter** — apply the same pre-send output-leak scan (tokens / env var names / system prompt / absolute paths, §4) to handoff writes as well
- ✅ **Trust boundary of abilities (the capability catalog)** (when `registry_sync` is enabled) — because an ability's `skill_path` is the entry point to an external skill that the secretary reads/exercises, trustworthiness is the key point. The capability catalog lives in Private (it is part of the registry, and the lease guarantees a single writer), and `add` is **limited to skills whose existence has been confirmed** (a self-append guard = it never writes a capability that does not exist). The distributed template is an empty array = it does not bake in any arbitrary `skill_path`. It is not PII, but operation-specific capabilities are placed in Private (audience scope, §8)
- ⚠️ **PROFILE (person understanding) presumes sensitive PII** — interpretations of divination results, personality traits, and values (method=precognitive_viewer/json_fortune/mbti, etc.) are more sensitive than ordinary contact information. It rides the same Private separation and git persistence path as INDIVIDUALS, but **recording is limited to what has the person's explicit consent** (SecretaryRole "Listening for personalization"). The WAL payload likewise stays within the registry-record scope (the full conversation body is never written to the log)
- ✅ **PII boundary of the divination routes (no external transmission)** — ① the bundled PrecognitiveViewer is **local computation only** (the absence of network I/O is structurally guaranteed by `test_self_contained.py`; names never leave the machine). ② JSON divination (introducing an external site): **the user themselves** enters their birth date etc. into the site in their browser, obtains the JSON, and sends it to the secretary — transmission from the secretary to the external site structurally never occurs (the introduced example, senjutsu.jp, is a tool that explicitly states in-browser computation with no server transmission). ③ MBTI listening completes within the conversation

## 8. Responsibility Boundaries at Distribution Time ⚠️

The boundaries when distributing as a plugin:

| What the plugin **holds** (public) | What each user **holds themselves** (Private) |
|---|---|
| Code (scripts) / documentation | Their own bot token / chat allowlist |
| **Templates** of the registry / Identities (templates/) | The **actual data** of the registry / the substance of the secretary's persona |
| Default values / schemas | Stakeholder information / requests / knowledge / person understanding & goals (PII) |
| The bundled divination skill (local computation, an empty capability catalog) | Divination reading results / actual PROFILE data |

- **Not baking personal data into the distributed artifact** is the single biggest distribution-security requirement. Template/data separation (DESIGN §3.3) is also a security mechanism
- ⚠️ The user obtains their own token from BotFather and holds their state in their own Private repo. The plugin provides only templates and deterministic logic

**The three distribution rules** — the three rules this artifact keeps, release after release, as something carved out of its upstream (TelegramSecretary):

1. **Never make another operator's measured registry values the default** — do not place a fixed number even in an example that states its source; ship "the calibration method, not the values" with the four-step procedure (measure → learn how much a single knob pays → combine → measure again) plus an `<N>` placeholder
2. **Never carry a persona name into the distributed scripts** — the upstream's persona and operating-entity names are replaced with neutral wording (internal artifact IDs are kept)
3. **A validation that fires on the read path must never be ported without migration steps in both language editions of the CHANGELOG** — a mechanical bulk replacement is not shipped (redoing a classification is a judgment, not a conversion)

## 9. Rate Limiting ✅ (per-chat sliding window)

- **Window definition** — for each authorized chat, at most **30** updates within the most recent **60** seconds are **passed to the agent** (defaults in `domain/rate_limit.py`). Updates beyond the window are discarded without being emitted, leaving one stderr line with `chat_id` / `update_id` / timestamp (`[security] rate_limited_update_discarded ...`, never the body). The allowlist narrows *who* may talk to us but not *how much*, so this is where the path by which a runaway send from an already-authorized device could fire agent turns without limit is closed
- **The window lives inside the watch process** (in-memory) — it resets when the process restarts and counts independently per chat. Rejected updates are not added to the history, so the window opens on schedule even during a flood
- ⚠️ A discarded update has already been consumed on the Telegram side (the existing invariant that the offset advances past everything fetched is preserved), so it is **not re-delivered**. The defaults sit at a level that human bursts will not trip, but operations that lower the threshold must assume that the excess is lost

## Pre-Distribution Checklist

- [ ] Has no actual token / chat_id / stakeholder information / persona substance leaked into the public tree (grep check)
- [ ] Does `templates/` contain only templates and no actual data
- [ ] Does `.gitignore` include development-only directories (`docs/devlog/`, etc.) and `state/` (actual data)
- [ ] Are the token redact tests green (including the network error path)
- [ ] Is the operation of injection_flags / the output leak scan specified in ROUTINE_PROMPT
- [ ] Do any proper nouns (persona name / operating-entity name / organization name / local absolute paths) remain in the distributed documentation (persona and operating-entity names are checked permanently across every tracked file by `scripts/tests/infrastructure/test_distribution_boundary.py`; the rest by grep check)
- [ ] Are the placeholders (`<AGENT_NAME>` / `<OWNER>` / `<ORGANIZATION>` / `<REPO_ROOT>` / `<BASE_REPO>` / `<PRIVATE_DIR>` / `<INSTALL_DIR>`) used according to convention ([STRUCTURE_en.md](./STRUCTURE_en.md))

## Relationship with the Root `SECURITY.md`

The upper-level `<BASE_REPO>/SECURITY.md` (the agent body's general response guidelines: refusal style, hiding internal information, general prompt injection) is loaded by ROUTINE_PROMPT Step 0. This file covers **the security mechanisms of the skill called ShioriSecretary**. The two are at different layers, and as a distributed artifact this file is self-contained.
