"""配布版の自己完結性を静的に検証する（ShioriSecretary 同梱固有のテスト）。

同梱スキルは ShioriSecretary 本体（scripts/）と import 関係を持たず、
外部ネットワークも呼ばない独立パッケージである（接続は ABILITIES データ経由のみ）。
この境界が破れると「占いスキルを消すと秘書が壊れる／占いが外部に PII を送る」が
起こり得るため、許可外 import の混入を構造的に検出する。
"""
from __future__ import annotations

import re
from pathlib import Path

PACKAGE_ROOT = Path(__file__).parent.parent

# ShioriSecretary 本体側のトップレベルパッケージ（同梱スキルからは参照禁止）
_HOST_PACKAGES = ("scripts", "infrastructure", "adapters", "usecases", "domain")
# ネットワーク I/O（占術はローカル計算のみ。PII を外部送信しない）
_NETWORK_MODULES = ("httpx", "requests", "urllib", "socket", "http.client", "aiohttp")

_IMPORT_RE = re.compile(r"^\s*(?:from|import)\s+([A-Za-z_][\w.]*)", re.MULTILINE)


def _imported_top_modules(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return {m.split(".")[0] for m in _IMPORT_RE.findall(text)}


def _all_package_sources() -> list[Path]:
    return [p for p in PACKAGE_ROOT.rglob("*.py") if "tests" not in p.parts]


def test_does_not_import_host_packages():
    """ShioriSecretary 本体（scripts/ 配下のパッケージ群）を import しない。"""
    for src in _all_package_sources():
        tops = _imported_top_modules(src)
        leaked = tops & set(_HOST_PACKAGES)
        assert not leaked, f"{src.name} imports host package(s): {leaked}"


def test_does_not_import_network_modules():
    """ネットワーク I/O を行わない（占術はローカル計算のみ、PII 外部送信なし）。"""
    for src in _all_package_sources():
        tops = _imported_top_modules(src)
        leaked = tops & {m.split(".")[0] for m in _NETWORK_MODULES}
        assert not leaked, f"{src.name} imports network module(s): {leaked}"


def test_no_legacy_repo_paths_in_code():
    """旧リポ前提のパス案内（Expertises/ForesightReader 経由）がコードに残っていない。"""
    for src in _all_package_sources():
        text = src.read_text(encoding="utf-8")
        assert "Expertises/CorporateStrategist" not in text, f"legacy path in {src.name}"
