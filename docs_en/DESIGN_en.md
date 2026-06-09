# ShioriSecretary Design Canon (DESIGN)

Consolidates the **why** of the design. Division of roles — **DESIGN** = why this design / **STRUCTURE** = where things live.

> **ShioriSecretary is "a magic bookmark you slip into a Claude model (Opus/Fable/Mythos)"**——a thin layer that grants the secretary role to any model. The design below (separation of deterministic core and agent judgment, template/data separation, a cloud routine residency that runs on a subscription alone with no dedicated server) is the skeleton that supports that "bookmark."

## 1. Design Principles

- **Secretary = input-understanding first**: the primary value is "receiving + understanding the content" of `<OWNER>`'s business inputs (voice / photos / documents)
- **Minimal bidirectionality**: output (sending) completes the bidirectional loop via file sending. Conversational UX decoration is optional
- **LLM inference lives outside the code**: response generation and judgment are the parent-process agent's job; the code is purely deterministic fetch / render / send / registry I/O (it does not spawn LLM inference in subprocesses)
- **Template/data separation**: for distributability, physically separate code and templates (public) from real data and persona (Private)
- **Pure 2-layer configuration**: env holds only secrets (bot token / authorized chats) + state_dir, while non-secret operational settings (`session_duration_sec` / `agent_name` / `private_dir`) have `config.json` as their single canon. `config.json` is hard-coded directly under `<INSTALL_DIR>` (env does not point to its location — avoiding the chicken-and-egg problem), and its actual contents are not distributed thanks to `.gitignore` exclusion. A missing `session_duration_sec` is fail-fast (there is no default value)
- **Separation of deterministic core and agent judgment**: based on the three-worlds model (the deterministic / subordinate / importance worlds), schemas, I/O, and archiving are code; judgment is the agent
- **Avoiding additive bias**: even features the official offering has are left out if unnecessary for the design goal (YAGNI). Fill them in once they are actually needed

## 2. Architecture (Clean Architecture, 4 layers)

```
Infrastructure → Interface(Adapter) → UseCase → Domain
              Dependency direction: outer to inner only (Domain does not import outer layers)
```

| Layer | Responsibility | Examples |
|---|---|---|
| **Domain** | Pure logic / value objects | `TelegramUpdate` / `OutboundMessage` / `Individual` / `Identity` / `Task` / `Knowledge` / `Ability` / `MediaAttachment` / normalization / injection flags |
| **UseCase** | Orchestration + Port definitions | `FetchAuthorizedUpdates` / `SendReply` / registry CRUD UseCases / Ports (`UpdateSource` / `MessageSink` / `OffsetStore` / each `*Store`) |
| **Interface (Adapter)** | Gateways / stores / CLI | `TelegramApiGateway` / `JsonStateStore` / `JsonRegistryStore` (registry) / `StdoutEventEmitter` / `main.py` |
| **Infrastructure** | External / framework / wiring | `bootstrap.sh` / `config` / `composition` (Composition Root) / `exit_codes` / `archive_rotate.py` |

**Composition Root**: dependency assembly is consolidated in `infrastructure/composition.py` (fail-fast `load_config`, and a media stack shared by poll/watch built via `build_media_stack`). Each CLI handler receives an already-assembled set and focuses on execution, never `new`-ing adapters itself. Exit codes have `infrastructure/exit_codes.py` as their SSoT (the values are an external contract — they match SKILL/ROUTINE_PROMPT/SECURITY).

### Mapping to the three-worlds model

| World | What is fed to the LLM | Applies to |
|---|---|---|
| **Deterministic world** | Nothing fed (managed in code) | scripts in general — pure functions for fetch / authorization / normalization / sending / render / registry I/O / archive / partitioning. Config validation and loading (config.json / env) are also deterministic |
| **Subordinate world** | Goal and premises only | ROUTINE_PROMPT (delegates the procedure) |
| **Importance world** | High-quality long-form text | the agent's persona (the core Identity) + SecretaryRole. Drafting responses / CRUD judgment / escalation judgment / the firing decision for archive/partitioning (when and at what granularity) |

**Design line**: "how to store (schema I/O), pure functions that compute partitioning" is the deterministic world. "who to make active / what to keep in KNOWLEDGE / **when and at what granularity to archive/partition** / how to respond" is the importance world (the agent). **The information's owner (the agent) decides how the information is held**——archiving is an LLM task and is not executed deterministically and automatically. The code provides pure functions (`archive_rotate.py`) and I/O as tools, while the firing and granularity decisions rest with the agent. This boundary is the backbone of the registry design.

**Three-worlds mapping of keep-alive**: "the watch window expiring / message-driven exit (`WatchWindow` / `--max-duration` / `--exit-on-message`)" and "deadline computation" are the deterministic world (code + bash arithmetic, testable). The operation of "running watch each turn until the deadline via `/goal` and drafting replies" is the subordinate world (delegated to ROUTINE_PROMPT). Placing the stopping axis on time (deadline) and decoupling the polling count from LLM judgment follows this design line of pushing determinism into code.

## 3. Data Architecture (registry + Identities)

### 3.1 Two data systems

- **Registry (4 tables)**: three fact-data tables — `INDIVIDUALS` (related parties) / `TASKS` (request progress) / `KNOWLEDGE` (accumulated response knowledge, case-DB-like) — plus `ABILITIES` (a catalog of capabilities the secretary can exercise, §3.8)
- **Identities (persona definitions)**: `SecretaryRole` — **without this the agent cannot behave as a persona**. Same shape as the role-definition file of a cloud routine agent

### 3.2 Why SSoT = Private JSON

- **Private**: related-party info, requests, and persona are all personal assets. If baked into the distributable (public code) they would fall into others' hands. Physical separation is inevitable
- **JSON**: the flexibility for the agent to later modify the schema as needed. A format the judging entity (the agent) can touch is more appropriate than a rigid schema language
- **Single canon**: when adopting multiple channels, the cache (Redis, etc.) is a mirror of the JSON (one-way JSON→Redis). Even as channels are added, there is exactly one canon — preventing the breakdown of dual management
- **config.json follows the same principle**: non-secret operational settings (`session_duration_sec` etc.) have `config.json` as their single canon. bootstrap computes the deadline etc. from config.json and expands them one-way into env (env is derived — not dual-managed). Its location is hard-coded directly under `<INSTALL_DIR>` (env does not point to it — avoiding the chicken-and-egg problem)

### 3.3 Why template/data separation (the core of distributability)

Separate `templates/` (public, scaffolds) from the actual entities (Private). If this separation is enforced from day one of personal use, distributing a plugin is just "add one entry to the marketplace + strip out Private." **Bake distributability into the structure of personal use from the very start.** Identities (persona) are the same — the scaffold is public, while `<OWNER>`'s actual SecretaryRole is Private.

### 3.4 Why CRUD is agent-driven + wrapped by `/shiori-secretary`

- **Operating entity = the agent**: the agent / SecretaryRole, in the conversational context, decides "make this person active" / "keep this judgment in KNOWLEDGE" and performs CRUD (the importance world)
- **Deterministic I/O = CLI subcommand**: the actual write is the deterministic world (testable). The agent calls the subcommand
- **Also exposed for the user**: the operation interface is published as a skill / slash command (a human can operate it directly too)
- **Everything wrapped by `/shiori-secretary`**: the master skill is the entry point to all operations as a management panel. Operable without memorizing command names

### 3.5 Why anti-bloat differs per registry table (the firing decision is the importance world)

The "**when and at what granularity to partition/archive**" of anti-bloat is the importance world (agent judgment)——the information's owner decides how it is held. The following are the default best practices (policy); the agent may vary the granularity and thresholds according to context. The code provides the pure functions of `archive_rotate.py` (`partition_for_archive` / `split_by_category`) and the I/O of `JsonRegistryStore` as **tools**, and holds no deterministic automatic execution (subcommand).

| Registry table | Method (default policy) | Rationale |
|---|---|---|
| **TASKS** | Date Archive (done after N days) | Completed tasks are naturally a "past log." They flow chronologically |
| **INDIVIDUALS** | Date Archive (blocked + long no-contact) | Departed parties are rarely turned into a past log |
| **KNOWLEDGE** | **Category partitioning** (no Archive) | Knowledge is **accumulative in essence** (a case DB is not discarded for being old). Bloat is solved by sharding into category units |
| **ABILITIES** | **Category partitioning** (no Archive, same shape as KNOWLEDGE) | A capability catalog is also accumulative in essence (not discarded). The partitioning unit/key is defined by the agent when needed (the JSON flexibility of §3.2) |

For detailed schemas and directory layout, see [STRUCTURE.md](./STRUCTURE_en.md).

### 3.6 Why the registry is persisted via git (volatile/persistent separation)

**Claude Code Routines** (Anthropic's cloud execution = cloud routine) are stateless (a fresh clone every time). State that may be volatile and the registry — which is accumulative in essence — have exactly opposite persistence requirements, so they are physically separated.

| Data | Persistence requirement | Solution |
|---|---|---|
| `offset.json` / `lease.json` / `media/` | Volatile OK | `state_dir` (restored/discarded via Telegram's ~24h retention / lease re-acquisition / retention deletion) |
| `individuals` / `tasks` / `knowledge` / `abilities` | **Persistence required** | `registry_dir` persisted via git (accumulative in essence; KNOWLEDGE is a case DB, ABILITIES is a capability catalog) |

**Persistence method** (`registry_sync` opt-in, disabled by default for backward compatibility):

- **Event-driven**: commit & push to a fixed branch on every registry add/remove. Low update frequency and high crash resilience
- **commit/push separation**: commit is local and immediate (reliable); push is best-effort (a transient failure is resent together at the next sync; since local commits accumulate, the only loss window is the tiny one of a crash before commit)
- **Fixed-branch operation**: push to a dedicated branch (`registry_branch`, default `claude/shiori-registry`), fetch at startup. Avoids the overhead of feature-branch divergence and merges (a horizontal application of the operational pattern of holding single-file state)
- **No force**: because multiple JSON files are independently and partially updated, force (replacing the whole tree) would clobber updates to other files. Normal push (whose automatic rejection of a non-fast-forward has conflict detection built in) + a `pull --rebase` fallback only on exception. The lease guarantees a single writer, and rebase serves only as insurance for the exception of external updates (manual edits, etc.)
- **config.json is canon for settings**: `registry_sync` / `registry_dir` / `registry_branch` are non-secret operational settings, hence config.json (pure 2-layer). The cloud routine reads them in a fresh clone

**registry_dir must be an independent git working tree (worktree)** (3-layer worktree provisioning, the permanent fix for the 2026-06-05 incident, this section being the SSoT):

Placing `registry_dir` in a **subdirectory** of the Private dev repo (e.g. `<PRIVATE_REPO>/ShioriSecretary/registry`) produces two defects at once——the startup-fetch `checkout -B` **switches the branch of the entire parent repo and destroys the dev tree** (defect 2), and in the cloud routine's fresh clone the registry_dir is absent, so a git invoked with `cwd=registry_dir` throws `OSError` (defect 1). The result was an incident where it **ran "without memory" while all 4 registry tables were empty** (T0002 misanswer, grant not loaded). Make registry_dir an **independent second worktree** and fix this fundamentally with 3 layers:

- **Layer 1 (root fix)** `bootstrap.sh`: idempotently provision `registry_dir` as a second worktree of the Private repo (`git worktree add -B <branch> <registry_dir> origin/<branch>`; refresh with `checkout -B origin/<branch>` if it already exists). Always force `origin/<branch>` — the SSoT is origin; it never grabs a stale local branch. On failure it does not `_shiori_die` but continues, with layer 3 warning (graceful)
- **Layer 2 (defense)** `GitCliAdapter.fetch_checkout`: **before** `checkout -B`, verify `rev-parse --show-toplevel == registry_dir`; on mismatch stop with `RegistryWorktreeError` (a `GitSyncError` subclass) = structurally forbidding accidental detonation of the parent repo
- **Layer 3 (observable)** `run_registry_fetch`: on fetch failure, emit a WARNING that "EMPTY tables = running without memory" (exit code unchanged; the one-shot notice to the principal is delegated to ROUTINE_PROMPT) = making silent empty-table operation visible

The fixed branch `claude/shiori-registry` is a **registry-dedicated orphan branch** holding **only registry-related items directly at root**——the 4 registry tables (`individuals/ tasks/ knowledge/ abilities/`) + `wal/` (the mechanism log for word-deed consistency, §3.7) + `artifacts/` (the secretary's deliverables layer, §3.10) (old: whole Private tree + nested `ShioriSecretary/registry/` → new: flat). This way the second worktree expands only the registry minimally and does not interfere with the dev tree. **Method B (a single worktree)** was settled through technical validation and proven in production operation (a post-fix cloud run completing provisioning→fetch→write→push).

> The backbone of the design follows §2 "separation of deterministic core and agent judgment": git operations (commit/push/rebase/fetch) are the deterministic world (code, testable), and the judgment of "what to keep" is the importance world (the agent).

> **About the cloud routine harness's work branch**: a cloud routine automatically generates a local work branch named `<registry_branch>-<random SUFFIX>` (e.g. `claude/shiori-registry-AbCdE`) per session. registry_sync, on the other hand, pushes directly to the fixed branch with `git push HEAD:<registry_branch>` (no SUFFIX), so the registry is always consolidated into a single branch (`registry_branch`). **A harness work branch is pushed to GitHub only when a commit rides on it**, so as long as nothing git-commits except registry_cli (i.e. the work branch stays empty), no residue is left on the remote. If `<registry_branch>-XXXXX` is accumulating on the remote, that is a sign that a manual commit not routed through registry_cli rode on it during a session——deletion is handled by manual cleanup (`gh api -X DELETE .../git/refs/heads/<branch>`); no standing per-session deletion process is needed.

### 3.7 Why a WAL (Write-Ahead Log) guarantees word-deed consistency (consistency vs durability)

The registry persistence of §3.6 makes push **best-effort** (a transient failure is resent next time). This is sufficient for durability (not losing data), but **has a hole for consistency (the agreement between an external promise and internal state)**: if, after the secretary replies "registered," the container is force-terminated and the push is dropped, a word-deed inconsistency can arise where "it was said but is not in the registry." This is solved not by redundancy but by **ordering** (WAL).

- **Write-ahead**: **before** a reply that promises a change to internal state, append the intent to the WAL log (`registry_dir/wal/WAL.jsonl`, on the same fixed branch as the registry) and push it
- **must-succeed push (pre-send gate)**: the WAL log push is the source of redo, so best-effort is not acceptable. Do not fire send-reply until the push succeeds = **if you cannot push, do not promise either** (stop before the contradiction surfaces). The registry add itself remains best-effort as before (it is the side that gets redone if dropped)
- **Redo at startup**: at the next startup, upsert the WAL's pending entries (the leftovers not in the registry) into the registry (key-idempotent). Place this **after** registry-sync (fetch) to reconcile against the latest registry. **Replies are not resent**——re-processing of the pre-send crash window is handled by offset re-acquisition (division of roles: offset = message re-processing, WAL = exclusively responsible for post-send registry drops). ※ This "replies are not resent" is a **premise specific to inbound replies**, and does not apply as-is to proactive-send (active push), which has no offset safety net. For the consistent extension of adding WAL resend only to the outbound path, see §3.9
- **Dual role**: the log doubles as both the WAL (consistency = pending redo) and short-term memory (the conversational context of the last 24h, read at startup). pending is held unconditionally (the redo source); done is cleaned up at the 24h startup checkpoint (so rotation does not depend on the termination handler = it does not get dropped on a force-termination)

> Consistency and durability are distinct problems: a durability hole is plugged with redundancy, but the hole here is "adding redundancy in the same failure domain (the same git push) just dies together," so it is plugged with ordering. The backbone of the design follows §2——the WAL's pure logic (reconcile/settle/checkpoint) is Domain, the order-adherence of push/redo is ROUTINE_PROMPT (the subordinate world), and git operations are deterministic. It runs only when `registry_sync` is enabled (a no-op when disabled, backward compatible).

### 3.8 Why abilities was added as a 4th table (a capability catalog, capability extension at the data layer)

Whereas individuals/tasks/knowledge are "fact data" (with whom, what was requested, how it was judged), `abilities` is a **catalog of the capabilities (skills) the secretary can exercise**——the 4th registry table responsible for "what can be done." Each record holds an invocation signal (`trigger`), a relative path to the skill entity (`skill_path`), and invocation guidance (`guidance`); before responding, the secretary queries `abilities list` for "is there a capability usable for this request" and, if applicable, exercises an external skill (e.g. a divination reading).

- **Why a 4th registry table (a peer)**: a capability too is the same shape as the three fact-data tables in that "the secretary judges, accumulates, and references it." Adding one kind to the table-driven `_REGISTRY_SPEC` + an `Ability` value object gets CRUD / validation / git persistence / startup fetch for free (directly inheriting §2 "separation of deterministic core and agent judgment"). The read wiring is made explicit as the "query before responding" operation in ROUTINE_PROMPT's 4-table orientation
- **Why a WAL target**: the WAL (§3.7) is the mechanism that protects the consistency between "a reply promising the other party 'registered'" and internal state. An `add` for abilities too can accompany "a reply declaring to the other party 'I can do XX'"——if it was declared but, due to a dropped push, is not in ABILITIES, the next vessel falls into the word-deed inconsistency of "I said I could but it is not registered." Being the same shape as individuals/tasks/knowledge, all 4 tables are uniformly made WAL-protection targets (`_WAL_KINDS` is all kinds of `_REGISTRY_SPEC`). For persistence, the git sync of §3.6 bears durability and the WAL bears consistency
- **Why capability extension at the data layer (the essence)**: by placing capabilities in ABILITIES.json (data) rather than ROUTINE_PROMPT (the procedural skeleton = the running body), **capabilities can be added without touching the running body**. Once the read wiring is established, subsequent capability additions require only an update to Private's ABILITIES.json (a git push), and re-registering the cloud routine's prompt body (with the risk of hitting the `RemoteTrigger update` pitfall) becomes unnecessary. In three-worlds terms, this is a design that stabilizes the procedural skeleton (the subordinate world = ROUTINE_PROMPT) and offloads the variable capability catalog into the deterministic world (data)
- **Distributability (audience scope)**: the distribution template (`ABILITIES.template.json`) does not bake in concrete capabilities; it ships empty. Operation-specific capabilities (e.g. a divination-skill integration) are placed in Private's actual ABILITIES.json——applying the template/data separation of §3.3 to capabilities as well
- **Self-append guard for capabilities**: the secretary `add`s a capability **only for a skill whose existence it has confirmed** (it does not declare uncertain/unverified capabilities = preventing the hallucination of writing a nonexistent capability into the catalog)

### 3.9 Why WAL resend is added to outbound (proactive-send) (idempotency for a path without the offset safety net) ★SSoT for the resend policy

The secretary is fundamentally inbound (receive → reply), but via a verbal authority grant (e.g. the conferral of free time) it also takes on **outbound (active push = proactive-send)** (the SSoT for the capability boundary is SecretaryRole). Adding push to the pull mouth (getUpdates) makes the conversational channel bidirectional. Because this outbound path structurally lacks the idempotency safety net (offset) that §3.7 presumed, the handling of WAL resend differs from inbound. This section is the **SSoT for the resend policy**; other documents (SKILL / ROUTINE_PROMPT / CHANGELOG) keep only a summary + a pointer to this section.

- **Why offset non-interference is an invariant**: `ProactiveSend` is a sister UseCase of `SendReply` with the `OffsetStore` dependency and offset advance removed. Since offset is **an inbound-only read ledger**, if outbound touched it, the accident of "advancing and missing unread inbound" could occur. By not holding it as a dependency (having no means to do so), it is structurally sealed off——a design that cannot be broken. The ordering of lease verification → attachment verification → send → lease renew, and the invariant "leave in place on send failure," are inherited from `SendReply`
- **Why a consistent extension that does not break §3.7 (the crux of the argument)**: §3.7 could say "the WAL is exclusively responsible for post-send registry drops, **replies are not resent**" because **inbound replies have offset as a safety net**——if the `update_id` is not advanced, the next cron's getUpdates re-fetches the same message and it is naturally resent. But proactive-send is not tied to inbound = **there is no triggering `update_id`** = the offset safety net is structurally absent. If it crashes before sending, that "intent to send" is never reproduced again. Therefore, for outbound, **WAL resend is the only idempotency guarantee**. Rather than overturning §3.7, this is "adding WAL resend only to the path without the offset safety net"——a consistent extension whereby, because the premise (presence or absence of the safety net) differs, the prescription differs (the inbound conclusion of §3.7 is kept intact)
- **happy-path settle (a successful send is not resent)**: `proactive-send` marks the outbound intent done immediately after a successful send (`domain.wal.settle_outbound` / `SettleOutboundIntent` / `run_wal_settle_outbound`). This **removes successfully-sent items from the next redo's scope**——what redo resends is only "the truly interrupted portion that crashed between a successful send and the done record." Symmetric to how registry kinds are marked done via registry reconciliation (reconcile/settle), outbound — which has no external source of truth — is **marked done by the sender itself with a direct created_at specification**. Lacking this causes "a successful send to be duplicated every startup, with a false failure apology riding on the duplicate" (the absence of happy-path settle = the bug up through v1.2.1, fixed in § Changelog 1.2.2)
- **Why idempotency is at-least-once (not pursuing exactly-once)**: the guarantee you can buy is at-least-once. Even after happy-path settle, if it crashes in the window of "successful send ↔ done record" it can still duplicate (a state where it has already arrived / only the done was dropped), but rather than crushing this with technology (TTL / content-hash dedup / two-phase commit), it is **neutralized at the social layer** by prefixing the body, **on resend, with the original scheduled send time + a neutral prefix** (`[<created_at>] にお送りしようとした内容を、念のためお届けします（既に届いていたらご容赦ください）`) to defuse "recipient confusion." The prefix **does not assert the cause of failure**——because in the window where a resend happens both sent and not-sent are possible, the wording is made not-false in either case (asserting "the system was down" would be a false apology in the successful case where it actually arrived). The freshness judgment (whether it is fine to receive an old push now) is left to the human, and no policy is held in code (following the deterministic core + agent judgment of §3.6/§3.7)
- **Why resend → immediate done (preventing an infinite resend loop)**: the outbound kind has no registry key (it is not on the reconcile/settle matching path), so redo, in an independent loop, "resends the (post-happy-path-settle remaining) pending exactly once → immediately `mark_done`." Placing the done-marking within the same transaction as the resend means that intent is not picked up again as pending at the next startup = preventing infinite resend. This is precisely why it holds no TTL (freshness-expiry discard)——fixing the resend count at one means it does not run amok even without a TTL. `wal-append --kind outbound`, having no registry key, keys on `created_at` (with `chat_id` required), and both the settle on a successful send and the resend on interruption point to that intent via this created_at
- **Pre-send gate and PII scope**: the outbound WAL lifecycle (`append`(pending) → `push`(must-succeed) → send → `settle`(done) → `push`(best-effort)) is **encapsulated by the `proactive-send` command** (it generates created_at internally and uses it as the settle key = eliminating the procedure-dependence of the agent handing off the key, and not making done-marking depend on procedure adherence). If it cannot push, it does not send either (sharing the pre-send gate of §3.7). When registry_sync is disabled, it passes through the WAL and sends only (backward compatible). The WAL payload is limited to the send body + attachment paths + chat_id + reply_to; it does not carry the entire conversation body (conforming to the PII scope of SECURITY §7)

> The backbone of the design follows §2 / §3.7——the WAL's pure logic (reconcile/settle/checkpoint and the inbound/outbound bifurcation) is Domain/UseCase, the order-adherence of push/redo and the judgment of "what to actively send at the parenthood gate" is ROUTINE_PROMPT (the subordinate world), and git operations and sending are deterministic. It runs only when `registry_sync` is enabled (a no-op when disabled, backward compatible).

### 3.10 Why artifacts is held as a deliverables layer (the reason to separate it from the deterministic 4 tables)

The 4 registry tables (individuals/tasks/knowledge/abilities, §3.1–3.8) are the **deterministic world**——structured data with `_REGISTRY_SPEC`-driven CRUD / schema validation / WAL protection. By contrast, `artifacts/` is a layer for the **non-templated deliverables** the secretary generates (reviews, chapter drafts, reports, etc.), and belongs to the **importance world**. Though it cohabits under the same `registry_dir`, the design is separated because its nature differs.

- **Why it is not given CRUD/WAL/schema (the essence)**: for a deliverable, "how to structure it" is itself the secretary's judgment (the importance world). Giving it a fixed schema or CRUD subcommand would inject the non-templated nature of deliverables into the determinism of the 4 tables. `artifacts/` standardizes only **its location (`registry_dir/artifacts/`) and that it is a git-persistence target**, and leaves the file composition, naming, and indexing (INDEX, etc.) to the secretary——as a concrete example, a deliverable may change shape from "per-chapter md + INDEX" to "a single JSON master," showing that **being schemaless is itself the requirement**. This follows §3.5 "the information's owner decides how it is held" and §2's three-worlds model
- **Why persistent**: deliverables are accumulative in essence (past deliverables are assets). On the git persistence of §3.6 (the orphan branch `claude/shiori-registry`), `artifacts/` rides alongside the 4 registry tables and `wal/`. Its persistence requirement is the opposite of the `state_dir`, which may be volatile
- **Why backup is tree-sync (not a fixed file list)**: whereas the 5 registry items (4 tables + WAL) are copied by a fixed enumeration because they are "single-file state SSoTs," `artifacts/` is a deliverables layer whose files increase and decrease, so it uses **directory-level tree sync** (`/shiori-registry-backup` enumerates all files with `ls-tree -r` and also reflects stale deletion with `rm -rf`). If the distribution target has no `artifacts/`, it is an empty loop = no-op (audience-scope safe)
- **Distributability (audience scope)**: the distribution template does not bake in deliverable entities (§3.3). `artifacts/` is a Private layer that grows naturally in real operation, and the public (distributable) describes only that "**the layer exists**"——standardizing, from day one of personal use, the structure where deliverables accumulate under registry_dir

> The backbone of the design follows §2 "separation of deterministic core and agent judgment": the 4 tables are deterministic (the code holds schema and CRUD), and artifacts is the importance world (giving only a place and persistence, leaving the contents to the judging entity). This layer's boundary is the backbone for not confusing a "structured registry table" with a "deliverable."

---

## 4. Scope: differences from the official plugin (/channels) and adoption decisions

A record of feature adoption decisions compared against Claude's official Telegram plugin (`/channels`). A reference point (a brake against additive bias) for **selectively implementing in light of the design goal, rather than "porting it because the official has it."**

Legend — Implementation: ✅ done / ❌ not / ❌(static) static alternative ｜ Need: ◎ essential / ○ useful / △ low priority / ✕ unnecessary

| Feature | Official tool | Use | TS impl. | Need | Adoption rationale |
|---|---|---|---|---|---|
| Image/file sending | `reply(files)` | Send back deliverables (figures/reports/docx) | ✅ | ◎ | The core of the write side. Auto-routes to sendPhoto / sendDocument by extension; `--file` may be repeated |
| typing indicator | `sendChatAction` | Ease the UX of the few-second lag before a response | ✅ | ○ | Stateless and lightweight; fires `send_chat_action` best-effort before sending |
| reply threading | `reply_to` | Make explicit which utterance is being replied to | ✅ | ○ | `reply_to_message_id` already exists in Domain; completed by wiring `--reply-to` (almost no cost) |
| **Understanding inbound media content** | (not in official) | voice/audio/video → transcript, docx/pptx/xlsx → markdown | ✅ | ◎ | **A strength where TS surpasses the official.** The official stops at file_id forward + download and does not read the content |
| Emoji reactions | `react` | A light ack (a read stamp) | ❌ | ✕ | Substitutable by UTF-8 emoji in the reply body. Furthermore, **in a 1:1 DM the bot cannot become an administrator, so inbound reactions are also structurally unreceivable** |
| Editing sent messages | `edit_message` | Progress updates for long-running tasks | ❌ | ○ | It has utility, but it brings `message_id` state management into the stateless design, so it is shelved. Add independently if needed |
| markdownv2 formatting | `format` | Headings / emphasis | ❌ | △ | MarkdownV2 requires escaping all of `_*[]()~>#+-=\|{}.!`, risking send failure. Easy to retrofit, so held under YAGNI |
| pairing authorization | access skill | Dynamically approve users at runtime | ❌(static) | ✕ | A static allowlist (`AUTHORIZED_CHATS`) is sufficient |
| bot commands | `setMyCommands` | Display command candidates on `/` input | ❌ | △ | The conversational style of talking to the agent in natural language is primary. Does not foreground a command system |
| sticker reception recognition | (receiving side) | Recognize stickers | ❌ | △ | An inbound extension. Add if it becomes necessary |
| group @mention | group policy | `@bot` invocation in a group (privacy mode) | ❌ | ✕ | Premised on a 1:1 DM (a personal chat with `<OWNER>`). Group operation is out of scope |
| cloud routine lifecycle | (not in official) | Register / update / stop a routine | ✅ | ◎ | **schedule / unschedule** manages the residency routine itself via `RemoteTrigger` (upsert / `enabled:false` stop). The official `/channels` is manual registration only |

### Structural summary

The features that are "in the official but not in TS" lean toward **send-side UX decoration**, while the features that are "in TS but not in the official" concentrate on **understanding inbound content** (turning voice/docx into transcript/md). This asymmetry surfaces as the flip side of the design philosophy that "the secretary's value is on the read side."

To organize it——**pairing is "who to let in," commands are "presenting what can be done," and group is "where to ask."** Because TS narrows to the operation of "`<OWNER>` and a few related parties, in 1:1, calling in natural language," these three are deemed unnecessary at present.

### Future decision guidance

- The remaining gaps (`edit_message` / `bot commands` / `sticker` recognition) are filled when actually wanted in operation. Do not preemptively implement on the grounds of "the official has it"
- When an adoption decision changes, update this table
