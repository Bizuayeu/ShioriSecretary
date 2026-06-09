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

# Resolve script dir robustly whether sourced or executed.
_shiori_script_path="${BASH_SOURCE[0]:-$0}"
_shiori_script_dir="$(cd "$(dirname "$_shiori_script_path")" && pwd)"

# --- 依存導入（pyproject.toml dependencies が SSoT、Tier 別に cloud routine 起動コストを制御）---
# base: httpx（必須）。Heavy モード時のみ markitdown(docx render) と voice(moonshine+av) を追加。
# media を扱わない Medium 運用・keep-alive 検証は httpx だけで起動が軽い。
python -m pip install --quiet "httpx>=0.27" || _shiori_die "httpx install failed"
if [ "${SHIORI_MEDIA_ENABLE_DOWNLOAD:-true}" != "false" ]; then
    _shiori_log "Heavy mode: installing markitdown (docx/pptx/xlsx render)..."
    python -m pip install --quiet "markitdown[docx,pptx,xlsx]>=0.1.6" || _shiori_die "markitdown install failed"
    # PDF テキスト層抽出（pdfplumber、MIT、pure-python）。passthrough(Read tool 依存)からの移行。
    # 画像 PDF を pypdfium2 で全ページ画像化し to_pil() で png 保存（Pillow）。pdfplumber が
    # 両者を transitive に引くが、pdf_renderer が pypdfium2 を直接 import するため再現性重視で明示 install。
    _shiori_log "installing pdfplumber + pypdfium2 + Pillow (PDF text-layer & image render)..."
    python -m pip install --quiet "pdfplumber>=0.11" "pypdfium2>=4.18.0" "Pillow>=9.1" || _shiori_die "pdf deps install failed"
    # voice(moonshine+av) は BUNDLE_VOICE=false で除外可（moonshine Community License は年商$1M未満のみ
    # 商用無料・~134MB model ゆえ大規模/ライセンス回避向け）。未導入時は watch が transcriber=None で
    # 起動し音声を skipped にフォールバック（render usecase は transcriber Optional）。
    if [ "${SHIORI_BUNDLE_VOICE:-true}" != "false" ]; then
        _shiori_log "installing voice deps (moonshine + av; BUNDLE_VOICE!=false)..."
        python -m pip install --quiet "moonshine-voice>=0.0.59" "av>=17.0" || _shiori_die "voice deps install failed"
    else
        _shiori_log "voice deps skipped (BUNDLE_VOICE=false) -> 音声は skipped にフォールバック"
    fi
else
    _shiori_log "Medium mode (MEDIA_ENABLE_DOWNLOAD=false): media deps skipped, httpx only"
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
            _shiori_reg_top="$(git -C "$SHIORI_REGISTRY_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
            if [ "$_shiori_reg_top" = "$SHIORI_REGISTRY_DIR" ]; then
                git -C "$SHIORI_REGISTRY_DIR" checkout -B "$_shiori_reg_branch" "origin/$_shiori_reg_branch" 2>/dev/null \
                    && _shiori_log "registry worktree refreshed ($_shiori_reg_branch)" \
                    || _shiori_log "warn: registry worktree refresh failed"
            else
                git -C "$_shiori_priv_repo" worktree prune 2>/dev/null
                rm -rf "$SHIORI_REGISTRY_DIR" 2>/dev/null
                git -C "$_shiori_priv_repo" worktree add -B "$_shiori_reg_branch" "$SHIORI_REGISTRY_DIR" "origin/$_shiori_reg_branch" 2>/dev/null \
                    && _shiori_log "registry worktree provisioned ($_shiori_reg_branch -> $SHIORI_REGISTRY_DIR)" \
                    || _shiori_log "warn: registry worktree add failed (registry-sync will surface empty-load)"
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
export SHIORI_POLL_SET_SEC="${SHIORI_POLL_SET_SEC:-580}"                     # メッセージ無し時の 1 窓上限 (bash timeout より短く)
export SHIORI_POLL_BASH_TIMEOUT_MS="${SHIORI_POLL_BASH_TIMEOUT_MS:-600000}"  # ポーリング call の bash tool timeout (=BASH_MAX_TIMEOUT_MS)
# SHIORI_MAX_TURNS: 日次総量レートキャップ (旧: deadline 異常時の暴走保険、役割変更)。
# 「~15通/h」を最低保証する天井 = アイドル下限(duration/POLL_SET_SEC) + 通数枠(15通/h)。
# 24h→約507 (148+359)、4h→約84 (24+60)。高密度日は最大このturn数まで伸び、到達で当日沈黙
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

_shiori_log "ready"
