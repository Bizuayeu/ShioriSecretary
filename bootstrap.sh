#!/bin/bash
# ShioriSecretary bootstrap — idempotent setup for cloud routine / manual runs.
#
# Use:
#   source <INSTALL_DIR>/bootstrap.sh
#     → exports SHIORI_SESSION_ID into the parent shell so subsequent
#       lease/watch/send-reply commands share the same owner (運用律 B 案)
#   bash   <INSTALL_DIR>/bootstrap.sh
#     → installs only, env exports do not persist
#
# Single source of truth for runtime deps: <INSTALL_DIR>/pyproject.toml
# source/exec デュアル対応の bootstrap パターン.

set -u

# Detect source vs exec so we can use `return` when sourced, `exit` when executed.
_shiori_sourced=0
if [ "${BASH_SOURCE[0]:-}" != "${0:-}" ]; then
    _shiori_sourced=1
fi

_shiori_die() {
    echo "[shiori-secretary-bootstrap] FAIL: $*" >&2
    if [ "$_shiori_sourced" = "1" ]; then
        return 1
    else
        exit 1
    fi
}

_shiori_log() { echo "[shiori-secretary-bootstrap] $*"; }

# 物理パス化（symlink/junction 成分を解消）。存在しないパスも python の realpath が
# 解決できる範囲で正規化する（cd && pwd -P は不在パスで使えない）。
_shiori_phys_path() { python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }

# registry worktree 再provision前のサニティチェック。
# config の registry_dir 誤設定（既存の実データディレクトリ等）を黙って rm -rf しないため、
# 「不在 / 空 / registry 既知エントリのみ」のときだけ破壊的再provisionを許す。
# 既知エントリ = worktree の .git、registry 4 表 + wal の各ディレクトリ、空ブランチ用 .keep。
# 未知エントリが 1 つでもあれば 1（呼び出し側が warn+skip、graceful 方針は worktree add 失敗時と同じ）。
_shiori_reg_safe_to_wipe() {
    [ ! -e "$1" ] && return 0   # 不在: rm -rf は no-op、worktree add が新規作成する
    [ ! -d "$1" ] && return 1   # ディレクトリ以外（ファイル/リンク）: 触らない
    local _entry _base
    for _entry in "$1"/* "$1"/.*; do
        _base="${_entry##*/}"
        case "$_base" in .|..) continue ;; esac
        [ -e "$_entry" ] || continue   # glob 不一致の literal はスキップ
        case "$_base" in
            .git|.keep|individuals|tasks|knowledge|abilities|wal) continue ;;
            *) return 1 ;;
        esac
    done
    return 0
}

# Resolve script dir robustly whether sourced or executed.
_shiori_script_path="${BASH_SOURCE[0]:-$0}"
_shiori_script_dir="$(cd "$(dirname "$_shiori_script_path")" && pwd)"

# --- 依存導入（pyproject.toml が SSoT、Tier 別に cloud routine 起動コストを制御）---
# editable install（packages=[] なので依存導入専用）で pyproject の extras を引く。
# ピンを bootstrap に再記述しない（二重管理だと片側だけ更新されるドリフトの温床）。
# base: httpx のみ。Heavy モード時に media extras（markitdown/pdf 系）、さらに voice extras を追加。
# media を扱わない Medium 運用・keep-alive 検証は base だけで起動が軽い。
# voice(moonshine+av) は BUNDLE_VOICE=false で除外可（moonshine Community License は年商$1M未満のみ
# 商用無料・~134MB model ゆえ大規模/ライセンス回避向け）。未導入時は watch が transcriber=None で
# 起動し音声を skipped にフォールバック（render usecase は transcriber Optional）。
if [ "${SHIORI_MEDIA_ENABLE_DOWNLOAD:-true}" != "false" ]; then
    if [ "${SHIORI_BUNDLE_VOICE:-true}" != "false" ]; then
        _shiori_log "Heavy mode: installing media+voice extras from pyproject..."
        python -m pip install --quiet -e "$_shiori_script_dir[media,voice]" || _shiori_die "media+voice deps install failed"
    else
        _shiori_log "Heavy mode (BUNDLE_VOICE=false): installing media extras from pyproject..."
        python -m pip install --quiet -e "$_shiori_script_dir[media]" || _shiori_die "media deps install failed"
        _shiori_log "voice deps skipped (BUNDLE_VOICE=false) -> 音声は skipped にフォールバック"
    fi
else
    _shiori_log "Medium mode (MEDIA_ENABLE_DOWNLOAD=false): installing base deps only (httpx)..."
    python -m pip install --quiet -e "$_shiori_script_dir" || _shiori_die "base deps install failed"
fi
python -c "import httpx" >/dev/null || _shiori_die "httpx import failed after install"

# --- Session ID 自動 export (運用律 B 案) ---
# lease acquire / watch / send-reply / lease renew が同じ owner を共有するように、
# bootstrap で session_id を session 全体に固定する。既に設定されていれば尊重 (冪等)。
export SHIORI_SESSION_ID="${SHIORI_SESSION_ID:-session-$(python -c 'import uuid; print(uuid.uuid4().hex[:8])')}"
_shiori_log "session_id=$SHIORI_SESSION_ID"

# --- INSTALL_DIR と STATE_DIR の絶対パス固定 (subshell cd でズレないように)---
# 後続 Step は (cd "$SHIORI_INSTALL_DIR" && ...) で subshell cd する。相対 STATE_DIR は
# その subshell cwd 基準で解決され幽霊パス化するため、bootstrap 実行時に skill root (INSTALL_DIR) 基準で
# 絶対化して固定する。既定 ./state は <INSTALL_DIR>/state/ に解決され、
# .gitignore の `/state/` に引き続きマッチする。
# INSTALL_DIR（=skill root, _shiori_script_dir）を自己解決して export。ROUTINE_PROMPT の各 bash call が
# config.json / scripts へ到達する唯一の基点。skill が repo 内のどこに置かれても、また junction 経由でも
# 自分の物理位置から絶対解決するため、別途 repo root の階層計算（旧 ../..）は不要（配置非依存）。
export SHIORI_INSTALL_DIR="$_shiori_script_dir"
export SHIORI_STATE_DIR="$(python -c 'import os, sys; print(os.path.abspath(os.environ.get("SHIORI_STATE_DIR") or sys.argv[1]))' "$_shiori_script_dir/state")"
_shiori_log "install_dir=$SHIORI_INSTALL_DIR state_dir=$SHIORI_STATE_DIR"

# --- 設定検証 (env + config.json の欠損/不正は exit 2 で fail-fast) ---
# validate-config を deadline 計算より先に実行する。config.json 不在/欠落/範囲外をここで弾けば、
# 後段の session_duration_sec 取得は「検証済み」前提で単純化できる（取得前に die させる）。
(cd "$_shiori_script_dir" && python scripts/main.py validate-config) || _shiori_die "validate-config failed"

# --- REGISTRY_DIR の絶対パス固定 (registry_dir も cwd 依存 .resolve() を回避)---
# config.json の registry_dir（2リポ親起点の相対）を bootstrap 実行時 cwd（=2リポ親）基準で絶対化して
# env 注入する。registry コマンドは後続 call で (cd "$SHIORI_INSTALL_DIR" && ...) するため、
# config.py 側の .resolve()（cwd=skill root）では二重ネストの幽霊パス化する（state_dir と同型）。
# config.json が値の正典、env は解決済み絶対パスのキャリア（STATE_DIR と同型）。未設定なら注入せず
# config.py が state_dir フォールバック。bootstrap source 時の cwd は 2リポ親（ROUTINE_PROMPT Step 2、cd 前）。
_shiori_registry_raw="$(python -c 'import json, sys; d = json.load(open(sys.argv[1], encoding="utf-8")); print(d.get("registry_dir") or "")' "$_shiori_script_dir/config.json")"
if [ -n "$_shiori_registry_raw" ]; then
    export SHIORI_REGISTRY_DIR="$(python -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$_shiori_registry_raw")"
    _shiori_log "registry_dir=$SHIORI_REGISTRY_DIR"

    # --- REGISTRY worktree provisioning（層1 根治：registry_dir を独立 git 作業ツリー化）---
    # registry_sync 有効時、registry_dir を Private リポの第二作業ツリー（worktree）として冪等に用意する。
    # これで GitCliAdapter の cwd=registry_dir が独立作業ツリーになり、起動時 fetch_checkout の
    # checkout -B が親 Private dev ツリーを汚染せず（欠陥2）、registry_dir 不在の OSError(Errno 2)
    # （欠陥1）も解消する。shiori-registry は registry ファイルを root 直下に持つ専用ブランチ。
    # provisioning 失敗時は _shiori_die せず継続し、registry-sync が空ロード警告（層3）を出す
    # （fail-fast でなく graceful。worktree add の dev ツリー非干渉は技術検証で実証済み）。
    # worktree add は -B "$BR" ... "origin/$BR" で常に origin から強制（registry の SSoT は origin）。
    # stateful 環境（手動/ローカル実行）に古い同名ローカルブランチが残っても掴まず最新を反映し、
    # 既存 worktree のリフレッシュ（checkout -B "origin/$BR"）と origin 強制で対称。
    _shiori_reg_sync="$(python -c 'import json,sys; print(str(json.load(open(sys.argv[1],encoding="utf-8")).get("registry_sync", False)).lower())' "$_shiori_script_dir/config.json")"
    if [ "$_shiori_reg_sync" = "true" ]; then
        _shiori_reg_branch="$(python -c 'import json,sys; print(json.load(open(sys.argv[1],encoding="utf-8")).get("registry_branch") or "claude/shiori-registry")' "$_shiori_script_dir/config.json")"
        # Private リポルート = private_dir の先頭パスセグメント（cwd=2リポ親起点）
        _shiori_priv_repo="$(python -c 'import json,sys; p=(json.load(open(sys.argv[1],encoding="utf-8")).get("private_dir") or "").replace(chr(92),"/").strip("/"); print(p.split("/")[0] if p else "")' "$_shiori_script_dir/config.json")"
        if [ -n "$_shiori_priv_repo" ] && { [ -d "$_shiori_priv_repo/.git" ] || [ -f "$_shiori_priv_repo/.git" ]; }; then
            git -C "$_shiori_priv_repo" fetch origin "$_shiori_reg_branch" 2>/dev/null \
                || _shiori_log "warn: registry fetch failed (registry-sync will retry / surface empty-load)"
            # toplevel 比較は物理パス同士で行う（symlink/junction 成分による
            # 「正しい worktree なのに不一致→誤って破壊的再provision」を防ぐ）。
            _shiori_reg_top="$(git -C "$SHIORI_REGISTRY_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
            if [ -n "$_shiori_reg_top" ] \
                && [ "$(_shiori_phys_path "$_shiori_reg_top")" = "$(_shiori_phys_path "$SHIORI_REGISTRY_DIR")" ]; then
                git -C "$SHIORI_REGISTRY_DIR" checkout -B "$_shiori_reg_branch" "origin/$_shiori_reg_branch" 2>/dev/null \
                    && _shiori_log "registry worktree refreshed ($_shiori_reg_branch)" \
                    || _shiori_log "warn: registry worktree refresh failed"
            elif _shiori_reg_safe_to_wipe "$SHIORI_REGISTRY_DIR"; then
                git -C "$_shiori_priv_repo" worktree prune 2>/dev/null
                rm -rf "$SHIORI_REGISTRY_DIR" 2>/dev/null
                git -C "$_shiori_priv_repo" worktree add -B "$_shiori_reg_branch" "$SHIORI_REGISTRY_DIR" "origin/$_shiori_reg_branch" 2>/dev/null \
                    && _shiori_log "registry worktree provisioned ($_shiori_reg_branch -> $SHIORI_REGISTRY_DIR)" \
                    || _shiori_log "warn: registry worktree add failed (registry-sync will surface empty-load)"
            else
                # registry_dir 誤設定の疑い（未知の実データが居る）: 黙って消さない。
                _shiori_log "warn: registry_dir has unexpected content; skipping destructive re-provision ($SHIORI_REGISTRY_DIR)"
            fi
            # __pycache__ を clone ローカルで ignore（追跡 .pyc の再生成差分が pull --rebase を塞ぎ
            # registry 書込が詰まる）。info/exclude 追記は working tree 非接触＝status を汚さず、
            # ブランチ側 .gitignore の有無に依らず効く。worktree 不成立時は rev-parse 失敗で skip。
            _shiori_reg_exclude="$(git -C "$SHIORI_REGISTRY_DIR" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null || true)"
            if [ -n "$_shiori_reg_exclude" ] && ! grep -qx '__pycache__/' "$_shiori_reg_exclude" 2>/dev/null; then
                mkdir -p "${_shiori_reg_exclude%/*}" 2>/dev/null
                echo '__pycache__/' >> "$_shiori_reg_exclude" \
                    && _shiori_log "registry exclude seeded (__pycache__/)"
            fi
        else
            _shiori_log "warn: Private repo root not found ($_shiori_priv_repo); registry provisioning skipped"
        fi
    fi
fi

# --- deadline 駆動ロングポーリング運用変数 (config.json 化) ---
# 「枠 (deadline)」と「ポーリング回数 (メッセージ頻度で可変)」を分離する。停止主軸は
# SHIORI_SESSION_DEADLINE_EPOCH (時刻)。回数は数えない (早期 exit→返信→再起動)。
# session_duration_sec は config.json が正典 (validate-config 検証済み)。bootstrap はローカル取得して
# deadline を計算するのみ。SHIORI_SESSION_DURATION_SEC env は作らない (純2層: duration 設定値を env に置かない、
# env は秘匿のみ)。deadline_epoch は計算"結果"ゆえ env スナップショットに残してよい。
_shiori_duration="$(python -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["session_duration_sec"])' "$_shiori_script_dir/config.json")" || _shiori_die "failed to read session_duration_sec from config.json"
export SHIORI_SESSION_DEADLINE_EPOCH="${SHIORI_SESSION_DEADLINE_EPOCH:-$(( $(date +%s) + _shiori_duration ))}"  # 停止主軸: この epoch 秒を過ぎたら /goal 停止
# SHIORI_POLL_SET_SEC の不変条件: max_duration + timeout(30) < bash_timeout/1000 (=600)。
# 破ると最終サイクルが窓を超えて回り SIGTERM(143) で落ちる。540 が残す 30s のマージンは
# Telegram 5xx リトライで long-poll が伸びた分の吸収代 (経緯は CHANGELOG v1.4.2)。
export SHIORI_POLL_SET_SEC="${SHIORI_POLL_SET_SEC:-540}"                     # メッセージ無し時の 1 窓上限 (bash timeout より短く)
export SHIORI_POLL_BASH_TIMEOUT_MS="${SHIORI_POLL_BASH_TIMEOUT_MS:-600000}"  # ポーリング call の bash tool timeout (=BASH_MAX_TIMEOUT_MS)
# SHIORI_MAX_TURNS: 日次総量レートキャップ (旧: deadline 異常時の暴走保険、役割変更)。
# 「~15通/h」を最低保証する天井 = アイドル下限(duration/POLL_SET_SEC) + 通数枠(15通/h)。
# 24h→約520 (160+360)、4h→約86 (26+60)。高密度日は最大このturn数まで伸び、到達で当日沈黙
# (lease release→次 cron が offset 継続)。先食い可ゆえ毎時平準化ではない。
# 短 duration (テスト用、約1.4h 未満) では整数除算で算出が過小/0 になり /goal が即死するため
# floor=30 を敷く (0 ターン停止の回避＝最低限の暴走保険予算)。env で上書き可。
_shiori_msg_per_hour=15
_shiori_max_turns_calc=$(( _shiori_duration / SHIORI_POLL_SET_SEC + _shiori_msg_per_hour * _shiori_duration / 3600 ))
export SHIORI_MAX_TURNS="${SHIORI_MAX_TURNS:-$(( _shiori_max_turns_calc < 30 ? 30 : _shiori_max_turns_calc ))}"
_shiori_log "deadline-driven poll: deadline=$SHIORI_SESSION_DEADLINE_EPOCH (now+${_shiori_duration}s from config.json), window<=${SHIORI_POLL_SET_SEC}s, max_turns=${SHIORI_MAX_TURNS}, bash timeout ${SHIORI_POLL_BASH_TIMEOUT_MS}ms"

# --- 派生 env を source 可能ファイルへ書き出し (Bash tool は call 間で env 揮発) ---
# Claude Code / cloud routine の Bash tool は call 毎に fresh shell (cwd のみ persist、env は揮発)。
# 運用律 B 案の「source で親シェルへ引き継ぐ」は成立しないため、後続 Step が各 call 冒頭で
# re-source する env snapshot を残す。TELEGRAM_BOT_TOKEN / AUTHORIZED_CHATS は Environment 注入で
# 各 call に入る & 秘匿のため、ここには書かない (出力漏洩スキャン規律)。
_shiori_env_file="${SHIORI_ENV_FILE:-/tmp/shiori-secretary.env.sh}"
{
    echo "# Generated by bootstrap.sh. Re-source at the top of each subsequent Bash call."
    echo "export SHIORI_SESSION_ID=$(printf '%q' "$SHIORI_SESSION_ID")"
    echo "export SHIORI_INSTALL_DIR=$(printf '%q' "$SHIORI_INSTALL_DIR")"
    echo "export SHIORI_STATE_DIR=$(printf '%q' "$SHIORI_STATE_DIR")"
    echo "export SHIORI_SESSION_DEADLINE_EPOCH=$(printf '%q' "$SHIORI_SESSION_DEADLINE_EPOCH")"
    echo "export SHIORI_POLL_SET_SEC=$(printf '%q' "$SHIORI_POLL_SET_SEC")"
    echo "export SHIORI_POLL_BASH_TIMEOUT_MS=$(printf '%q' "$SHIORI_POLL_BASH_TIMEOUT_MS")"
    echo "export SHIORI_MAX_TURNS=$(printf '%q' "$SHIORI_MAX_TURNS")"
    # registry_dir は registry を使う環境でのみ存在（config.json に registry_dir があれば上で絶対化済み）。
    if [ -n "${SHIORI_REGISTRY_DIR:-}" ]; then
        echo "export SHIORI_REGISTRY_DIR=$(printf '%q' "$SHIORI_REGISTRY_DIR")"
    fi
} > "$_shiori_env_file" || _shiori_die "failed to write env snapshot: $_shiori_env_file"
export SHIORI_ENV_FILE="$_shiori_env_file"
_shiori_log "env snapshot -> $_shiori_env_file"

# 起動時オリエンテーションの入口を、失敗するステップより上流（ここ）で名指しする。
# 7表を並べて list すると registry 肥大で出力上限を超え、ハーネスが persisted-output へ
# 退避して「データがコンテキストに載らないまま exit 0」する沈黙失敗になる（DESIGN §3.12）。
_shiori_log "startup digest: python scripts/main.py orientation  (do NOT list the 7 tables side by side)"

_shiori_log "ready"
