---
name: precognitive-viewer
description: A bundled skill that generates a formal reading report via triple divination (Japanese name divination, I Ching, and tarot). It reads the person's essence with name divination (the seven-grid method), the structure of the situation with I Ching (digital shin'eki), and the texture of the flow with tarot (Rider-Waite-Smith), and outputs a chaptered Markdown reading report. As ShioriSecretary's personalization (P-axis) route ①, it generates the material that bootstraps person understanding (PROFILE) of the principal. Invoke when the user mentions fortune-telling, a reading, name divination, I Ching, tarot, etc., or during onboarding when enabling personalization (the Anego (big-sis) mode).
---

# PrecognitiveViewer — A formal reading report via triple divination (distribution build)

A skill that integrates three divination arts — Eastern (name divination + I Ching) and
Western (tarot) — to observe a person's being structurally and present it as a formal
reading report, given as a gift.

This is the distribution build bundled with ShioriSecretary, serving route ① of the
secretary's personalization feature (the P axis) — **person understanding of the
principal through divination**.

---

## ⚠️ Disclaimer

The readings this skill provides are **reference information** based on divination, a classical technique of observation.
Life choices are always a matter of your own free will; divination shows no more than one possibility.

---

## 🎯 The three divination arts

| Art | Type | Question focus | Domain |
|------|------|----------|---------|
| Name divination (seven-grid method) | Form reading | Not required | Essence, innate tendencies |
| I Ching divination (digital shin'eki) | Casting | Required | Structure of the situation, timing |
| Tarot reading | Casting | Optional | Texture of the flow, present aspect |

- Every art is **local computation only** (no external network calls; PII such as names is never sent externally)
- Every art is **deterministic** (the same moment, focus, and situation yield the same result; BASE64+SHA256 seeding)

---

## 🚀 Usage

### import (self-contained bootstrap)

```python
import sys
from datetime import datetime
from pathlib import Path

# スキルルートを sys.path に追加（Seimei/ と I-Ching/ へのパス追加は
# PrecognitiveViewer/__init__.py の bootstrap が自動で行う）
sys.path.insert(0, str(Path("skills/precognitive-viewer").resolve()))

from PrecognitiveViewer.Report.composer_usecase import ReadingReportComposerUseCase
from PrecognitiveViewer.Report.domain import Recipient
from PrecognitiveViewer.Report.filename import ReportFilenameGenerator
from PrecognitiveViewer.Report.iching_usecase import IChingDivinationUseCase
from PrecognitiveViewer.Report.presenter import ReadingReportPresenter
from PrecognitiveViewer.Report.seimei_usecase import SeimeiAssessmentUseCase
from PrecognitiveViewer.Report.tarot_usecase import TarotReadingUseCase
from PrecognitiveViewer.Report.triple_divination import TripleDivinationUseCase

# 1. 各占術を実行
seimei = SeimeiAssessmentUseCase().assess("山田", "太郎", [3, 5], [4, 9])
iching = IChingDivinationUseCase().divine("今年の展望", "新しい挑戦を考えている")
tarot = TarotReadingUseCase().read("今年の展望", "新しい挑戦を考えている", "celtic_cross")

# 2. 統合 → 鑑定書生成
triplet = TripleDivinationUseCase().synthesize(seimei, iching, tarot)
recipient = Recipient(full_name="山田太郎", reading="やまだたろう", context="今年の展望")
ts = datetime.now()
report = ReadingReportComposerUseCase().compose(triplet, recipient, ts)

# 3. Markdown 整形（examiner には秘書の人格名＝config.json の agent_name を渡す）
markdown = ReadingReportPresenter(examiner="栞").render(report)
Path(ReportFilenameGenerator.generate(ts)).write_text(markdown, encoding="utf-8")
```

- The report's skeleton is built deterministically, and the agent completes it at run time
  by overwriting the `<!-- LLM 補完 -->` placeholders
- Guidance for the LLM completion: use the vocabulary of pure energy theory ("inauspicious" →
  "high-difficulty energy"), avoid assertions and leave room for choice, respect the
  recipient's dignity to the fullest, and make the humility explicit in the closing words

### Connection with ShioriSecretary (dynamic install)

**Being bundled alone does not activate this skill.** It becomes a capability only when the
secretary registers it into ABILITIES (dynamic install) — an opt-in design that is not baked
into the template, so the experience of users who don't use divination is unchanged:

```bash
python scripts/main.py abilities add --json '{
  "id": "precognitive-viewer",
  "name": "三位占術鑑定",
  "trigger": "占い・鑑定・姓名判断・易・タロット・リーディング・人物プロファイリング",
  "skill_path": "<INSTALL_DIR>/skills/precognitive-viewer",
  "guidance": "SKILL.md を読み三占術で鑑定書を生成。principal の鑑定なら解釈の要点を PROFILE（method=precognitive_viewer）にも記録する",
  "related": [],
  "created_at": "<ISO8601>", "updated_at": "<ISO8601>"
}'
```

- Because the skill is bundled, the existence of skill_path can be verified with Read (satisfying the ABILITIES self-append guard)
- **Connection to the P axis**: when the principal is the one read, record the report's key
  interpretive points (nature, strengths, behavioral tendencies) into the PROFILE table with
  `method="precognitive_viewer"` — this becomes the judgment material for personalization
  (the butler/anego evolution)

---

## 📁 Layout

```
skills/precognitive-viewer/
├── SKILL.md                      # this file (entry point)
└── PrecognitiveViewer/           # Python package (self-contained)
    ├── __init__.py               # bootstrap (adds Seimei/I-Ching to sys.path)
    ├── Report/                   # reading-report Domain + UseCase + Presenter
    ├── Seimei/                   # name-divination engine (seven-grid method)
    ├── I-Ching/                  # I Ching engine (digital shin'eki)
    ├── Tarot/                    # tarot (78 cards + 5 spreads, MIT)
    └── tests/                    # pytest (run together with the body's tests)
```

It has no import relationship with the ShioriSecretary body (`scripts/`) — the connection is
via ABILITIES data only (structurally guaranteed by `tests/test_self_contained.py`).

## 🧪 Tests

```bash
python -m pytest skills/precognitive-viewer/PrecognitiveViewer/tests/ -v
```

## 📜 License and attribution

- **Tarot data**: MIT License (see `Tarot/LICENSE.md`; derived from tarot-mcp)
- **Origin**: a distribution-sanitized port of the PrecognitiveViewer Expertise from the
  Weave Project ([Homunculus-Weave](https://github.com/Bizuayeu/Homunculus-Weave))
- The theoretical source texts for the name divination (the Kajiwara school of numerology)
  are **not bundled** pending copyright confirmation (the theory-summary md, the computation
  engine, and the data tables are bundled, so the reading capability is complete)

## 🎯 Design principles

1. **A formal reading report**: a quality you can hand to the recipient; structural description that never lapses into mysticism
2. **Pure energy theory**: never assert "inauspicious"; phrase it as "energy that is difficult to harness"
3. **Explicit humility**: the closing words reaffirm that divination is reference information
4. **Deterministic reproducibility**: verifiable, testable, and a restraint on the frivolity of "casually redrawing"
5. **Privacy**: local computation only, no PII sent externally, and the report's
   filename never contains the name of the person read

---

*Divination is the art of observing a person's being structurally.*
*Crystallizing it into a form that can be given as a gift is this skill's mission.*
