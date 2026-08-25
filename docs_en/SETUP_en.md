# ShioriSecretary Setup Guide (cloud routine operation)

**The setup manual for slipping ShioriSecretary — the "bookmark that grants a secretary" — into your Claude model and your environment.** It keeps a secretary that responds 24-7 over Telegram resident on **Claude Code Routines** (Anthropic's cloud-execution scheduled-agent platform; Remote execution = cloud routine) — a route designed to **get you running without getting lost**, almost entirely within the claude.ai GUI and the Telegram app.

> The SSoT for the specification is [SKILL_en.md](../skills/shiori-secretary/SKILL_en.md); the detailed startup procedure is in [ROUTINE_PROMPT_en.md](./ROUTINE_PROMPT_en.md); the placement conventions are in [STRUCTURE_en.md](./STRUCTURE_en.md); local verification is in [README_en.md](../README_en.md). This document is the "route to begin operation" that sits on top of those.

## Overview

```
① Create bot → ② Get chat_id → ③ Place plugin → ④ Secretary persona → ⑤ config
   → ⑥ Register cloud routine → ⑦ Configure Environment (GUI) → ⑧ Test launch
```

The secretary's responses are drafted by the parent agent itself; this skill only handles fetch / authorization / normalization / send. **Secrets (bot token, chat_id) are injected into the cloud routine's Environment** and are never baked into the code or the repository.

## What you need

- **A Telegram account**
- **Claude Code (an environment where cloud routine is available)**
- **A repository (at minimum 1, Private by default)** — cloud routine clones it. **The straightforward approach is to consolidate into a single private repository**, but you can also split it into two:
  - **Base configuration** (`<BASE_REPO>`) — this skill `ShioriSecretary/` (placed inside `<BASE_REPO>`; the location is arbitrary — bootstrap resolves its own position absolutely) plus the parent persona `Identities/<agent_name>Identity.md` and `SECURITY.md` (the locations ROUTINE_PROMPT reads relative to cwd). The skill may be Public. **The parent persona supports both co-locating in a public repo and, in the single-repo consolidation, co-locating on the private side** — `<BASE_REPO>` is a logical position, and whether its physical instance is public or private is up to your operation.
  - **Private data** (`<PRIVATE_DIR>`) — the secretary persona `SecretaryRole.md` and operational state. Private is assumed.
  > **Consolidating into a single private repository** is the baseline (`<BASE_REPO>` = `<PRIVATE_DIR>`, one source, cwd = repo root). **Only when you want to publish part of it**, such as a general-purpose skill, do you split into two (multiple sources, each repo-name directory side by side, cwd = parent).

## Procedure

### ① Create a Telegram Bot

1. Talk to **@BotFather** on Telegram
2. `/newbot` → decide the bot's display name and username
3. Note the **token** that comes back (in the form `123456789:ABC-DEF...`) ← this is `TELEGRAM_BOT_TOKEN`

### ② Find out your own chat_id

1. Talk to **@userinfobot** on Telegram
2. Note the numeric **Id** that comes back (e.g. `123456789`) ← this is `SHIORI_AUTHORIZED_CHATS`

> **The token and the chat_id are different things.** The token is the bot's key (issued by BotFather); the chat_id is your personal destination (revealed by @userinfobot). In a personal DM, `chat_id = user_id`.

### ③ Place the plugin

Install from the marketplace, or place it in the base-configuration repo's `ShioriSecretary/`. **cloud routine performs a fresh clone of the base-configuration repo**, so `ShioriSecretary/` (the full code) must be committed to the base-configuration repo.

### ④ Prepare the secretary persona (SecretaryRole.md)

Copy the template [`templates/SecretaryRole.template.md`](../templates/SecretaryRole.template.md) and define the secretary's proper name, response principles, off-limits topics, and so on as the **private repo's `Identities/SecretaryRole.md`** (the persona is a personal asset, so it lives in the private repo and is not baked into the distributed artifact).

### ⑤ Generate config.json

```
/shiori-secretary init-config --session-duration-sec <seconds> --agent-name <persona name> --private-dir <Private path>
```

- `--session-duration-sec`: the length of one session (1–86400 seconds)
- `--agent-name`: the name used to resolve the base-configuration repo's `Identities/<agent_name>Identity.md`
- `--private-dir`: the path to the private repo relative to cwd (the 2-repo parent) (e.g. `<PRIVATE_REPO>/ShioriSecretary`)

> Place config.json at **the base-configuration repo's `ShioriSecretary/config.json` and commit it so the cloud routine can read it on a fresh clone** (it contains no secrets, just operational settings, so committing is fine). In the distributed repo it is a `.gitignore` target, so track it explicitly on the operational repo side.

**If you want to persist the management tables (related parties / requests / response knowledge / subject vocabulary / ability catalog / person understanding / goals / reverse-planned steps) to the repository** (optional, recommended) — because the cloud routine launches with a fresh clone every time and the execution environment is volatile, persisting the management tables the secretary has accumulated to the next launch requires **git persistence to a fixed branch of the repository**. Since `init-config` does not generate these, add the following to config.json (the template is `templates/config.template.json`):

```json
{
  "registry_sync": true,
  "registry_dir": "shiori-registry-wt",
  "registry_branch": "claude/shiori-registry"
}
```

- `registry_sync`: set to `true` to git-persist the management tables to a fixed branch (commit & push on every update + fetch at startup). For local verification, use `false` (does not touch git)
- `registry_dir`: where the persistent management tables (individuals/tasks/knowledge/subjects/abilities/profile/goals/steps) live. Keep it **separate from `state_dir`, which holds volatile state (offset/lease/media)**, and point it at **an independent second git working tree (worktree) of the private repo** (bootstrap does idempotent provisioning via `git worktree add`; recommended value `shiori-registry-wt`). **Making it a subdirectory inside the dev tree is not allowed**, because the startup `checkout -B` of fetch would destroy the parent repo (→ DESIGN §3.6). If unset, it falls back to `state_dir`
- `registry_branch`: the fixed branch to push to (default `claude/shiori-registry`). Operated together with `registry_remote` (default `origin`). By separating it from volatile state, you physically separate "things that may disappear" from "things whose accumulation is the essence"

### ⑥ Register with cloud routine

```
/shiori-secretary schedule
```

- Creates the routine itself (cron + prompt body + sources)
- **sources are the base configuration + the private one** (two if split, one if consolidated into a single repo)
- The `<BASE_REPO>` / `<PRIVATE_DIR>` in the prompt body are automatically replaced with the actual repo names by schedule (no manual replacement needed)
- **If you enabled `registry_sync`**, the management tables are pushed directly from `registry_dir` (the independent worktree) by `registry_cli` to the fixed branch `registry_branch` (default `claude/shiori-registry`) (`bootstrap.sh` provisions the worktree; authentication uses the cloud routine's git credential. DESIGN §3.6). Naming the `registry_branch` in the routine's `outcomes` declaration is not required (after the 2026-06-05 worktree migration)

> **`environment_id` can be swapped in later.** Creating the routine first, then setting up the environment in ⑦ and binding it afterward, is generally the less error-prone flow and is recommended.

### ⑦ Configure the Environment (claude.ai GUI)

In claude.ai's Code → Environments:

- **Environment variables**:
  - `TELEGRAM_BOT_TOKEN` = the token from ①
  - `SHIORI_AUTHORIZED_CHATS` = `[chat_id from ②]` (a JSON integer array. e.g. `[123456789]`)
- **network policy (egress allowance)**: **allow `api.telegram.org`** ← without this it stops at startup with `host_not_allowed`
- Bind the created Environment to the routine (via the GUI, or by re-running `/shiori-secretary schedule` and specifying `environment_id`)

### ⑧ Test launch

- **Manual launch**: run the routine immediately with `run` (you can test without waiting for cron)
- **Send one message to the bot on Telegram** → if a reply comes back within a few seconds, **connectivity is complete** (egress, immediate response, and path resolution are all OK)
- If nothing comes back, check which Step stopped in claude.ai's execution history (see Troubleshooting below)

## Designing the working hours (cron + duration)

Don't give the clock to the code; express it with **cron (launch timing) + `session_duration_sec` (the length of each run)**:

| Operation | cron (UTC) | session_duration_sec |
|---|---|---|
| 24-hour residency | Multiple times at the measured-upper-limit interval (e.g. every 4h = `0 15,19,23,3,7,11 * * *` = JST 0/4/8/12/16/20) | About the same as the measured upper limit (e.g. `14400` = 4h) |
| Weekdays 9–17 | `0 0-7 * * 1-5` (JST 9–16 = UTC 0–7) | `3600`–`7200` |

> **cron is in UTC.** Subtract 9 hours from JST (JST 9:00 = UTC 0:00). **The execution upper limit of a single session is platform-dependent**; the Claude Code Routines container terminates at roughly about 4 hours by measurement (subject to variation). If you want residency, set `session_duration_sec` to about the same as the measured upper limit and have cron cycle at that interval — even if the window is longer than the limit it terminates partway, and the next cron continues via the idempotency of lease / offset (gap messages are not dropped thanks to Telegram's ~24h retention). Conversely, "cron once a day + a huge window (e.g. `86340`)" is unsuited for residency, because after being cut off at the limit it goes silent until the next launch.

## Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| `host_not_allowed` (Step 3) | egress not opened | Add `api.telegram.org` to the network policy |
| exit 2 (config invalid) | config.json missing or env missing | Check with `show-config` → regenerate with `init-config`, verify the Environment's token/chats |
| exit 3 (auth failed) | bot token invalid | Verify or regenerate the token with BotFather |
| exit 4 (lease conflict) | another session is holding it | Normal self-healing behavior (prevents duplicate launches). Leave it as is |
| Path resolution fails at Step 0 | inconsistency in the 2-repo layout | Verify that sources contains both the base-configuration repo and the private repo, and that config's `private_dir` is relative to the cwd parent |
| No reply comes back | egress or authorization | Check whether chat_id is in `AUTHORIZED_CHATS` and whether `api.telegram.org` egress is open |
| Management tables revert to empty every time | `registry_sync` disabled, or worktree not provisioned, or insufficient git auth | Check config's `registry_sync:true` / `registry_dir` (independent worktree) → verify the bootstrap `registry worktree provisioned/refreshed` log and the push authentication (git credential) to the fixed branch (DESIGN §3.6) |
| `registry fetch failed` (at startup) | fixed branch not created, or insufficient git auth | On the first run it continues even if the target branch is empty (launches with the previous local state). Verify that git auth (PAT, etc.) is present in the Environment |
| The registry is populated, yet the secretary forgets registered tasks and policies every time | The registry tables are being `list`ed side by side at startup (a bloated table exceeds the output limit and exits 0 without landing in context = silent failure) | Do startup orientation with a single `python scripts/main.py orientation` (bootstrap prints the pointer just before `ready`). When a single table's `list` exceeds 200KB a warning goes to stderr — take it as the cue to switch to `orientation` / `get --key` (→ DESIGN §3.12) |
| `add` / `import` / `wal-append` fails with exit 2 (stderr shows `unknown field(s): ...` or an enumeration of subject candidates) | The fail-closed on the write paths — an unknown top-level key, an out-of-vocabulary subject, or an out-of-set category is being rejected (`add` / `import` since v1.9.0, and `wal-append` joined the same gate in v1.11.0) | stderr states the cause (the key name, the candidates); fix the record accordingly and rerun. This exists so a typo'd key is not silently discarded, and the read paths (`list` / `get` / `orientation`) remain readable as before. `wal-append` stops **before anything is written to the log**, so a rejected intent leaves nothing behind (→ DESIGN §3.7/§3.8/§3.12) |
| `wal redo: dead <table> key=<key>: <reason>` appears on stderr at every startup | An intent that failed the v1.11.0 redo validation is quarantined as `dead` = the record of something promised as registered but never applied (it does not expire) | Read the reason and take one of the two exits: (1) re-`add` the same key with a correct payload (the next redo's `settle` marks it done = self-healing), or (2) if you decide not to keep the promise, close it out with `wal-drop --kind <table> --key <key>`. Left alone it keeps printing every startup (→ DESIGN §3.7) |
| Management tables empty = running with no memory (stderr shows `WARNING: ... EMPTY tables`) | `registry_dir` is not an independent worktree (a subdirectory inside the dev tree = the old layout) | Set `registry_dir` to the independent-worktree value (`shiori-registry-wt`). Verify the bootstrap `registry worktree provisioned/refreshed` log (→ DESIGN §3.6) |

## References

- Specification SSoT: [SKILL_en.md](../skills/shiori-secretary/SKILL_en.md)
- Startup procedure: [ROUTINE_PROMPT_en.md](./ROUTINE_PROMPT_en.md)
- Structure map: [STRUCTURE_en.md](./STRUCTURE_en.md)
- Security canon: [SECURITY_en.md](./SECURITY_en.md)
- Local verification: [README_en.md](../README_en.md)
