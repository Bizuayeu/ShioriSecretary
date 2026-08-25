"""配布境界の静的検査（母体固有の呼称が追跡ファイルに残っていないこと）。

ShioriSecretary は母体（TelegramSecretary / Homunculus-Weave）から切り出した公開
配布リポであり、母体側の人物名・運用主体名は配布物に載せない約束で分岐した。
この約束は grep の手作業に頼ると版を重ねるたびに漏れる——実際 v1.11.0 時点でも
同梱占術データに 3 箇所残っていた。追跡ファイル全体を毎回機械が読む網に変える。

検査対象を `git ls-files` にするのは、配布境界＝追跡集合だからである。
`docs/devlog/` のような配布除外ディレクトリは追跡外なので、ここでは見ない。

禁止語は unicode エスケープで持つ。本ファイル自身も追跡ファイルであり、リテラルで
書くと自分にマッチして恒久的に赤くなる（パス除外リストを作らない代わりの措置）。

網の限界（見ているのは追跡ファイルの生テキストだけ）:
- 語が 1 文字でも現れれば赤——CHANGELOG や設計文書で「◯◯を除去した」と当の語を
  書くと踏む。経緯は「母体固有の呼称」のように婉曲に書く（v1.11.1 の CHANGELOG が例）
- 検査語は 2 語のみ。組織名・ローカル絶対パス・母体のドメイン語彙は対象外＝
  SECURITY の配布前チェックリストで grep する側
- `git ls-files` 依存＝git checkout の外（tarball 展開）では動かない。marketplace
  経路は clone なので現行は問題ない
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).parents[3]

# 母体固有の呼称（Taikanshu / Jujichuro）。上記のとおりリテラルでは書かない。
FORBIDDEN = ("\u5927\u74b0\u4e3b", "\u5f93\u4e8b\u4e2d\u90ce")

_ICHING_DIR = (
    REPO_ROOT / "skills" / "precognitive-viewer" / "PrecognitiveViewer" / "I-Ching"
)
# \u5927\u5366 = daika（大卦）, database / spec
_ICHING_DB = _ICHING_DIR / "\u5927\u5366\u30c7\u30fc\u30bf\u30d9\u30fc\u30b9.json"
_ICHING_SPEC = (
    _ICHING_DIR
    / "\u30c7\u30b8\u30bf\u30eb\u5fc3\u6613\u30b7\u30b9\u30c6\u30e0\u4ed5\u69d8.md"
)

_JSON_BLOCK_RE = re.compile(r"```json\n(.*?)\n```", re.DOTALL)
_FORMAT_RE = re.compile(r'"format"\s*:\s*"([^"]*)"')


def _tracked_files() -> list[Path]:
    """追跡ファイルの一覧。パスは UTF-8 で明示 decode する。

    text=True は Windows で cp932 に落ち、日本語ファイル名が化けて読めなくなる。
    """
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=REPO_ROOT,
        capture_output=True,
        check=True,
    )
    return [
        REPO_ROOT / chunk.decode("utf-8")
        for chunk in result.stdout.split(b"\0")
        if chunk
    ]


def test_tracked_files_have_no_persona_names():
    """追跡ファイルのどの行にも母体固有の呼称が現れない。"""
    hits: list[str] = []
    for path in _tracked_files():
        try:
            text = path.read_bytes().decode("utf-8")
        except (UnicodeDecodeError, OSError):
            continue  # バイナリ・読めないものは対象外
        for lineno, line in enumerate(text.splitlines(), start=1):
            if any(word in line for word in FORBIDDEN):
                hits.append(f"{path.relative_to(REPO_ROOT).as_posix()}:{lineno}")
    assert not hits, "\n".join(hits)


def test_iching_spec_metadata_matches_database():
    """仕様書が引き写す metadata.format が、実データの値と一致する。

    呼称の置換はデータと仕様書の両方に要る。片方だけ直すと、仕様書が実在しない
    フォーマット名を語る文書になる（今回の置換で実際に起きうる乖離）。
    """
    db_format = json.loads(_ICHING_DB.read_text(encoding="utf-8"))["metadata"]["format"]
    spec_text = _ICHING_SPEC.read_text(encoding="utf-8")
    spec_formats = [
        m.group(1)
        for block in _JSON_BLOCK_RE.findall(spec_text)
        for m in _FORMAT_RE.finditer(block)
    ]
    assert spec_formats, "仕様書の json ブロックに format が見つからない"
    assert all(v == db_format for v in spec_formats), (
        f"spec={spec_formats} vs db={db_format!r}"
    )
