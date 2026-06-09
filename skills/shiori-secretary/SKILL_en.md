---
name: shiori-secretary
description: A "magic bookmark" that grants a secretary to any Claude model (Opus/Fable/Mythos). It keeps Telegram Bot API long-polling running on a cloud routine, providing a conversation channel where a secretary agent (SecretaryRole) responds instantly to messages from authorized chats. It works around the cloud routine constraint of no inbound Webhook via long-polling + a /goal deadline-driven loop.
---

# ShioriSecretary — The bookmark that grants a secretary to a model (a resident Telegram secretary on a cloud routine)

> **Magic bookmark**: Simply slip it into a Claude model — Opus (a work), Fable (a legend), or Mythos (a myth) — and it grants the role of a secretary. A serverless secretary that spins up with nothing but an Anthropic subscription, no dedicated server required. The technical reality is as follows.

## Overview

- **Purpose**: A resident secretary reachable from `<OWNER>` with lower latency (seconds) than Gmail. As opposed to push-type delivery such as scheduled notifications, it provides a 24-7 reachable endpoint as a pull/conversational channel
- **Receive method**: Telegram getUpdates long-polling (no public ingress required, hence aligned with **Claude Code Routines** (Anthropic's cloud execution = cloud routine))
- **Responding entity**: The agent itself in the parent process handles responses (the design principle of not spawning multiple LLM inference subprocesses). This skill only does fetch / authorization / normalization / send
- **state persistence**: `offset.json` + `lease.json` are saved in `state_dir`, with heartbeat + TTL lease for concurrency prevention and crash self-healing. **The registry (individuals/tasks/knowledge/abilities) lives in `registry_dir`, separated from the volatile state, and when `registry_sync` is enabled it is git-persisted to a fixed branch** (event-driven commit&push + fetch at startup, no force)
- **Word-deed consistency guarantee (WAL, when `registry_sync` is enabled)**: registry push is best-effort, so an inconsistency where "the reply said it was registered but it isn't" can occur. The **WAL (Write-Ahead Log)** prevents this — before sending a registration-type reply, the intent is push-ahead to the WAL log (`registry_dir/wal/WAL.jsonl`, on the same fixed branch) (must-succeed = if push fails, the message is not sent either), and at startup any unreflected entries are redone into the registry (key-idempotent). The log also doubles as short-term memory of the conversation context for the last 24h
- **The heart with zero idle slot**: `/goal` runs foreground `watch --exit-on-message` each turn until the deadline. On message receipt it immediately exits → replies → restarts (instant response, latency ≤ the long-poll timeout); when there are no messages it blocks on the long-poll (minimal wait tokens + keeps the session warm via the foreground call). Details in [`ROUTINE_PROMPT.md`](../../docs_en/ROUTINE_PROMPT_en.md)

## Daily Workflow (at cloud routine startup)

```
1. In Step 0, read `config.json` to learn `agent_name`/`private_dir` → `source bootstrap.sh` to install dependencies + validate-config (including validation of session_duration_sec in config.json) + share `SHIORI_SESSION_ID` via env
2. Verify egress connectivity (hit curl api.telegram.org/.../getMe with an invalid token to confirm 401/404 is returned)
3. lease acquire (if another session holds it, exit 4 immediately = self-healing)
4. Drive monitoring with `/goal` until the deadline (`$SHIORI_SESSION_DEADLINE_EPOCH`). Each turn = foreground
   `watch --exit-on-message --max-duration <remaining window> --timeout 30` (only this call uses bash
   `timeout: $SHIORI_POLL_BASH_TIMEOUT_MS`, others default to 2 minutes)
5. After watch returns, read the JSON Lines from stdout, the agent drafts a response as SecretaryRole → send-reply
   (immediate-response restart on message receipt, restart at window expiry if none)
6. lease renew is run internally by watch each cycle (no manual renew needed)
7. At session end, lease release (so the next cron can pick it up)
```

Processing branches per media item (full flow in [`ROUTINE_PROMPT.md`](../../docs_en/ROUTINE_PROMPT_en.md)):

- **`rendered_text` non-null (`render_status="ok"`)** → use that text directly. docx/pptx/xlsx are markdown, voice/audio/video are the audio transcription transcript (distinguish via `kind`/`mime_type`)
- **`derived_image_paths` non-empty (PDF)** → PDF is always rendered to images (`rendered_text=""`). Grasp the gist of the first up-to-5 pages with Vision, then decide on ① full-text (`render-pdf --text`) / ② close-read individual pages / ③ enough (details in "Handling PDFs" below)
- **`local_path` non-null + `render_status="passthrough"`** → open with the `Read` tool for Vision/text interpretation (image/text types)
- **`render_status="failed"`** → reply briefly that it "couldn't be read", including `file_name`. Note: corrupt / silent / undecodable audio (PyAV) falls through to `ok`+empty rather than failed → reply ambiguously (by medium) with "possibly silent, or a file that can't be read as audio"
- **`render_status="skipped"` + `skip_reason="media_size_exceeded"`** → size-exceeded reply
- **`render_status="skipped"` + `skip_reason=null`** → unsupported mime, or audio with no transcriber injected / Medium mode. Reply based on `mime_type`
- **Send a generated artifact back** → after generating a chart/report etc., `send-reply --file <path>` (multiple allowed, auto-routed images→sendPhoto / others→sendDocument). `--reply-to <message_id>` for a reply thread, typing indicator before sending

## Handling PDFs (spec SSoT)

PDFs are **always rendered to images for all pages** (no detection of whether a text layer exists). This structurally eliminates misjudgment of stamps / faint text layers (e.g., the same document-number stamp on every page causing it to fall into the text path and become unreadable). It is a separation of **rendering = deterministic (code) / what to read = judgment (agent)** (the design principle of moving LLM inference outside code).

**On receipt (automatic)**: When `poll`/`watch` receives a PDF, `PdfRenderer.render()` renders the first `pdf_image_max_pages` (default 20) pages to images and emits `rendered_text=""` / `page_count` (the actual total) / `derived_image_paths` (array of png paths). It does **not** extract text (separated to on-demand).

**Agent's staged processing**:

1. **Grasp the gist** — Vision the **first up-to-5** of `derived_image_paths` with `Read` to grasp the document's nature and `page_count` (the total volume) (don't view all 20 = token savings)
2. **Decide ①②③**:
   - **① Full text is needed** → `render-pdf --path <local_path> --text` (pdfplumber extracts the text layer of all pages with `--- page N ---` markers. Scanned PDFs have zero text layer and honestly return an empty string)
   - **② Close reading of individual pages is needed** → `Read` that page's image. **For N ≤ 20, just open the already-emitted `derived_image_paths[N-1]` (zero additional cost)**; **for N > 20 (over cap), generate it for the first time with `render-pdf --path <local_path> --pages N-M`** then Read
   - **③ 5 pages are enough** → respond as is
3. **Confirm if there's a lot / unclear** — if it's unclear where to look or there are many pages, confirm with `send-reply` ("It appears to be a ◯◯ of N pages total. Where should I look?") before processing only the necessary parts

> **retention caveat**: The N>20 delayed generation in ② requires the original PDF to still be within `media_retention_hours` (default 24h). It is reliable within the same session / same day. "Page 25 of that PDF" later may be gone, in which case prompt for a resend.

## Subcommands

| Command | Function | Exit code |
|---|---|---|
| `validate-config` | Validate env + config.json (including the range of session_duration_sec) | 0=OK, 2=config missing |
| `show-config` | Display current config read-only (secrets masked) | 0 (0 even if unset) |
| `init-config [--session-duration-sec] [--agent-name] [--private-dir] [--force]` | Generate config.json (range validation, overwrite existing with `--force`). Interactive collection is via `/shiori-secretary` | 0, 2=out of range/existing |
| `lease acquire\|renew\|release [--owner] [--ttl SEC]` | Lease lock operations (`--ttl` default 300) | 0=success, 4=conflict, 2=config missing |
| `poll [--timeout SEC]` | One getUpdates cycle (`--timeout` long-poll seconds, default 30), emits authorized & normalized updates as JSON Lines to stdout | 0=OK, 1=fetch failed, 3=auth failed |
| `watch [--owner] [--timeout SEC] [--max-iterations N] [--max-duration SEC] [--exit-on-message] [--cleanup-interval N]` | Long-running long-poll loop. One actual message = one line emitted. Auto-renews lease each cycle. `--timeout`=getUpdates long-poll seconds (default 30), `--max-duration SEC`=exit 0 at window expiry (0=infinite), `--exit-on-message`=exit 0 on the cycle that emitted a message (immediate-response restart) | long-running residency / window folding |
| `send-reply --chat-id --update-id --text-file [--owner] [--file ...] [--reply-to]` | Send the agent-drafted reply → offset advance + lease renew. Double owner verification at CLI layer + UseCase layer. `--file` (multiple allowed) attaches images→sendPhoto / others→sendDocument, `--reply-to` for threading | 0=OK, 1=send failed, 2=invalid attachment, 3=auth, 4=lease |
| `proactive-send --chat-id --text-file [--owner] [--file ...] [--reply-to]` | Proactive send by the secretary (outbound push independent of inbound) → send + lease renew (**offset-non-interfering** = does not touch the inbound-only read ledger). When `registry_sync` is enabled, it encapsulates the outbound WAL lifecycle (append→push→send→**settle**→push) and marks successfully-sent entries done (happy-path settle = no resend next time, no separate wal-append/push needed). **No `--update-id`** is the difference from send-reply. Double owner verification, `--file`, `--reply-to` are shared. The capability boundary is SecretaryRole, the resend policy is DESIGN §3.9 | 0=OK, 1=send failed, 2=invalid attachment, 3=auth, 4=lease |
| `test --chat-id` | One ping to the owner chat | 0=OK, 1=send failed, 3=auth |
| `cleanup-media` | Delete stored media exceeding `media_retention_hours` under `state_dir/media/` (manual / cron). `watch` auto-fires it via `--cleanup-interval` (default 120 cycles ≒ 1h) | 0=OK, 2=config missing |
| `render-pdf --path <pdf> (--text \| --pages N-M)` | On-demand extraction of an already-received PDF. `--text`=the text layer of all pages (pdfplumber, `--- page N ---` markers), `--pages N-M`=render specified pages to images (1-indexed inclusive, for the 21st page onward over the cap). The result is one JSON line on stdout. `--text`/`--pages` are mutually exclusive and required | 0=OK, 2=file missing/invalid argument |
| `individuals\|tasks\|knowledge\|abilities {list\|get\|add\|remove}` | CRUD on the registry (INDIVIDUALS/TASKS/KNOWLEDGE/ABILITIES). `get`/`remove` use `--key` (uuid/id), `add` uses `--json`/`--json-file`. Validated by value objects. The SSoT is Private JSON, the operating entity is SecretaryRole, the entry point is `/shiori-secretary`. When `registry_sync` is enabled, commit&push after add/remove (event-driven) | 0=OK, 2=invalid input |
| `registry-sync` | At startup, fetch the registry from the fixed branch (only when `registry_sync` is enabled, no-op when disabled). To start up with the latest registry, ROUTINE_PROMPT calls it once at startup | 0=OK, 1=fetch failed |
| `wal-append --kind <individuals\|tasks\|knowledge\|abilities> (--json \| --json-file)` | Append the intent to the WAL as pending (**before a registration-type reply**, the push-ahead write for the word-deed consistency guarantee). Only when `registry_sync` is enabled, no-op when disabled | 0=OK, 2=invalid |
| `wal-push [--message]` | commit & push the WAL log (**must-succeed** = failure is exit 1 = **aborts send-reply at the pre-send gate**). No-op when `registry_sync` is disabled | 0=OK, 1=push failed |
| `wal-redo` | At startup, redo the WAL's pending entries (when `registry_sync` is enabled). registry kinds upsert (key-idempotent, **inbound replies are not resent**), outbound kinds resend once only the interrupted portions remaining after happy-path settle → done immediately. ROUTINE_PROMPT calls it once right after registry-sync | 0=OK |

`--owner` is optional (auto-synced via env by `source bootstrap.sh`). The priority is `--owner > env > uuid auto-generation`.

## cloud routine lifecycle (schedule / unschedule)

The operation by which the agent that invoked `/shiori-secretary` registers, updates, or stops this resident routine itself on the cloud routine. **Not the Python CLI but a `RemoteTrigger` tool procedure** (a separate lineage from the Subcommands table above = the deterministic CLI). The SSoT for the procedure is the "cloud routine lifecycle management" section of [`ROUTINE_PROMPT.md`](../../docs_en/ROUTINE_PROMPT_en.md), and the canon for the body shape is the built-in `schedule` skill.

| Operation | Function | Reality |
|---|---|---|
| `schedule` | Register / enable / config overwrite (upsert) | `RemoteTrigger create` (if absent) or `get→modify→update` (if existing) + `init-config` (config.json) |
| `unschedule` | Stop (`enabled:false`, never starts again) | `RemoteTrigger update {enabled:false}`. Physical deletion (removing it from the list) is manual via the claude.ai UI |

> Secrets (bot token / authorized chats) are injected into the cloud routine's Environment (not baked into the prompt body / commit). Operational settings such as `session_duration_sec` are via `init-config` (deterministic). For avoiding the RemoteTrigger schema pitfalls (events v1 nesting, session_context full replacement), see ROUTINE_PROMPT / the `schedule` skill.

## Failure Modes

| Exit code | Meaning | Response |
|---|---|---|
| 0 | Success | — |
| 1 | fetch / send failed (after 5xx retry, or 4xx) | Transient, retry next cycle |
| 2 | config missing / malformed | Check env vars |
| 3 | 401 Unauthorized | Check / regenerate bot token |
| 4 | lease conflict (another session holds it, or no lease) | Normal self-healing behavior |

## env vars

| Var | Required | Overview |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | ✅ | The bot token obtained from BotFather |
| `SHIORI_AUTHORIZED_CHATS` | ✅ | JSON array of int (chat_id allowlist) |
| `SHIORI_STATE_DIR` | optional | Save location for offset/lease/media, default `./state` (media is in `state_dir/media/`) |
| `SHIORI_SESSION_ID` | optional | Lease owner ID, auto-generated uuid if omitted. Auto-exported by `source bootstrap.sh`, so all `lease`/`watch`/`send-reply` commands share the same owner |
| `SHIORI_MEDIA_MAX_SIZE_BYTES` | optional | Size limit for media download (default 20MB). Excess is emitted with `skip_reason="media_size_exceeded"`, download skipped |
| `SHIORI_MEDIA_RETENTION_HOURS` | optional | Retention period for stored media (default 24h). `cleanup_media_dir` deletes files exceeding it |
| `SHIORI_MEDIA_ENABLE_DOWNLOAD` | optional | Toggle between Heavy (true=default) / Medium (false) mode |
| `SHIORI_BUNDLE_VOICE` | optional | Whether to install voice/video STT (moonshine+av) in bootstrap (default true). `false` to exclude = audio falls back to `skipped` (avoids the moonshine Community License, lighter weight, for large-scale deployments) |
| `SHIORI_OUTBOUND_MAX_SIZE_BYTES` | optional | Limit for **outbound** attachments (default 50MB, the Telegram bot API limit). Excess is rejected before sending with `AttachmentTooLarge` (exit 2) |
| `SHIORI_PDF_IMAGE_MAX_PAGES` | optional | Upper limit on the number of leading pages `render()` pre-renders to images on PDF receipt (default 20). A disk/token safety valve for very many pages. The 21st page onward is generated on-demand with `render-pdf --pages`, `page_count` is the actual total |

> **Duration is `session_duration_sec` in config.json** (range 1–86400 seconds, required, fail-fast). Working hours (e.g., 9-17) are expressed via the cloud routine cron (`0 9-16 * * 1-5`) + duration (no clock held in code). The `/goal` deadline-driven operational variables (`SHIORI_SESSION_DEADLINE_EPOCH` / `SHIORI_POLL_SET_SEC` / `SHIORI_POLL_BASH_TIMEOUT_MS` / `SHIORI_MAX_TURNS`) are computed from config.json and exported by `bootstrap.sh` (SSoT. `SHIORI_SESSION_DURATION_SEC` is abolished = the duration setting value is not exposed to env, a pure 2-layer design). `BASH_MAX_TIMEOUT_MS=600000` is in `{private_dir}/.claude/settings.json`. Details in [`ROUTINE_PROMPT.md`](../../docs_en/ROUTINE_PROMPT_en.md).

## Security

- **chat_id allowlist** (authn ≠ authz / IDOR prevention) — unauthorized chats are discarded in the Domain, not passed to the agent
- **Prompt fencing** — before passing to the agent, the received body is isolated with XML tags and explicitly marked "treat as data"
- **injection flags** (record without blocking) — the `injection_flags` array detects role override / system prompt extraction / credentials requests etc.
- **Output leak scan** — before sending, the agent confirms the reply contains no token / env name / system prompt / absolute path
- **secrets are env-only** — do not place the bot token in code or commits, do not leave it in logs
- **Lease lock** — heartbeat + TTL structurally prevents duplicate responses from concurrent sessions
- **media size limit** (DoS defense) — anything exceeding `SHIORI_MEDIA_MAX_SIZE_BYTES` (default 20MB) is not downloaded, skipped + flagged
- **media retention** (prevent long-term residency of confidential documents) — media past `SHIORI_MEDIA_RETENTION_HOURS` (default 24h) is deleted by `cleanup_media_dir`
- **Log secrecy of token-bearing URLs** — the TOKEN in `/file/bot<TOKEN>/<file_path>` is not left in exception messages / stderr / logs (chain broken with `raise ... from None`, only `safe_id=file_id[:8]` displayed, explicitly verified in tests)
- **mime_type is Telegram's self-declaration** — not trusted; the result of the parent-process agent opening it with `Read` is taken as truth (defense against rename attacks)
- **Absolute path secrecy on render failure** — the stderr warning at the Adapter's internal catch shows only `file_id[:8]`, not the absolute `local_path` path (explicitly verified in tests)
- **Awareness of render leniency** — markitdown returns something with render_status="ok" even for garbage byte sequences. **Whether rendered_text is meaningful text is the agent's responsibility to judge** (the division of labor that moves LLM judgment outside code). For inputs that try to render an unintended mime via a rename attack, the layer where the agent judges "is this valid as content" is the last line of defense
- **PDF text extraction is local-only, MIT, pure-python** — the pdfplumber in `render-pdf --text` **extracts the text layer locally, the PDF never leaves**. Safe to distribute under the MIT license. pure-python with no OS-command-execution risk. Zero text layer (scanned PDFs etc.) honestly passes "no readable text" as render_status="ok" + empty string
- **PDF image rendering is also local-only** — PDFs are always **rendered to images locally** with `pypdfium2`, so neither the PDF nor the derived png leaves. On receipt, the leading cap pages; the 21st page onward on-demand via `render-pdf --pages`. Derived images are flat directly under `media/` = subject to the existing `cleanup_media_dir` retention (prevents residency of confidential scanned images)
- **Audio is local-only** — Moonshine is **local inference, audio never leaves** (safe for confidential voice memos). A design advantage of not adopting external-send STT such as the Whisper API
- **Output leak scan of the transcript** — confidential content within audio (e.g., a password read aloud) may ride on the emit via the transcript, so `rendered_text` (transcript) is also included in the pre-send-reply leak scan
- **No audio intermediate files** — PyAV decodes in-memory (numpy) to 16kHz mono float, **never writing an ffmpeg intermediate wav to disk**. No intermediate artifact of confidential voice remains on disk
- **Output leak scan of outbound attachments** — before sending, the agent confirms that agent-generated artifacts (md/docx/image/PDF) contain no token / env name / system prompt / confidential content. The code does not inspect binary contents = the agent's judgment responsibility
- **Outbound size limit** (accident prevention) — anything exceeding `SHIORI_OUTBOUND_MAX_SIZE_BYTES` (default 50MB) is rejected before sending with `AttachmentTooLarge`
- **Log secrecy of token-bearing URLs on send** — sendPhoto/sendDocument failure exceptions carry only the method / chat_id / file name, not the URL / token (same shape as the receive-side media_downloader, verified in tests)
