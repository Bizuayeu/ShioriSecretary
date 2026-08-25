"""SECURITY 日英パリティの静的検査（形だけを見る網）。

`docs/SECURITY.md`（日本語正本）と `docs_en/SECURITY_en.md` は同じ内容を二言語で
持つ対であり、正本を直すたびに英語版を人手で追随させてきた。その追随が版ごとに
漏れる：v1.11.1 で節見出しの数、v1.11.2 で状態マーカー列（§4/§9）を目視で合わせ、
その検収でさらに §1/§2 の箇条欠落が見つかった——同じ乖離が 3 度目に達したので、
目視をやめて機械の網に変える。

検査するのは形だけ——節数・節ごとの箇条数・見出しの状態マーカー列の三点であり、
訳文の質や意味の一致は見ない（機械に判定できない領域はここに持ち込まない）。
対象も SECURITY の 1 対に限る。他の日英対に広げるかは、そこで乖離が 3 度起きて
から決める。

状態マーカー（check mark / warning sign / clipboard の 3 種）は本ファイル内では
unicode エスケープで持ち、失敗メッセージにも `ascii()` で埋める。cp932 のコンソール
へ絵文字を出すと UnicodeEncodeError で落ち、検査結果そのものが読めなくなるため
（test_distribution_boundary.py が禁止語をエスケープで持つのと同じ流儀）。
"""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).parents[3]
JA_PATH = REPO_ROOT / "docs" / "SECURITY.md"
EN_PATH = REPO_ROOT / "docs_en" / "SECURITY_en.md"

# \u2705 = check mark, \u26a0 = warning sign, \U0001f4cb = clipboard
_MARKER_RE = re.compile("[\u2705\u26a0\U0001f4cb]")
# 異体字セレクタ（\u26a0 は \ufe0f 付きで書かれる）を落としてから拾う。
_VARIATION_SELECTOR = "\ufe0f"


def _sections(path: Path) -> list[tuple[str, list[str]]]:
    """`## ` 見出しで節に切り、節ごとの箇条（`- ` 始まりの行）を返す。

    最初の `## ` より前（表題と前置き）はどの節にも属さないので捨てる。
    どちらの文書も fenced code block を持たないため、コード中の `- ` を
    箇条と誤読する余地はない（状態機械を置かない理由）。
    """
    sections: list[tuple[str, list[str]]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            sections.append((line[3:].strip(), []))
        elif line.startswith("- ") and sections:
            sections[-1][1].append(line)
    return sections


def _markers(heading: str) -> list[str]:
    return _MARKER_RE.findall(heading.replace(_VARIATION_SELECTOR, ""))


def test_section_headings_pair_up():
    """節の数が日英で一致する。"""
    ja, en = _sections(JA_PATH), _sections(EN_PATH)
    assert len(ja) == len(en), f"ja={len(ja)} sections, en={len(en)} sections"


def test_bullet_counts_match_per_section():
    """対応する節の箇条の数が日英で一致する。"""
    ja, en = _sections(JA_PATH), _sections(EN_PATH)
    # 節数の不一致は test_section_headings_pair_up の担当なので、共通部分だけ見る。
    mismatches = [
        f"{ja_title}: ja={len(ja_bullets)} en={len(en_bullets)}"
        for (ja_title, ja_bullets), (_, en_bullets) in zip(ja, en, strict=False)
        if len(ja_bullets) != len(en_bullets)
    ]
    assert not mismatches, "\n".join(mismatches)


def test_status_markers_match_per_section():
    """対応する節の見出しが同じ状態マーカー列を持つ。"""
    ja, en = _sections(JA_PATH), _sections(EN_PATH)
    mismatches = [
        f"{ja_title}: ja={ascii(_markers(ja_title))} en={ascii(_markers(en_title))}"
        for (ja_title, _), (en_title, _) in zip(ja, en, strict=False)
        if _markers(ja_title) != _markers(en_title)
    ]
    assert not mismatches, "\n".join(mismatches)
