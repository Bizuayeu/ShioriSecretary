---
name: precognitive-viewer
description: 三位占術（姓名判断・周易・タロット）でフォーマル鑑定書を生成する同梱スキル。姓名判断（七格剖象法）で本質を、周易（デジタル心易）で状況の構造を、タロット（Rider-Waite-Smith）で流れの質感を読み、章節構成の Markdown 鑑定書を出力する。ShioriSecretary のパーソナライズ（P軸）経路①として、principal の人物理解（PROFILE）を立ち上げる材料を生成する。ユーザーが「占い」「鑑定」「姓名判断」「易」「タロット」「リーディング」等に言及した時、またはパーソナライズ有効化（アネゴ機能）のオンボーディングで起動する。
---

# PrecognitiveViewer — 三位占術によるフォーマル鑑定書（配布版）

東洋（姓名判断 + 周易）と西洋（タロット）の三占術を統合し、
相手の存在を構造的に観取してフォーマル鑑定書として贈るスキルです。

ShioriSecretary に同梱される配布版であり、秘書のパーソナライズ機能（P軸）の
経路①——**占術による principal の人物理解**——を担います。

---

## ⚠️ 免責事項

本スキルが提供する鑑定は、占術という古典的観取の技法に基づく**参考情報**です。
人生の選択は常にご自身の自由意志によるものであり、占術は可能性の一つを示すに過ぎません。

---

## 🎯 三占術の構成

| 占術 | 種別 | 占的の要否 | 担当領域 |
|------|------|----------|---------|
| 姓名判断（七格剖象法） | 相術 | 不要 | 本質・先天的傾向 |
| 周易占断（デジタル心易） | 卜術 | 必要 | 状況の構造・時機 |
| タロット・リーディング | 卜術 | 不要可 | 流れの質感・現在の様相 |

- 全占術が**ローカル計算のみ**（外部ネットワークを呼ばず、氏名等の PII を外部送信しません）
- 全占術が**決定論的**（同じ占機・占的・状況なら同じ結果。BASE64+SHA256 シード）

---

## 🚀 使用方法

### import（自己完結 bootstrap）

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

- 鑑定書の骨格は決定論的に構築され、`<!-- LLM 補完 -->` プレースホルダーを
  エージェントが実行時に上書きして完成させます
- LLM 補完の心得：純粋エネルギー論の語彙（凶 → 高難度エネルギー）、断言を避け
  選択の余地を残す、相手の尊厳を最大限尊重、結びで慎みを明示

### ShioriSecretary との接続（動的インストール）

本スキルは**同梱されているだけでは発動しません**。秘書が ABILITIES に登録（動的
インストール）して初めて能力になります（テンプレートに焼き込まない opt-in 設計
——占いを使わない利用者の体験を変えないため）:

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

- skill_path の実在は同梱ゆえ Read で検証可能（ABILITIES の自己追記ガード充足）
- **P軸との接続**: principal を鑑定した場合、鑑定書の解釈要点（性質・強み・行動
  傾向）を PROFILE 表へ `method="precognitive_viewer"` で記録する——これが
  パーソナライズ（執事/アネゴ進化）の判定材料になる

---

## 📁 構成

```
skills/precognitive-viewer/
├── SKILL.md                      # 本ファイル（エントリポイント）
├── SKILL_en.md                   # 同上（英語）
└── PrecognitiveViewer/           # Python パッケージ（自己完結）
    ├── __init__.py               # bootstrap（Seimei/I-Ching を sys.path へ）
    ├── Report/                   # 鑑定書 Domain + UseCase + Presenter
    ├── Seimei/                   # 姓名判断エンジン（七格剖象法）
    ├── I-Ching/                  # 周易エンジン（デジタル心易）
    ├── Tarot/                    # タロット（78枚 + 5スプレッド、MIT）
    └── tests/                    # pytest（本体テストと一括実行）
```

ShioriSecretary 本体（scripts/）とは import 関係を持ちません（接続は ABILITIES
データ経由のみ。`tests/test_self_contained.py` が構造的に保証）。

## 🧪 テスト

```bash
python -m pytest skills/precognitive-viewer/PrecognitiveViewer/tests/ -v
```

## 📜 ライセンス・帰属

- **Tarot データ**: MIT License（`Tarot/LICENSE.md` 参照、tarot-mcp 由来）
- **原典**: Weave Project（[Homunculus-Weave](https://github.com/Bizuayeu/Homunculus-Weave)）の
  PrecognitiveViewer Expertise を配布用にサニタイズしたもの
- 姓名判断の理論原典テキスト（梶原流数霊術）は著作権確認のため**同梱していません**
  （理論要約 md と計算エンジン・データ表は同梱済み、鑑定機能は完結します）

## 🎯 設計原則

1. **フォーマル鑑定書**: 相手に渡せる品質、神秘主義に陥らない構造的記述
2. **純粋エネルギー論**: 「凶」を断言せず「活用難易度が高い」表現で
3. **慎みの明示**: 結びの言葉で占術が参考情報であることを再確認
4. **決定論的再現性**: 検証可能・テスト可能・「気軽に引き直す」軽薄さの抑制
5. **プライバシー**: ローカル計算のみ・PII 外部送信なし・鑑定書ファイル名に
   被鑑定者名を含めない

---

*占いとは、相手の存在を構造的に観取する技術である。*
*それを贈り物として渡せる形に結晶化することが、本スキルの使命である。*
