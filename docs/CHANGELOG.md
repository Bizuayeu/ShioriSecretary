# Changelog

すべての主要な変更をこのファイルに記録する。形式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/)、バージョニングは [Semantic Versioning](https://semver.org/lang/ja/) に準拠する。

> **ShioriSecretary** — Claude のモデル（Opus/Fable/Mythos）に挟む"魔法の栞"。モデルに秘書を授ける、サブスクだけ・専用サーバ不要のサーバーレス秘書エージェントの変更履歴。

## [1.11.2] - 2026-08-25 — 英語版 SECURITY が語る実装状態を、実装に追いつかせる

公開配布リポの英語版 SECURITY が、実装済みの防御——outbound の機械スキャンとレート制限——を「未実装」と公言していた。
1.11.1 で日英の見出しを突き合わせた一致確認（12/12）は見出しの対応を見るだけで、節の中身が実装から離れたことは検出しない。
母体に `docs_en/` が無く EN は Shiori 固有文書ゆえ、JA への実装更新に EN の追随を強いる装置がそもそも無かった。**コードの挙動は変えていない**。

### Fixed

- **`docs_en/SECURITY_en.md` §4 / §9 が実装に追従していなかった**——§4 は見出しに ✅（機械スキャン）が無く、`redact_outbound` の箇条（形状で決まる 4 種・`[REDACTED:<種別>]` への置換・送信は止めず stderr 1 行・`SendReply` / `ProactiveSend` の両方に適用）が丸ごと欠けていた。§9 は「未実装（設計要件）」の 1 箇条のままで、実装は v1.9.0 以降存在する（chat_id 別のスライディング窓）。**日本語正本 §4 / §9 の内容と状態マーカーに揃えた**（JA は不変）

### Changed

- **`scripts/tests/usecases/test_orientation.py` に残っていた母体語彙を配布版の既存語へ**——1.11.1 で同じテストの主題語彙を直した際の取り残し。訳語は既存テストの対から取り、新しい語を発明していない。フィクスチャと assert を対で直したので**挙動不変・テスト件数不変**

### 移行（稼働中の routine への波及）

**不要**——本版は文書とテストのみで、読み取り経路で発火する検証は増えていない（配布三則(3)の対象外）。CLI・スキーマ・挙動はいずれも 1.11.1 と同一で、**prompt body の再登録も要らない**。

## [1.11.1] - 2026-08-25 — 配布境界の約束を、定義と常設の検査で留める

母体から切り出した配布物としての約束——配布三則——は、CHANGELOG から参照されるだけで定義の本体がどこにも無かった。
その(2)は grep の手作業に頼っており、現に v1.11.0 時点でも同梱占術データに母体固有の呼称が残っていた。
**定義を SECURITY §8 に置き、検査をテストに常設する**。コードの挙動は変えていない。

### Added

- **配布境界の静的検査 `scripts/tests/infrastructure/test_distribution_boundary.py`**——`git ls-files` の追跡ファイル全件を読み、母体固有の呼称 2 語がどの行にも現れないことを検査する（**除外規則を持たず**、違反は `path:line` で全件列挙）。配布境界＝追跡集合ゆえ、`docs/devlog/` のような配布除外ディレクトリは自然に対象外になる。禁止語は unicode エスケープで持つ——テスト自身も追跡ファイルであり、リテラルで書けば自分にマッチして恒久的に赤くなる
- **同梱 I-Ching の仕様書と実データの metadata 一致検査**——仕様書が引き写す `format` と JSON の `metadata.format` を突合する。呼称の置換はデータと仕様書の両方に要り、片方だけ直すと仕様書が実在しないフォーマット名を語る文書になる

### Changed

- **同梱 I-Ching データの `metadata`（`format` / `created_by`）から母体固有の呼称を除いた**——**挙動は中立**（コードは `metadata` を読まない）で、六十四卦・384 爻の占術データそのものは変えていない
- **`test_orientation.py` の subjects フィクスチャ語彙を配布版の汎用語へ**——テストデータであっても運用固有の主題は運用主体の輪郭を露出する（母集団スコープ、SECURITY §7）
- **`docs_en/DESIGN_en.md` に目次を新設し、§3.8 の節構成を日本語正本へ揃えた**——見出しの日英対応が揃い、片方にだけ在る節が生まれない
- **SECURITY §8 に配布三則を明文化した**——従来は CHANGELOG からの参照だけで定義本体が無く、規則の内容が版の記憶に依存していた。配布前チェックリストの固有名の項も、常設検査が担う範囲（人格名・運用主体名）を名指しに改めた

### 移行（稼働中の routine への波及）

**不要**——本版は文書とテストのみで、読み取り経路で発火する検証は増えていない（配布三則(3)の対象外）。CLI・スキーマ・挙動はいずれも 1.11.0 と同一で、**prompt body の再登録も要らない**。

## [1.11.0] - 2026-08-25 — 書き込み口を一つの検証で揃え、果たせなかった約束を dead に残す

記憶の正典へ書く口は四つあるのに、検証が掛かっていたのは二つだけだった。
残る二つ——WAL の入口と起動時 redo——は、`add` が受理しない payload をそのまま正典へ通す。
読み側は fail-open で鳴らず、`settle` の done 化と 24h 掃除で証拠まで消える。**エラーを出さない壊れ方**である。

### Added

- **`wal-drop --kind --key`**——`dead` になった intent を WAL から落とし、固定ブランチへ **must-succeed** push する（履行しないと決めた約束を明示的に畳む）。**`pending` / `done` は落とせない**（不在も同じく exit 2）。果たしていない約束を黙って捨てる口は開けない、が設計判断（秘書倫理としての SSoT は SecretaryRole の「言行一致」）
- **WAL の状態語彙に `dead` を足した**（`pending` / `done` / `dead`、理由を持つ省略可能フィールド付き）。スキーマ変更は加算のみで、`reason` を持たない既存行の書き戻しは従来と同一。`dead` は checkpoint の掃除対象にならず、`reconcile`（redo の入力）にも乗らない——**redo ソースではなく、未履行の約束の記録**だから

### Changed

- **四つの書き込み口が一つの検証関門を共有するようになった**——`add` / `import` / `wal-append` / `wal-redo` がいずれも `registry_cli.canonical_record`（未知トップレベルキー・語彙外 subject・許可集合外 category の判定＋値オブジェクトを通した正準化）を呼ぶ。検証を口ごとに書けば、口を増やすたびに「そこだけ緩い」抜け道が増える。`add` / `import` の挙動と stderr 文言は不変（公開名化は純粋なリファクタ）
- **`wal-append`（registry kind）が fail-closed になった**（後方非互換）——不正 payload は **exit 2**（stderr `invalid <kind> wal payload: <理由>`）で、**ログを書く前に**止まる。WAL は must-succeed push で remote へ出る片道の口ゆえ、不正を redo まで持ち越すと「push 済みなのに永久に反映されない intent」が残る。入口で弾けば、その場で書き直せる。書かれる payload は正準形（`from_dict` → `to_dict`。`subjects` 省略が `[]` で載る等）。`outbound` kind は値オブジェクトを持たないため従来どおり
- **`wal-redo` が各 intent を検証し、落ちたものを `dead` へ隔離するようになった**——registry へは書かず、理由を添えて状態を移す。stdout は `wal redo: redone=N resent=N kept=N dead=N` へ変わった（**`dead` を加えた 4 フィールド形**。旧 3 フィールド形を引用していた記述は追従済み）。`dead` が示すのは**ログに残る総数**であって今回隔離した分ではない——残存する dead は毎起動 stderr へ `wal redo: dead <kind> key=<key>: <理由>` として 1 行ずつ出る。**exit は 0 のまま**で起動経路を止めない
- **隔離の理由に payload の値を残さない**——検証の例外文は弾いた値そのもの（individuals / profile なら名前や note 断片）を含みうる一方、`dead` は無期限に残り毎起動 stderr へ出る。例外型名＋メッセージ先頭を**既存の topic 幅**で切り詰めてから記録する（新しい閾値を発明しない）。SECURITY §7 に保持期間の例外（`wal-drop` まで保持）とあわせて明記
- **DESIGN §3.7 を WAL 設計根拠の SSoT として見出しに明示**（§3.9 の再送方針・§3.12 の起動時オリエンテーションと同じ流儀）。書き込み口と検証の関係・`dead` の意味・状態ごとの保持期間（pending 無条件／dead 無条件／done は 24h）を同節に集約し、他文書は要約＋ポインタに留めた

### 移行（稼働中の routine への波及）

1. **body 再登録は不要**——コードと SKILL.md は毎枠読まれるため、routine が毎枠 fresh clone する構成なら、更新を反映した次の枠から効く。**ROUTINE_PROMPT の文言変更だけは次のまとめた再登録で足りる**（手順の説明であって値ではない。1.10.3 と同型）
2. **1.11.0 未満で書かれた pending は、初回 redo で検証される**——通れば従来どおり registry へ反映され、通らなければ `dead` になる。旧版が緩く受けて WAL に積んだ不正 payload の窓は、この初回 redo が塞ぐ。stderr の `wal redo: dead <kind> key=<key>: <理由>` を読み、正しい payload で同じ key を `add` し直す（次回 redo の `settle` が done 化＝自己治癒）か、`wal-drop --kind <kind> --key <key>` で畳む
3. **`wal-append` が exit 2 で弾くようになる**（後方非互換）——registry kind の payload は `add` へ渡すのと**同一のレコード**（`created_at` / `updated_at` を含む）でなければ通らない。手順書で「payload は `add` に渡すレコードと同一でよい」と読めていた箇所は「同一でなければならない」に変わった。弾かれた時点でログには何も書かれていないので、その intent について対外的な約束をしないこと
4. **1.11.0 未満へのダウングレードは `dead` 行を黙って捨てる**——旧版の loader は `dead` を未知 status として `ValueError` で読み飛ばし、その後の rewrite（done-marking / checkpoint）で永久に落とす。コードでは防げない非可逆な向きなので、`dead` を残したまま巻き戻さない（先に消化するか、`WAL.jsonl` を退避してから戻す）

## [1.10.3] - 2026-08-16 — 障害時にだけ露出する窓の不変条件と、静かに落ちる二つの読み筋

平常時は成立して見え、障害時にだけ破れる条件が一つ（窓）、
守れていると誤解されうる保証が一つ（WAL）、
不在と誤判定されうる参照が一つ（卒業した申し送り）。三つとも**エラーを出さない壊れ方**の側にある。

### Fixed

- **ポーリング窓の不変条件が最悪滞留を過小に見積もっていた（SIGTERM の実因）**——窓の既定値 540s は「1 サイクルの最悪滞留 = long-poll の `--timeout`（30s）」という前提の上に立っていたが、実際に窓を越えさせるのは HTTP 層の再試行予算のほうだった。`watch` は最終サイクルの long-poll を残り窓へ丸めるが（`main.py` の `poll_timeout`）、**丸まるのは long-poll の引数だけ**で、その内側の `api_gateway`（`retry_count=2` / `request_timeout=40.0`、**5xx は sleep せず即再試行**＝待ちではなく試行回数が時間を食う）は窓を知らない。ゆえに最悪滞留は 30s ではなく `(2+1) × 40 = 120s` で、`540 + 120 = 660 > 600` と破れる。平常時は 5xx が出ないので `540 + 30 = 570 < 600` が成立して見えていた——**障害時にだけ露出する条件**であり、常駐運用で 5xx が続いた枠が exit 143（SIGTERM）で落ちて発覚した。**窓の既定値を 540 → 450 に下げた**（`450 + 3×40 + 30(後処理余裕) = 600`）
- **同じ腐りをコメントで止めない**——窓（`bootstrap.sh`）と再試行予算（`api_gateway`）は別ファイルに住んで互いを知らないので、不変条件を注釈に書いても片方だけ動かせば静かに破れる（現に破れた）。`test_poll_window_invariant.py` が**両方の実値を突合**し、片側を動かしたら赤になるようにした

### Changed

- **DESIGN §3.7 に WAL の守備範囲を明記**——`reconcile` / `settle` の判定は `(kind, key)` の存在だけで payload を見ないため、**既存レコードの内容更新（例: 既にある tasks の `notes` 追記）は WAL では守れない**。intent を積んでも key は既に在るので redo されず、それどころか `settle` が done 化して**反映されていないのに反映済みに見える**（偽陽性）。WAL が塞ぐのは「約束したレコードが無い」穴だけで、「約束した内容が入っていない」穴は順序（送信と記録を同じ手順の内側で連続させる）でしか塞げない
- **DESIGN §3.12・SKILL に「卒業後の参照は二箇所で解決する」を明記**——申し送りへの参照はファイル名だけでディレクトリ成分を持たず、`handoff-archive` は名前を変えずに場所だけを動かす。ゆえに卒業後の解決先は「直下 → `archive/`」の二箇所であり、**直下に無い＝失われた、ではない**
- **ROUTINE_PROMPT の不変条件の記述を実際の式へ改めた**（`max_duration + (retry_count+1) × request_timeout + 後処理余裕 <= bash_timeout/1000`）

### 移行（稼働中の routine への波及）

1. **窓の是正は body 再登録を要さない**——登録済み body は `$SHIORI_POLL_SET_SEC` を参照するだけで、値は `bootstrap.sh` が持つ。routine が毎枠 fresh clone する構成なら、**更新を反映した次の枠から 450 で起動する**。Routine の Environment で `SHIORI_POLL_SET_SEC` を明示注入している場合はそちらが勝つので、注入していないことを確認する
2. SKILL.md も毎枠読まれるため、卒業後の参照規律は同じ経路で届く。**ROUTINE_PROMPT の記述だけは body 再登録が要る**（式の説明であって値ではないので、次のまとめた再登録で足りる）
3. 副作用: 窓が縮む分アイドル枠のポーリング回数が増える（4h 枠で 26 → 32、`MAX_TURNS` は算出式に窓が入るので自動追従）

## [1.10.2] - 2026-08-12 — 起動手順が実在しないパスを指していた（Step 1 の SKILL.md）

### Fixed

- **ROUTINE_PROMPT Step 1 の参照先が実在しなかった**——`<INSTALL_DIR>/SKILL.md` と書かれていたが、SKILL.md はプラグイン構造上 `skills/shiori-secretary/SKILL.md` にあり、**リポ直下には一度も存在したことがない**。秘書は起動のたびに Step 1 の Read に失敗し、Subcommands / Failure Modes / env vars を仕様書から把握しないまま Step 2 へ進んでいた。**読めなくても手順は止まらない**ため、この失敗は観測されないまま残り続けた（DESIGN §3.12 が扱う沈黙失敗と同型で、こちらは手順書側に出たもの）。英語版は `skills/shiori-secretary/SKILL_en.md` を指すよう揃えた（README_en と同じ流儀）

### 移行（稼働中の routine には再登録が必要）

1. **登録済みの cloud routine body には旧パスが焼かれている**——本ファイルを直しただけでは稼働中の routine に届かない。`/shiori-secretary` の `schedule`（upsert）で body を再登録する（手順は [ROUTINE_PROMPT.md](./ROUTINE_PROMPT.md) の「cloud routine ライフサイクル管理」節）
2. 再登録しない場合も**従来どおり動く**——Step 1 が失敗するだけで手順は進む。ただし秘書は仕様書を読まないまま稼働し続ける（Subcommands の把握が起動時オリエンテーションと実地の記憶頼りになる）

## [1.10.1] - 2026-08-11 — 母体との同期漏れ回収と、検査の穴の補修

機能変更なし。母体 TelegramSecretary との二重管理で**片側にしか入っていなかった修正**を双方向に
回収し、テストの網とドキュメントの階層を整えた。

### Fixed

- **`FfmpegAudioPreprocessor.to_float_pcm` の docstring が実装と矛盾していた**——「音声ストリームなし/デコード失敗時は空配列を返す（クラッシュしない）」と書かれていたが、実装は v1.3.1 以降 `AudioDecodeError` を送出する（無音と読み取り失敗を取り違えないため）。**読んで実装を誤解する側の誤り**で、記述を実装（Raises 節）へ揃えた
- **DESIGN §3.5 の digest 絞り表が v1.10.0 に追従していなかった**——`GOALS / STEPS` が「絞りなし」のままで、同じ文書の §3.12 の 8 行表と矛盾していた。表と処方の対応は §3.12 が SSoT である旨も明記

### Added

- **配線と失敗経路のテスト 13 本**——`build_git` / `build_sync`（registry と WAL が共有する DI）、PDF renderer 未導入時のフォールバック、音声デコードが途中で壊れた場合（一片も取れなければ raise・部分的に取れていれば返す・flush 失敗でも取得済みを捨てない）、`Retry-After: 0` と負値、通信エラーからの回復、WAL 書き込み口の入力不正 3 種。カバレッジ 96% → **97%**（`composition` / `http_retry` / `ffmpeg_preprocessor` は 100%）
- **CI に bandit のセキュリティスキャンを追加**——母体側の CI には元からあり、本リポだけ欠けていた。検査範囲は配布する Python 全体（`scripts/` ＋同梱スキル `skills/`）で、ruff を `.` に掛けているのと同じ理由——配布物なのに検査されない層を作らない

### Changed

- **DESIGN に目次を追加し、§3.8 の階層を正した**——abilities（4 表目）の節の配下に subjects（8 表目）がぶら下がっていたのを、両表を並べる節へ改めた（§3.8 という番号は他文書からの参照ごと維持）

## [1.10.0] - 2026-08-11 — 蓋の無い表を残さない（subjects / steps の索引化・goals の cap）

v1.9.0 は蓋の無い側から 3 表（individuals / abilities / profile）を可動域に入れたが、**subjects /
goals / steps の 3 表には処方が無いまま**残っていた。処方の無い表は、育つまで無害に見えて、育った枠で
沈黙失敗（データがコンテキストに載らないまま exit 0）を再発させる側になる。本版の目標は目先のサイズ削減
ではなく **「8 表すべてに処方があり、digest のサイズが構造的に有界」**な状態で、これは goals / steps を
蓋なしで残したままでは証明されない。処方は表の性質で決まる——**1 レコードが長い表には cap、レコード数が
増える表には索引または件数絞り**。表と処方の対応は **DESIGN §3.12 の 8 行表が SSoT**。

### Added

- **`orientation --goals-cap N`** — goals の `notes` をバイト上限で丸める（`--profile-cap` / `--abilities-cap` と同型、`_CAP_FIELDS` へ 1 行）。既定は未指定＝全文、見出しに `full, notes cap N bytes` として開示。goals は**件数が少なく本文が長い**側なので処方は cap
- **`orientation --steps-latest N`** — steps 索引を新しい順 N 件に絞る（`--tasks-latest` と同型、`pick_latest_by_id` を再利用）。既定は未指定＝全件、見出しは `latest N of M, newest last`。**0 は「全捨て」**で未指定へ逆転しない（判定は `is not None`、既存 cap ノブと同じ規約）

### Changed

- **subjects の索引化（全文 JSON → `id | label | aliases | status | note` の一行索引）** — 語彙は `subjects add` で育つ＝**件数が増える表**なので、処方は cap ではなく索引にした（cap は 1 レコードの長さにしか効かない）。全文 JSON は `created_at` / `updated_at` という**この用途で価値ゼロの数十バイト**を毎レコード運んでいた。**件数絞りは付けない**——この表は「どの主題で knowledge を引くか」を選ぶ一覧なので母数を減らすと選べない語が出る。絞るのは行あたりの重さだけで、丸まるのは `note` 列（幅は `knowledge` の `topic` 列の既定 `DEFAULT_TOPIC_WIDTH` に揃えた＝**新しい数値を発明していない**）。`aliases` は `/` 連結・空は `-`（列が消えると桁がずれて誤読する、`index_knowledge` と同じ流儀）
- **steps の索引化（全文 JSON → `id | goal_id | seq | status | title` の一行索引）** — 目標からの逆算単位ゆえ**設計上 `done` が高速に溜まる**＝件数が増える表で、処方は tasks と同じ「一行＋件数絞り」。`notes` は載らない（読み筋は `steps get --key`）。**選ぶのは新しい順・並べるのは id 昇順**の捻れの解き方も tasks / knowledge と同じ（`newest last` は絞ったときだけ載せる）
- **既定出力の変更（破壊的変更ではない）** — subjects / steps の 2 セクションの描画が変わる（v1.9.0 の索引 3 列化と同じ扱いの**仕様変更**）。**他 6 セクションは byte 同一**を退行テストで固定してある——この錠は production 変更**前**に書いて green を確認した。スキーマ・データ・exit code 契約には一切触れていない（索引化も cap も表示だけの操作）
- **接点文書の追従** — `README.md` / `skills/shiori-secretary/SKILL.md`（orientation オプション表へ 2 種）、`DESIGN.md` §3.12（**表の性質→処方の 8 行表を SSoT として追加**・有界式・「絞れない床」の現況＝床に残るのは cap 側 4 表と tasks 一行要約）、`ROUTINE_PROMPT.md`（オプション列挙・表別の読み筋——**「小表の全文」の列挙が索引化で嘘になっていた**ので、cap 側 4 表〔individuals / abilities / profile / goals〕と索引側〔subjects / steps〕へ書き分けた）、`STRUCTURE.md`（`orientation.py` の射影内容）。日英とも同期

### 移行（破壊的変更ではないが読み方が変わる）

1. **subjects / steps を全文前提で読んでいた運用は読み替える** — 索引の行に載らない項目（subjects の `created_at` / `updated_at`、steps の `notes`）は `subjects get --key` / `steps get --key` で引く。**データは何も失われていない**——落ちたのは描画であって記録ではない
2. **`--steps-latest` で絞った枠は母数を見出しで確かめる** — `latest N of M` の M が全件数を開示するので、絞りで落ちた分の存在は画面から消えない
3. **自環境での校正は v1.9.0 で敷いた四段手順に従う**（測る → 単一ノブで効きを知る → 併用 → 再測定）——手順の SSoT は `ROUTINE_PROMPT.md` の該当節で、本版はそこへ新ノブ 2 種を合流させただけ。**どの値まで絞るかは自分のデータの実測から決める**（registry の中身は運用主体ごとに違うので、他所で効いた値はあなたの正解ではない）
4. **稼働中の cloud routine を持つ場合は prompt body の再登録が必要** — 既存 routine の body は登録時 snapshot ゆえ、ROUTINE_PROMPT の変更（新オプションの案内・subjects / steps の読み筋）はリポ更新だけでは本番へ届かない。**再登録しなくても壊れない**（新ノブは未指定＝全文・全件で、旧 body の呼び出しはそのまま動く）——届かないのは案内だけである

### Notes

- **`cc-defer` を 1 つも積んでいない** — 本版の目標が「蓋の無い表を残さない」である以上、蓋の無い表を台帳に積んで先送りすると目標そのものが未達になる
- **母体（TelegramSecretary）の採用値は配らない** — 配布版は「値でなく校正方法を配る」（v1.9.0 で確立した配布三則(1)）。同じ機構に対し、母体は実測値を prompt body へ焼き、配布版は既定（蓋なし）のまま四段手順を配る——扱いが非対称なのは仕様である

## [1.9.0] - 2026-08-11 — 主題の軸（8 表目）・蓋の無い表への上限ノブ・書き込み口の fail-closed

v1.8.0 は測る装置（stderr のサイズ申告）を置いたが、**絞れるのは knowledge 索引・notes 末尾・
handoff 本文の 3 項だけ**で、小表の全文と tasks の一行要約——「絞れない床」——には手が届かなかった。
もう一つ、knowledge を引く軸が `category`（認識の型）しか無く、**主題（経理・顧客…）で引く経路が無い**。
v1.8.0 はこれを `topic` の接頭辞規約（`[主題] 本文`）で代用しようとしたが、規約は**強制されないぶん揺れる**。
本版は二本柱で入れる：**蓋の無い表への上限ノブ**（床を可動域へ）と **主題の語彙表 SUBJECTS**（8 表目）。
主題軸は digest を太らせる（subjects 表の全文掲載＋索引の主題列）ので、**上限ノブは主題軸の前提条件**である。

### ⚠️ 破壊的変更（アップグレード前に必読）

**書き込み口（`add` / `import`）が、トップレベルの未知フィールドを exit 2 で弾く（fail-closed）。**
従来 `from_dict` は既知キーだけを転記していたため、typo（`subjects` → `subject`）は**例外にならず
沈黙して消えていた**——「登録したのに無い」を後から探させる形である。本版はキー名を stderr に出して
（`unknown field(s): subject`）その場で落とす。**未知キー付きの `add` を行っていた運用は落ちる**
（落ちること自体が目的）。検証は**書き込み口のみ**で、read 経路（`list` / `get` / `orientation`）は
前方互換のため警告どまりに留める——read に同じ検証を入れると、未知キーを 1 つ持つレコードがあるだけで
`list` が全滅する。

**移行手順（アップグレード前後に実施）**:

1. **SUBJECTS 表（8 表目）を立てる** — 8 表目のファイルは**無くても落ちない**（存在しない表は空配列として
   読まれ、`orientation` の subjects セクションが `[]` で出るだけ）。最初の `subjects add` が
   `<registry_dir>/subjects/SUBJECTS.json` をディレクトリごと作るので、通常は追加作業が要らない:

   ```bash
   python scripts/main.py subjects add --json '{"id": "経理", "label": "経理", "aliases": [], "status": "active", "note": "請求・支払・決算まわり", "created_at": "2026-08-11T00:00:00Z", "updated_at": "2026-08-11T00:00:00Z"}'
   ```

   雛型の書式（`_record_schema` / `_growth_policy`）を先に手元へ置きたい場合は
   `templates/SUBJECTS.template.json` を `<registry_dir>/subjects/SUBJECTS.json` へ複製してもよい。
   いずれの経路でも語彙は空から始めて `subjects add` で育てる（**増やすより育てる**——扱う領域は
   運用主体ごとに違うので、初期語彙は同梱しない）。`registry_sync` 有効時は `add` が commit&push に乗る
2. **未知フィールド付きのレコードが無いか確かめる** — 手書きや旧スクリプトで登録した表がある場合、
   最初の `add` / `import` が exit 2 で落ちる。stderr のキー名を見て、typo なら正しいキーへ直し、
   不要なキーなら削る（read 経路は落ちないので、`list` で現物を確認してから直せる）
3. **topic 接頭辞規約（`[主題] 本文`）から subjects へ移る** — v1.8.0 Notes が提案した接頭辞規約は
   **本版で廃止**した。既存 topic の接頭辞は壊れないのでそのままでも読めるが、絞りに効かせるには
   `subjects add` で語彙を立て、`knowledge add`（新規）または `import --json-file`（既存の一括書き戻し）で
   `subjects[]` に移す。**一括変換スクリプトは配っていない**——どの主題に属するかは判断であって変換ではない
   （v1.8.0 の category 移行と同じ理由）
4. **稼働中の cloud routine は prompt body の再登録が必要** — 既存 routine の body は登録時 snapshot ゆえ、
   ROUTINE_PROMPT Step 5 の変更（新オプション・subjects の読み筋・8 表化）はリポ修正だけでは本番へ届かない

### Added

- **`SUBJECTS` 管理表（8 表目）** — 主題の語彙表（`id`＝正準 slug / `label` / `aliases[]` / `status` ∈ {active, deprecated} / `note` / `created_at` / `updated_at`）。**閉じた語彙はコード、開いた語彙はデータ**——`category` が frozenset のままなのに対し、主題は管理表に置く（主題を 1 つ増やすたびに再デプロイを要求しないため。DESIGN §3.8）。`status=deprecated` は削除ではなく廃止で、既存レコードの読み出しを壊さず新規付与だけを止める。**配線コストは `REGISTRY_SPEC` の 1 行＋`Config.subjects_path` だけ**で、CRUD・WAL kind・orientation の表順・subparser がすべて自動追従した（§3.8 が abilities で主張したテーブル駆動の実証）
- **`knowledge.subjects[]`（主題の付与）** — `category` と直交する軸。値は SUBJECTS 表の **active な id** と照合し、語彙外・deprecated は**候補列挙付き exit 2**（v1.8.0 の category 検証と同じ UX）。空配列・省略は可（後方互換）。照合の判定は Domain 純関数 `invalid_subjects(subjects, active_ids)`、データ供給は Interface——依存は内向きのまま、判定は引数だけでテストできる
- **`orientation --knowledge-subject <id>`** — 索引を subjects の要素一致で絞る（`--knowledge-category` の同型。母数は見出しの `N of M` に残り、該当 0 件でも exit 0＝絞りは観測であって検証ではない）。絞りの順は **category → subject → latest**（latest を先に効かせると「新しい N 件に該当主題が無ければ 0 件」になり絞りの意味が壊れる）
- **`orientation` の上限ノブ 4 種** — `--profile-cap` / `--individuals-cap` / `--abilities-cap`（各表の**支配的長文フィールド**＝ `content` / `identity.context_notes` / `guidance` のバイト上限）と `--tasks-latest`（一行要約の件数上限、notes も連動）。丸めは既存 `_truncate` の再利用（バイト・文字境界・マーカーは幅の内側・非正は全捨て）で**新しい丸め処理を書いていない**。レコード全体の JSON を丸めず 1 フィールドだけに当てるのは、構造を壊さず「丸めても個票は `get --key` で引ける」読み筋を温存するため。**既定（未指定）は全文・全件＝非破壊**で、見出しに `full, <field path> cap N bytes` として開示する。goals / steps にはノブを付けていない（肥大トリガーで同型追加）
- **`<表> import --json-file`（全件置換の正面口）** — 全 8 表に生える（`REGISTRY_SPEC` 駆動）。**全件検証 → 一括置換**で、1 件でも不正なら exit 2・**無置換**（部分書き込みを作らない）。batch 内のキー重複も exit 2 で弾く——`replace_all` は upsert と違い一意性を畳まないため、通すと「`get` は先頭だけ返し `remove` は両方消す」表ができる。stderr に `imported knowledge: N -> M records (added: …, removed: …)` の差分。置換後の sync は 1 commit（表は 1 ファイル）
- **`templates/SUBJECTS.template.json`** — 8 表目のみ雛型欠落は構成の非対称。`records` は他表の規約どおり空配列で、例示語（経理・顧客・健康）は `_record_schema` に置く（実データ投入は秘書の領分）

### Changed

- **knowledge 索引の 3 列化（`id | topic` → `id | subjects | topic`）** — 主題は `/` 連結、未設定は `-`（列が消えると読み手が桁をずらして誤読する——`summarize_task` の due_date と同じ理由）。**併記列は topic_width の外側**に置く（主題を足したせいで topic の丸め幅が縮むと、索引の読める量が主題の付き方で揺れる）。これにより**既定出力の byte 同一契約は索引行 1 箇所だけ意図的に破れている**（裁可済みの仕様変更）
- **topic 接頭辞規約（`[主題] 本文`）の廃止** — v1.8.0 が Notes に置いた規約を撤回し、`SKILL.md` / `templates/KNOWLEDGE.template.json` から本文ごと削除して subjects 案内へ置換した。規約は**強制されないぶん揺れる**（付け忘れ・表記ゆれ・遡及付与の未完了が混在しても誰も気づかない）——検証できない規約より、書き込み口で弾けるデータ構造を採る。**過去の節（v1.8.0 以前）は歴史記録ゆえ書き換えていない**
- **`test_templates` の対象拡張** — 従来は PROFILE / GOALS / STEPS の 3 雛型のみを `_record_schema` ↔ `to_dict()` のキー集合一致で検証しており、**未カバーの表は乖離しても誰も気づかなかった**。雛型を持つ 8 表すべてを対象にしたところ、予告どおり **KNOWLEDGE 雛型の既存乖離（`subjects` 未記載）が露見**したので雛型側を値オブジェクトに揃えた（スキーマの正は VO）。表が増えたらここへ 1 行足す
- **接点文書の追従** — `README.md`（8 表・orientation 全オプション）、`DESIGN.md`（§3.1 8 表化 / §3.5 digest 側の上限ノブ表 / §3.8「なぜ subjects を 8 表目に」＋書き込み口だけを fail-closed にする理由 / §3.10 表数 / §3.12 有界式・主題絞り・床の再計算）、`ROUTINE_PROMPT.md`（Step 5 の表別読み筋に subjects 行と索引 3 列・新ノブ 4 種・8 表・wal-append kind）、`skills/shiori-secretary/SKILL.md`、`commands/shiori-secretary.md`、`STRUCTURE.md`、`SECURITY.md`、`SETUP.md`、`templates/{KNOWLEDGE,SUBJECTS,SecretaryRole}`、`bootstrap.sh`——いずれも日英同期

### Notes

- **新ノブの既定はすべて蓋なし（全文・全件）** — 本版は絞る手段を増やしただけで、既定出力の量は増減しない（索引の主題列と subjects 表の分だけ増える）。**絞る値は自分のデータで校正する**——v1.8.0 で敷いた計器（毎枠 stderr の `orientation digest: N bytes`）と、その値が閾値を超えたら絞るという手順に、新ノブがそのまま乗る（ROUTINE_PROMPT Step 5）。**主題軸を運用すると digest は太る**ので、主題を付け始めた枠のサイズ申告は見ておく
- **語彙は空から始まる** — 配布 `SUBJECTS.template.json` は `records` 空配列で、初期語彙を同梱しない（扱う領域は運用主体ごとに違う）。語彙追加の目安「10 件以上たまったら整理を考える」は**仮置き**（運用実績が無い時点で置いた数字）で、校正の一次資料は自分の運用実測になる
- **`bootstrap.sh` の registry 既知エントリ列挙**に `subjects` を足した（未追加だと subjects/ を持つ registry で再 provisioning が常に warn+skip される）。profile / goals / steps / artifacts が元々未列挙な既存不整合は本版のスコープ外——安全側（削除しない側）に倒れる不整合ゆえ `cc-defer` で台帳化し、昇格トリガーを添えてある

## [1.8.0] - 2026-08-10 — 許可集合の検証・サイズの自己申告・幅の校正手順

v1.7.0 は幅の**単位**を是正したが、その値が実データで足りているかは**誰も測っていなかった**。
母体運用の実測では、既定の orientation が 72,724 バイト・幅を絞った呼び出しでも 45,802 バイトで、
いずれも退避される圏にいた——見積りが外れていたことに気づけなかったのは、出力サイズが
観測面に出ていなかったからである。本版は (1) 弾くべき値を Domain で弾き、(2) サイズを毎枠
stderr で申告させ、(3) その計器で幅を実測から決める手順を配る、の 3 点を入れる——
**測る装置を先に置いてから校正する**。

### ⚠️ 破壊的変更（アップグレード前に必読）

**knowledge の `category` が許可集合 10 種に閉じ、検証が読み取り経路でも発火する。**
範囲外の category を持つレコードが 1 件でもあると、`knowledge list` / `orientation` が
**丸ごと exit 2 で落ちる**（値オブジェクトの `__post_init__` 検証ゆえ、読み出しでも発火する）。
とくに **v1.7.0 までの `templates/KNOWLEDGE.template.json` が例示していた
`projects` / `clients` / `procedures` は 3 つとも許可集合の外**——テンプレートに沿って
運用していた場合はほぼ確実に該当する。

**移行手順（アップグレード前に実施）**:

1. 現行の category を数える（registry の実体 `<registry_dir>/knowledge/KNOWLEDGE.json`）:

   ```bash
   python -c "import json,collections,sys; print(collections.Counter(r['category'] for r in json.load(open(sys.argv[1],encoding='utf-8'))['records']))" <registry_dir>/knowledge/KNOWLEDGE.json
   ```

2. 許可集合の外にある値を、10 種のいずれかへ**手で読み替えて**書き換える（機械的な一括置換は
   意味の対応が壊れるため配っていない——分類のやり直しは判断であって変換ではない）。
   目安: 作業の一般則→`method` ／ 対象ドメインの知見→`domain-insight` ／ 器やツールの運用→`harness` ／
   観察の記録→`observation` ／ 調べもの→`research` ／ データの分析結果→`analysis` ／
   設計判断→`design` ／ 方針・原則→`philosophy` ／ 商売の勘所→`business` ／ 決めごと→`decision`
3. 書き換え後に `orientation` が exit 0 で通ることを確認してからアップグレードする

主題（案件・顧客 等）の軸を category に載せていた場合は、`topic` の接頭辞 `[主題] 本文`
（例 `[経理] 月次締めの手順`）へ移す——**category は認識の型の軸専用**で、二軸を混ぜない。

### Added

- **knowledge `category` の許可集合検証（Domain）** — `observation` / `research` / `harness` / `domain-insight` / `analysis` / `design` / `method` / `philosophy` / `business` / `decision` の 10 種のみ通す。**エラーメッセージは許可集合を列挙する**——Identity / Goal（invalid 値のみ）との非対称は意図的で、弾かれる主体が自走エージェントである以上、エラー文だけで正しい語を選び直せる情報量が要る
- **orientation 出力サイズの自己申告（Interface）** — 実行のたび stderr へ `orientation digest: N bytes` を**常時 1 行**。`ORIENTATION_WARNING_BYTES = 25 * 1024` 超では、退避の可能性と絞り 4 オプションの名指しを添える。閾値は**仮置き**（母体運用の実測境界 25〜39KB 圏の安全側下限、`cc-defer` で校正待ちを明示）。`_warn_if_oversized`（list の 200KB 警告）と違い**閾値未満でも黙らない**——安全側で黙る計器は「exit 0 なのに digest が載っていない」を観測させないまま通す。stdout は byte 不変・exit code も不変（fail-open）

### Changed

- **`Knowledge.from_dict` の `category` 必須化（後方非互換）** — 旧実装は `d.get("category", "general")` で欠落を黙って `"general"` に化けさせていた（許可集合に無い値を**沈黙生成する fail-open**）。`d["category"]` へ改め、**category を欠いた `knowledge add` は exit 2 になる**。落ちること自体が目的で、沈黙の `"general"` 生成こそが分類の増殖と綴り揺れの温床だった
- **`templates/KNOWLEDGE.template.json` の category 記述** — 旧記述の例示（`projects` / `clients` / `procedures`）は**いずれも許可集合の外**で、そのまま従うと add が exit 2 になる。許可集合 10 種の列挙と「主題の軸は topic 接頭辞で持つ」に差し替えた
- **ROUTINE_PROMPT Step 5 に幅の校正手順** — 呼び出し自体は**素の既定のまま**（新規インストールは絞る必要がない）。そのうえで「警告が出たら絞る」順序と、母体 registry での実測（**単一ノブでは目標に届かず**——最も効く `--knowledge-latest 30` 単独でも 45,802 バイト、4 項同時で 24,152 バイト）を worked example として載せた。**この 4 値は母体のデータに対する実測であって、利用者のデータの正解ではない**——自分の枠の `orientation digest: N bytes` を見て決める
- **接点文書の追従** — `skills/shiori-secretary/SKILL.md`（category 制約と topic 接頭辞規約・stderr 申告）、`DESIGN.md` §3.12（サイズ自己申告・絞れない床・許可集合を読み取り経路で弾く理由）、`README.md`（オプション表）——いずれも日英同期

### Notes

- **topic 接頭辞規約（コード変更ゼロ）** — knowledge の主題軸は `topic` を `[主題] 本文` の形にして持てる。category は**認識の型**の軸専用に保ち、二軸を混ぜない。**規約であって強制ではない**——コードもデータも接頭辞を要求せず、運用開始と既存 topic への遡及付与は秘書の裁量。`tags` スキーマ拡張は絞り実装まで要求し始めるため、接頭辞で効かなかったときの昇格先として温存する
- **絞れない床** — 全ノブを最小に振っても残る部分（小表全文＋tasks 一行要約）は母体実測で 11,629 バイト＝目標の 45%。将来 goals / steps が埋まれば床はさらに上がるため、そのときは小表側にも射影が要る（DESIGN §3.12）
- **既存ユーザーの routine body は登録時 snapshot** — ROUTINE_PROMPT の変更を反映するには routine の再登録が要る

## [1.7.0] - 2026-08-09 — orientation を現場データへ噛み合わせる（幅のバイト単位化・件数絞り）

v1.5.0 で入れた有界射影は、**幅を字数で数えていた**。退避の閾値はバイトなので、
日本語主体のデータでは 1 字≈2.47 バイトの分だけ実効幅が膨らみ、既定のまま
99,037 バイトを出して沈黙失敗が再発した。**数値は動かさず単位だけを是正する**。

### Added

- **`orientation --knowledge-latest N`** — knowledge 索引を**新しい順 N 件**に頭打ちにする（id は日付順に振られるため id の大きい方が新しい）。見出しは `latest N of M, newest last`——**選ぶのは新しい順、並べるのは id 昇順のまま**（索引の読み方は変えず母数だけ減らす）で、この捻れは並べ替えではなく**読み方の開示**で解く。`--knowledge-category` と併用すると**絞ってから latest**。既定は未指定＝全件（後方互換・見出しも不変）

### Changed

- **幅の単位を UTF-8 バイトへ是正（`--notes-tail` / `--topic-width` / `--handoff-cap`）** — 退避の閾値と同じ単位で数える。**数値は不変のまま単位だけを是正**——v1.5.0 の校正意図（notes 末尾に 3,000–4,000 字の申し送りが堆積する／topic は識別可能な幅で足りる）は「1 字＝1 バイト」の世界の見積りゆえ、バイトとして読み直せばそのまま生きる。丸めは**文字境界**で止め（サロゲート・結合文字を割らない）、切り取りマーカー `…`（3 バイト）は幅の**内側**に置く。`--handoff-latest` は件数ゆえ単位是正の外
- **`0` を有効な端点として受け付ける** — `--notes-tail 0` / `--handoff-latest 0` 等で当該項を落とせる（旧実装は `or DEFAULT` の記法で 0 を未指定に潰していた＝**指定したのに効かない**沈黙。`is None` 判定へ是正）

### Notes

- 幅オプションを指定しない既定出力は、日本語データでは v1.5.0 より**狭くなる**（字→バイト）。これは是正であって退行ではない——旧挙動は閾値と違う単位で数えていた

## [1.6.0] - 2026-08-09 — 申し送りのブロック化 第二段（archive 契約・卒業・消化）と内部正規化

第一段（v1.5.0）は申し送りを枠ごとのブロックに分離して「読む量」を切ったが、
**母数は増え続ける**——ブロックは溜まる一方で、消化（再利用価値ある対応知の
knowledge への結晶化）と卒業（読み筋から外す）のサイクルが無かった。加えて
「`handoff/archive/` は orientation が読まない」は実装の副作用（`glob("*.md")` の
非再帰）に留まり、再帰読みへの改修一つで静かに壊れる暗黙挙動だった。
**契約をテストで固定し、その上に卒業と消化を最小コードで載せる。**

### Added

- **`handoff-archive <name>...` サブコマンド** — 消化を終えた申し送りブロックを `handoff/archive/` へ移し、既存 `artifacts-sync` 経路で commit & push（新規 git コードなし。git は rename として拾う＝履歴が切れない）。**全件検証→全件移動**で部分成功を作らない——パス成分を含む名前（traversal）・不在・archive 側の同名既存は何も移動せず exit 2。**一括掃除（`--before <date>` 等）は持たない**：消化を経ない機械的 archive は原トレースの意図しない退場を招くため、卒業は常に秘書の消化判断を受ける指名制
- **`orientation --knowledge-category <cat>`** — knowledge 索引を category 完全一致で絞る。見出しは `knowledge (N of M records, category=<cat>, index: id | topic)`——**絞って落ちた M−N 件が `of M` に残る**（サイレントに減らさない）。該当 0 件でも exit 0（絞りは観測であって検証ではない）。未指定時の出力は v1.5.0 と byte 同一
- **消化ワークフローの手順化（ROUTINE_PROMPT 手順 11）** — 自由時間（autonomous turn）の候補に「未消化 handoff を読み返し、再利用価値ある対応知を knowledge へ結晶化 → 結晶化済みブロックを `handoff-archive` で卒業」を追加（既存の actionability ゲート配下、1 ターンで扱える件数だけ）。**何を結晶化し何を卒業させるかの選択は秘書の判断に残す**——コードが持つのは移動と読み筋だけ

### Changed

- **archive 契約の昇格（暗黙の実装挙動 → テスト済みの契約）** — 「orientation は `handoff/` **直下の `*.md` だけ**を読む（サブディレクトリ・非 .md は読まない）」を退行テストで固定した。卒業の受け皿はこの非再帰読みが作る「読み筋の外」であり、文書だけの約束にしない。DESIGN §3.12（起動時オリエンテーション SSoT）に契約・卒業・カテゴリ絞りを追記
- **`Config.artifacts_path` へパス解決を一元化** — `registry_cli` の局所導出を解消（`*_path` プロパティ群と同型）
- **handoff 読み取りの有界化** — 全ブロックを open してから選ぶのをやめ、名前降順の上位 `--handoff-latest` 件だけを open する（**出力不変**、ブロックが溜まっても読み込み I/O が比例して増えない）

### Notes

- 全変更が後方互換の**追加**（オプション・サブコマンド・プロパティ）。orientation の既定出力は v1.5.0 と byte 同一であることをスナップショットテストで固定してある
- 卒業したブロックは**消えない**（`handoff/archive/` に残り、git 履歴にも残る）。読む量を切るのが目的で、append-only 台帳の不可侵性は保つ
- 手順 11 / 14 を変更したため、本番へ届けるには **cloud routine の body 再登録が必要**（リポ修正だけでは到達しない）

## [1.5.0] - 2026-08-09 — 起動時オリエンテーションの沈黙失敗対策（orientation）と申し送りのブロック化（第一段）

肥大した registry を起動時に読もうとすると、出力がハーネスの上限を超えて退避され、
**データがコンテキストに載らないまま exit 0 する**——読めていないのに読めたつもりで
起動する沈黙失敗が 17 枠にわたり再発した（実測 1.6MB: knowledge 943KB/187 件、
tasks 741KB/8 件、支配項は 1 レコードの notes 165K 字）。7表を並べた `list` を
絞り込みダイジェストに置き換え、線形に堆積する申し送りをブロックへ分離する。

### Added

- **`orientation` サブコマンド** — role 判定・7表の件数/バイト数・小表（individuals/abilities/profile/goals/steps）全文・tasks の一行要約と active タスクの notes 末尾・knowledge の `id | topic` 索引・handoff 最新ブロックを 1 コマンドで出す read-only 射影。**出力量が notes 総長・knowledge content 総量に依存せず有界**（レコードが太っても出力は太らない）。幅は `--notes-tail`（既定 4000）/ `--topic-width`（既定 120）/ `--handoff-latest`（既定 3）/ `--handoff-cap`（既定 8000）で調節可
- **申し送りの handoff ブロック（第一段）** — 書き先を tasks の `notes` 追記から `<registry_dir>/artifacts/handoff/<UTC日時>_<session_id>.md` へ移した。**セッション枠がそのままブロック境界**になり、命名の辞書順降順で新しい順に読める。スキーマも CRUD も持たない（置き場と命名だけを標準化＝DESIGN §3.10 の境界を侵さない）
- **`artifacts-sync` サブコマンド** — 成果物層 `artifacts/` を既存 sync 経路で commit & push（新規 git コードを書かない）。書き込み CLI は持たず、秘書の `Write` → `artifacts-sync` の二手
- **`list` の 200KB 超警告** — 単表 `list` の出力が 200KB を超えると stderr に一行警告（stdout・exit 0 は不変＝fail-open）。「沈黙」を「声」に変えるだけで、既存経路を退行させない
- **`bootstrap.sh` の起動時案内** — `ready` の直前に `orientation` を名指しする一行。**手順 X の失敗を防ぐ知識は X より上流に置く**（データ層に書いても、それを読むステップ自体が失敗するため効かない）

### Changed

- **ROUTINE_PROMPT Step 5 / SKILL.md Daily Workflow** — 7表を並べた `list` の手順を `orientation` 一撃＋個別 `get --key` へ置換し、「7表合計でも数千トークン規模」の楽観記述を削除。沈黙失敗の機序を why として明記した（誘導源の根絶）
- **`DESIGN.md` に §3.12 を新設（起動時オリエンテーションの SSoT）** — 沈黙失敗の機序・上流配置の原則・出力の有界性・handoff のブロック境界。他文書は要約＋ポインタに統一。§3.10 には「規約付き用途を置いてよい範囲」を追記
- **`SECURITY.md` §7** — handoff の PII 範囲は WAL と同型（Private 分離・commit 先は同一）。ただし自由記述ゆえ出力漏洩スキャン規律を書き込みにも適用する旨を明記

### Notes

- **既存の notes は書き換えない**（append-only 台帳の不可侵）。`orientation` は legacy な堆積も読み続ける（active タスクのみ・末尾 `notes_tail` 字）ため、移行は既存データを壊さず tail が縮む一方の可逆な形になる
- 申し送りの**消化（knowledge 結晶化）と卒業（archive）は次段**——本版の天井は分離のみで、昇格トリガー（orientation 実測 100KB 超）は `registry_cli._read_handoff_blocks` に `cc-defer` として刻んである
- `handoff_latest=3` / `handoff_cap=8000` は実測からの外挿による**仮置き**（次枠の実測で校正する）。`notes_tail=4000` / `topic_width=120` / 警告閾値 200KB は運用実測由来
- 登録済み routine の body は登録時 snapshot のため、Step 5 の置換を本番へ届けるには **body の再登録が必要**（リポ修正だけでは到達しない）

## [1.4.3] - 2026-08-02 — registry 書込の詰まり対策と watch 中断の復帰手順

母体 TelegramSecretary の実運用で観測された 2 事象の恒久対処を、同一コードベースの本リポへ波及させる。挙動を止める向きの変更は無い。

### Fixed

- **registry worktree へ `__pycache__/` の clone ローカル ignore を播種（`bootstrap.sh`）** — registry ブランチが誤って `.pyc` を追跡している状態で artifacts のスクリプトを実行すると、再コンパイル差分が unstaged で残り、push 競合時の `pull --rebase` リカバリを塞いで registry 書込が exit 1 で詰まる（remote 先行と `.pyc` 差分の同時発生が発火条件）。provisioning 後に clone の `info/exclude` へ `__pycache__/` を冪等追記する——working tree 非接触ゆえ `git status` を汚さず、ブランチ側 `.gitignore` の有無に依らず効く

### Added

- **ROUTINE_PROMPT「Failure modes」へ worker プロセス再起動からの復帰手順** — watch 中のターン切断はセッションの終了ではなく中断（offset・lease・registry・deadline は全て永続側に生存）。復帰は env snapshot re-source → `lease renew`（acquire ではない）→ 残り窓で watch 再開の順で、**bootstrap / lease acquire / オリエンテーションの再実行はしない**（新 session_id への owner 交代や、保持中リースへの acquire conflict（exit 4）で自分を自分で追い出すため）

### Notes

- 既に `.pyc` を追跡してしまっている既存 registry ブランチは、一度だけ `git rm -r --cached <該当ディレクトリ>`（＋任意でブランチ側 `.gitignore`）での掃除を推奨。播種は「以後追跡させない」を保証するもので、追跡済みの掃除は行わない
- 登録済み routine の body は登録時 snapshot のため、Failure modes 追記の反映には body の再登録が必要

## [1.4.2] - 2026-07-30 — ポーリング窓 580s→540s（不変条件の回復）

母体 TelegramSecretary で SIGTERM(143) の実発生が観測され、同一コードベース由来の本リポにも
同じ既定値が残っていたため波及させる。挙動を変える変更はこの 1 行のみ。

### Fixed

- **`SHIORI_POLL_SET_SEC` の既定を 580 → 540 へ** — `max_duration + timeout < bash_timeout/1000` が
  ポーリング窓の不変条件だが、既定値の組み合わせが `580 + 30 = 610 > 600` でこれを破っていた。
  平常時は `main.py` の「残り窓への丸め」が最終サイクルを吸収するため表面化しないが、Telegram の
  5xx リトライで long-poll が伸びると窓を超えて回り、bash timeout に達して SIGTERM(143) で落ちる。
  540 は 30s のマージンを残し、そのリトライ分を吸収代として持つ。**env で上書き可能な既定値のみの
  変更**でロジックは不変（丸め処理も従来どおり値に依存しない）
- **`bootstrap.sh` のコメントに不変条件を明記** — 「bash timeout より短く」とだけ書かれていたため、
  「どれだけ短ければよいか」が暗黙になっていた。今回の違反は式が書かれていれば目視で気付けた

### Changed

- **`$SHIORI_MAX_TURNS` の算出例を新しい窓長へ同期** — 24h≈507・4h≈84 → **24h≈520・4h≈86**
  （`bootstrap.sh` のコメント算出例、`docs/ROUTINE_PROMPT.md`、および英語版）。式は不変で、
  アイドル下限 `duration/POLL_SET_SEC` が窓の短縮分だけ増える。README の常駐設定注記も 580s→540s
- 上限が上がるのは日次総量レートキャップの天井のみで、`~15通/h` の最低保証枠は変わらない

## [1.4.1] - 2026-07-29 — allowlist を通った後の面を塞ぐ（入力・出力・流量）

`allowlist` は「誰が到達できるか」だけを決める。それを通った後の入力面・出力面・流量が
無防備で、防御の一部が `docs/SECURITY.md` に「運用責務」「設計要件」と書かれたまま
機械化されていなかった。本リリースはその 4 点を実装へ落とす。挙動を止める向きの変更は
入れていない（検知・redact・窓による絞りのみ）。

### Added

- **出力漏洩スキャン** — 送信本文に混じった bot token / PAT / 秘匿 env 変数名 / ローカル絶対パスを形状で検出し redact する（`scripts/domain/output_scan.py`）。適用点は `SendReply` と `ProactiveSend` の両方（`docs/SECURITY.md` §4 が両経路を対象と明記していた）。**送信自体は止めない** — 止めると秘書が黙り、事故より障害の方が起きやすい。入力側がフラグ止まりなのに対し出力側で redact するのは、送信が不可逆だから
- **未認可アクセスの記録** — 破棄していた update の `chat_id` と時刻を 1 行残す（本文は載せない）。痕跡が無ければ bot に誰が到達したかを事後に観測できない
- **chat 単位のレート制限** — 認可 chat ごとに直近 60 秒 30 件までを emit する窓（`scripts/domain/rate_limit.py`）。allowlist は「誰が」を絞るが「どれだけ」を絞らないため、認可済み端末の暴走送信がエージェント turn を無制限に焚く経路が開いていた。拒否分は履歴に積まない（フラッド中も窓が開く）

### Fixed

- **添付・音声由来テキストが入力防御を素通りしていた** — NFKC 正規化と injection フラグ判定が本文 `text` / `caption` にしか掛かっておらず、markitdown / pdfplumber が抽出した `rendered_text` と音声 `transcript` は素通しでエージェントへ届いていた。認可済み chat から「指示文を本文でなく添付 PDF に書いて」送れば `injection_flags` は空のまま到達する。**エージェントはフラグ無しを「素性が確認された入力」と読むため、既存防御があること自体が誤った安心を与えていた**。抽出本文は未信頼のバイナリ由来テキストで `text`/`caption` と同格の外部入力面ゆえ、render UseCase で同じ順序（NFKC → フラグ判定）を適用し、emit 側で本文フラグと同じ top-level `injection_flags` へ合流させる

### Security

- **media extras の `Pillow` 下限を 9.1 → 12.3 へ** — 9.1〜12.2 に積み上がった PYSEC 系の既知脆弱性を持つ版がそのまま解決され得た。media 経路は認可済み chat から届く画像・PDF——外部入力——を `pypdfium2` の `to_pil()` で復号する面なので、脆弱版の混入は宣言側で塞ぐ。12.3.0 は `requires-python >=3.10` かつ cp310 wheel を持つため CI の 3.10/3.11/3.12 マトリクスを壊さない
- **`docs/SECURITY.md` を実態へ** — 上記で機械化された項目を「運用責務」から実装済みの記述へ改めた

### Notes

- Domain 追加は純関数 2 本（`output_scan` / `rate_limit`）のみ。UseCase は適用点と観測ログの配線だけを持ち、依存方向は不変。観測ログは stdout が emitter 専用チャネルのため stderr へ出す
- 同梱スキル `precognitive-viewer` は本リリースの対象外（無改変）
- テスト **685 passed**（v1.4.0 の 651 から +34）

## [1.4.0] - 2026-07-26 — 例外名を N818 準拠へ改名（破壊的変更）

### Breaking Changes

- **例外クラス 4 件を `Error` 接尾辞へ改名** — v1.3.2 で `ignore` に退避していた N818 を解除し、検出された全件を改名した。互換 alias は置かない（旧名で import している利用側は明示的に壊す＝minor bump で通知する）

| 旧名 | 新名 | 所在 |
|------|------|------|
| `MediaSizeLimitExceeded` | `MediaSizeLimitExceededError` | `scripts/domain/exceptions.py` |
| `AttachmentNotFound` | `AttachmentNotFoundError` | `scripts/domain/exceptions.py` |
| `AttachmentTooLarge` | `AttachmentTooLargeError` | `scripts/domain/exceptions.py` |
| `_ConfigInvalid` | `_ConfigInvalidError` | `scripts/main.py`（CLI 境界の内部シグナル、公開 API ではない） |

- 影響は `domain/exceptions.py` を直接 import する利用側に限られる。CLI の終了コード・env 変数名・emit される JSON の形と値（`skip_reason="media_size_exceeded"` 等）はいずれも不変

### Changed

- **pyproject の `ignore = ["N818"]` を削除** — 例外命名は以後 CI が恒久的に検査する。v1.3.2 の ignore コメントが名指ししていたのは 3 件だったが、機械に数えさせた実数は 4 件だった（`scripts/main.py` の内部シグナル `_ConfigInvalid` が手書きの列挙から漏れていた）。「理由付きで ignore する」運用でも対象の列挙は人手で腐る、という一例
- **SECURITY.md / SKILL.md と各英語版の記述を新名へ追従** — 旧名の残存は本 CHANGELOG の履歴記述のみ（`git grep` で確認）

### Notes

- 挙動の変更なし。テスト 651 passed（v1.3.2 から増減なし＝改名が既存契約を保った物証）

## [1.3.2] - 2026-07-26 — lint ルールの拡張と CI ゲートの確立

### Added

- **CI（GitHub Actions）を新設** — lint（`ruff check .` / `ruff format --check .`）と pytest を push/PR のゲートに載せた。ruff は `0.16.0` に版固定する（整形結果は ruff の版に依存するため、双子リポ TelegramSecretary と揃えないと差分が出る。更新は「版を上げて再適用する」commit として意図的に行う）

### Changed

- **ruff の select に `N` / `B` / `SIM` / `PTH` を追加** — 従来の `E4,E7,E9,F,I,UP` では「CI が green のまま危険記法が溜まる」経路が残っていた。実際に B904 5 件・SIM105 4 件・PTH 6 件・SIM114 1 件・SIM108 1 件を検出。うち 16 件を挙動を変えずに解消し、残 1 件（PTH105）は下記の理由で意図的に見送った。以後の再混入は CI が止める
- **例外連鎖を復元（B904、5 箇所）** — `config.py` の `raise OSError(...)` を `... from exc` へ。原因例外（`json.JSONDecodeError` / `ValueError`）が traceback から切れており、config 不正の一次原因を追えなかった。メッセージ文字列は不変
- **握り潰しを `contextlib.suppress` へ（SIM105、4 箇所）** — atomic 書込の tmp 掃除・`rebase --abort`・lease clear・`sendChatAction` の best-effort。「握るのが意図」であることが構文で読める形にした（挙動不変）
- **パス操作を pathlib へ統一（PTH、5 箇所）** — `os.unlink` / `open()` を `Path.unlink` / `Path.open` へ。同梱スキル precognitive-viewer の 2 箇所を含む
- **`I`（import 整列）と `UP`（pyupgrade）の恒久ルール化と一括適用** — 狭い select では検出されないまま `typing.Dict` / `Optional[X]` 等の旧記法が残存していた。`ruff format` も全 Python ソースへ適用し、整形基準を機械可読に固定した

### Notes

- **PTH105（atomic 書込の `os.replace`、1 件）は `scripts/adapters/atomic_io.py` の per-file-ignores で除外** — `Path.replace` へ替えたところ CI の Python 3.10 で 6 件 red になった。3.10 の pathlib は accessor 経由で import 時に `os.replace` を束縛するため、`Path.replace` にするとクラッシュ注入テストの `monkeypatch.setattr(atomic_io.os, "replace", ...)` が素通りし、「publish 前クラッシュで旧内容が残る」不変条件が 3.10 で無検査になる。lint の見栄えより検査可能性を採った（`requires-python` は `>=3.10`）
- N818（例外名の `Error` 接尾辞、4 件）は `ignore` に理由付きで登録し見送り。`MediaSizeLimitExceeded` / `AttachmentNotFound` / `AttachmentTooLarge` は SECURITY.md・SKILL.md・usecases・tests から名指しで参照される公開 API であり、patch リリースでの改名は利用側を壊す。破壊的変更として次の minor にまとめる
- 同梱スキル precognitive-viewer の N803 / N806 / N999 は per-file-ignores で除外。占術ドメインを日本語の識別子（天 / 地 / 人 / 得卦 / 総格）で書いており、日本語には大文字小文字の区別が無いため構造上必ず誤検知になる。N999 はパッケージ名 `PrecognitiveViewer` 自体で、公開 import パスゆえ改名できない
- 挙動の変更なし。テスト 651 passed（増減なしが、リファクタが既存契約を保った物証）

## [1.3.1] - 2026-07-26 — 音声デコード失敗を「無音」と区別

### Fixed

- **音声のデコード失敗が「無音」に化けていた** — `FfmpegAudioPreprocessor` が壊れた音声・音声ストリーム無しのファイルでも空配列を返していたため、`MoonshineTranscriber` が「本当に無音」と同じ `render_status="ok"` + 空 transcript に丸め、秘書は読み取り失敗を検知できなかった。デコード不能時は新設の `AudioDecodeError` を送出し `failed` へ翻訳する。デコードできて 0 サンプルだった場合（＝本当に無音）は従来どおり `ok`、途中まで取れた場合は部分音声を返す

## [1.3.0] - 2026-06-12 — アネゴ機能（P×A 役割進化・3表追加・三位占術スキル同梱）

### Added

- **役割のデータ駆動進化（P×A 直交2軸、通称アネゴ機能）** — 預けたデータで秘書の顔が進化する: **秘書**（baseline）→ principal のプロファイルを預けると**執事**（P✓: 嗜好を踏まえた先回り）→ active な目標を預けると**コーチ**（A✓: 目標逆算とプロマネ巻き取り）→ 両方で**アネゴ**（P×A: 人物理解 × 伴走の両輪）。全目標達成で A 軸が降りて自然に卒業（アネゴ→執事）。判定は `derive_role` 純関数＋`role-status` subcommand（決定論）が担い、役割の演じ方のみ SecretaryRole ガイダンスに置く——LLM の役割自称ハルシネーションを構造的に排除（DESIGN §3.11）
- **管理表3表追加（4→7表）** — `PROFILE`（人物理解＝P軸。method ∈ precognitive_viewer/json_fortune/mbti/interview/observation/other、蓄積優先）／`GOALS`（目標＝A軸。category ∈ money/work/relationship/health/other の四大相談コース、closed_at 起点の日付 Archive）／`STEPS`（目標逆算ステップ。goal_id 必須・seq 順、親 GOAL 連動 Archive）。既存4表と同型の CRUD subcommand・値オブジェクト検証・git 永続化・**WAL 言行一致**が `REGISTRY_SPEC` 追加だけで自動適用（abilities 前例 §3.8 の踏襲、UseCase/Adapter 無変更）。雛型 `templates/{PROFILE,GOALS,STEPS}.template.json` を追加
- **PrecognitiveViewer 同梱（三位占術スキル、P軸経路①）** — 姓名判断（七格剖象法）×周易（デジタル心易）×タロット（Rider-Waite-Smith）のフォーマル鑑定書生成スキルを `skills/precognitive-viewer/` に配布版として同梱（原典: Weave Project、固有名サニタイズ済み・実鑑定書サンプル除外・梶原流原典テキストは著作権確認まで非同梱）。**全占術ローカル計算・決定論的再現性・ネットワーク I/O 不在**（`test_self_contained.py` が構造的に保証）。ShioriSecretary 本体と import 関係を持たない独立パッケージで、利用は ABILITIES への動的インストール（`abilities add`）による **opt-in**——テンプレには焼かず、占いを使わない利用者の体験を変えない。鑑定者名は `ReadingReportPresenter(examiner=...)` で注入可能（配布物に人格名を焼き込まない）
- **パーソナライズ聴取3経路**（SecretaryRole「パーソナライズの聴取」） — ①同梱 PrecognitiveViewer の動的インストール ②JSON 出力型占いサイトの紹介（例: senjutsu.jp——ブラウザ内計算・データ外部送信なし。**ユーザー自身が**取得した JSON を秘書が LLM 解釈、パーサー固定せず外部形式変更に頑健）③MBTI 等の直接聴取。いずれも本人同意のもと PROFILE へ method 付きで記録
- **伴走方針（A軸）**（SecretaryRole「伴走の方針」） — 1コースから開始（伴走密度を薄めない）、対話で目標言語化→success_criteria→target_date から STEPS へ逆算分解、起動時オリエンテーションと自由時間（grant 下）の伴走ナッジ（proactive-send 既存経路を再利用、新規送信機構なし）。健康=医療助言でなく生活習慣の伴走／お金=投資助言でなく家計行動の伴走の境界を明文化
- **`role-status` subcommand** — PROFILE/GOALS から現在の役割を JSON 1行で emit。ROUTINE_PROMPT Step 5 の起動時オリエンテーションが7表一括ロードと併せて1回叩く

### Changed

- **ROUTINE_PROMPT Step 5 を7表オリエンテーションへ拡張** — 一括ロードに profile/goals/steps と `role-status` を追加、自由時間の能動発信候補に「STEPS 期限近接の伴走ナッジ」を追加（**稼働中 routine は prompt body の再登録が必要**）
- **wal-append の `--kind` choices を `REGISTRY_SPEC` 導出へ統一** — 表追加のたびに argparse 列挙を手で増やす二重管理を解消（main.py の registry subparser 生成も同様に SSoT 導出化）
- **SECURITY §7 に PROFILE の機微 PII 項目と占術経路の PII 分界を追記** — PROFILE は本人同意前提・Private 分離、占術3経路はいずれも秘書から外部への PII 送信が構造的に発生しない

### Notes

- テスト 562 → 649（Domain 19 + Infrastructure 13 + テンプレ整合 6 + 同梱スキル移植 42 ＋ 自己完結 3 ほか）。既存挙動の破壊的変更なし（minor bump）

## [1.2.3] - 2026-06-10 — 公開後フルレビューに基づく堅牢性修正と内部リファクタ

### Fixed

- **media download の通信失敗で watch が即死し、当該バッチの全メッセージが恒久消失する不具合を修正** — catch が size 超過のみで、CDN 4xx・期限切れ file_id 等の通信系例外が素通りして watch を traceback 死させていた。fetch が download 前に offset を確定するため、落ちたバッチのメッセージ（テキスト含む）は再取得不能だった。通信失敗を `skip_reason="download_failed"` へフラグ化し（「フラグ化して emit、ブロックしない」原則）、`AuthFailureError`（401）のみ伝播させる。MediaDownloader Port に失敗時契約を明文化。
- **caption が NFKC 正規化と injection フラグを素通りする非対称を修正** — text のみ正規化され caption は生のまま merge されていたため、写真＋caption（最頻の入力形）に載せた全角 injection 文にフラグが付かなかった。merge 前に caption も `normalize_input` を通す。
- **`init-config` の argparse 既定値を雛型既定 `14400` に統一** — 1.2.1 の 14400 統一スイープの取りこぼしで、フラグ省略時のみ `7200`（2h）が書かれていた。
- **CLI の未捕捉 traceback を入力不正（exit 2）へ整備** — registry add の `--json`/`--json-file` 両方未指定（TypeError）・`--json-file` 不在パス（FileNotFoundError）、`send-reply`/`proactive-send` の `--text-file` 不在、`render-pdf` の `--pages` 不正書式が、いずれも traceback で exit 1（transient の誤シグナル）に落ちていた。EXIT_CONFIG_INVALID で明示メッセージを返す。

### Changed

- **全 JSON store の save/rewrite を atomic 化（tmp + `os.replace`）** — truncate→write は書込中クラッシュ（cloud routine の約 4h 強制終了等）で WAL 全損や registry の silent wipe（破損→`[]` ロード→1件だけの表が push されリモート伝播）に至る経路だった。共有ヘルパ `adapters/atomic_io.py` へ集約し、破損フォールバック付き load も一本化。
- **lease 新規取得を排他作成（`O_CREAT|O_EXCL`）に** — load→check→save の TOCTOU で、同時 cron 起動の 2 コンテナが両方 acquire に成功し得た。新規取得経路を `try_create`（OS の排他作成）にし、勝者を構造的に 1 つへ（stale 奪取・自己更新は従来どおり）。
- **git subprocess に timeout（90s）と `GIT_TERMINAL_PROMPT=0`** — credential プロンプト待ちの永久ブロック（WAL push は送信ゲートのため秘書のターン全体が無期限停止）を遮断。`pull --rebase` 失敗時は `rebase --abort` を best-effort 実行してから raise（rebase-in-progress 放置による自己復旧不能を防止）。git stderr の URL 埋め込み認証はスクラブし、PAT がログへ漏れる残存経路を閉鎖。
- **bootstrap の registry worktree 再 provision 前にサニティチェック** — `registry_dir` 誤設定時に既存の実データディレクトリを黙って `rm -rf` しない（不在/空/registry 既知エントリのみ破壊的再 provision を許可、worktree 判定のパス比較は物理パス化で symlink 誤判定も解消）。
- **依存ピンの二重管理を解消** — heavy 依存を pyproject の `media` / `voice` extras へ分離し、bootstrap は tier に応じ `pip install -e ".[media,voice]"` を叩く形へ一本化（ピンの正典は pyproject、bootstrap は再記述しない）。coverage の omit から `main.py` を外し実測を可視化（95%）。
- **telegram retry の共通化と 429 ポリシー統一** — api_gateway / media_downloader の retry 重複を `http_retry.py` へ抽出。CDN 経路が 429 の Retry-After を無視して即死していたのを Bot API 経路と同じ尊重 retry に統一。到達不能コード（`last_exc`）と `DEFAULT_USER_AGENT` 二重定義も解消。
- **ffmpeg 前処理の `tolist()` 廃止** — 長尺音声で Python list 化が数 GB 級に膨らむメモリ暴発リスク。ndarray のまま transcriber へ渡す。
- **内部リファクタ（挙動不変）** — send-reply/proactive-send の lease 検証重複を `usecases/outbound.py` のヘルパへ、FS I/O を伴う添付検証を domain から usecases へ移動（domain 純粋性の回復）、main.py の subparser×handlers dict 二重管理を `set_defaults(handler=)` へ、private シンボル越境 import の解消（DI 組み立てを composition へ公開名移設）、WAL checkpoint の時系列保持（kind 別連結で崩れていた interleave 順を復元）、registry remove の domain 純関数化（`remove_by`）、config の `agent_name`/`private_dir` 型検証、`message_id` の int 防御キャスト、テストの時刻ヘルパ・fake・Config 組み立ての重複一本化、docstring の言行一致修正。

### Added

- **LICENSE ファイル（MIT）** — plugin.json / marketplace.json の `"license": "MIT"` 宣言に対し本文が欠落していた（公開リポの法的体裁）。pyproject にも `license` フィールドを追加。

### Notes

- 公開直後のフルレビュー（domain+usecases / adapters / infrastructure+CLI / 配布物整合の4観点並列）に基づく一括修正。配布ドキュメントの開発残骸（母体略称・個人メモリ参照・幽霊スキル参照・プレースホルダ不統一）も同時に掃除。挙動契約の変更はなし。テスト 512 → 562（+50）。

## [1.2.2] - 2026-06-07 — proactive-send の happy-path settle（偽の障害謝罪を根治）

### Fixed

- **能動送信（proactive-send）が成功しても毎起動で複製され、複製に偽の障害謝罪が乗る不具合を修正** — `proactive-send` は送信成功後に outbound WAL を done 化しておらず（lease renew のみ）、次回起動の `wal-redo` が pending を**無条件**再送していた。outbound は registry のような外部真実源を持たず「送信済みか」を redo 時点で判別できないため、成功送信まで再送対象になり、しかも再送文面が「システムが落ちていたので…」と実際には起きていない障害を断定していた（既に届いているのに未送信を騙る二重の誤り）。DESIGN §3.9 は「送信成功と done 記録の間にクラッシュすれば重複」と happy-path settle の存在を前提にしていたが、その done 記録が実装漏れだった。
- **happy-path settle の実装** — `proactive-send` が送信成功直後に当該 outbound intent を done 化 + push する（`domain.wal.settle_outbound` / `usecases.wal.SettleOutboundIntent` / `wal_cli.run_wal_settle_outbound`）。redo が再送するのは「送信成功↔done 記録の窓でクラッシュした真の中断分」だけになり、正常送信は二度と再送されない。registry kind の冪等化（reconcile/settle）と対称な、外部真実源を持たない outbound 向けの settle。
- **謝罪プレフィックスの中立化** — 障害原因を断定する旧文言（`…に送ろうとした件、システムが落ちていたので念のため再送します`）を、送信済み/未送信のどちらでも偽にならない中立文言（`…にお送りしようとした内容を、念のためお届けします（既に届いていたらご容赦ください）`）へ変更。

### Changed

- **`proactive-send` が outbound WAL ライフサイクルを内包** — 従来エージェントが `wal-append --kind outbound`→`wal-push`→`proactive-send` の3コマンドで回していた手順を、`proactive-send` 一発に集約（内部で `append`(pending)→`push`(must-succeed 送信前ゲート)→送信→`settle`(done)→`push`(best-effort)）。created_at を内部生成して settle キーに使うことで、done 化がエージェントの手順遵守に依存しなくなった。`registry_sync` 無効時は送信のみ（後方互換）。**ROUTINE_PROMPT の outbound 送信手順を更新**（cloud routine prompt body の再登録が必要）。
- **outbound WAL payload に添付パス・reply_to を保存** — 再送時に本文だけでなく添付・スレッド先も復元する（従来は本文のみで添付が落ちていた）。SECURITY §7 の PII 範囲（本文 + 添付パス + chat_id + reply_to）内。

### Notes

- 再送方針の SSoT は DESIGN §3.9。registry kind の冪等化（reconcile/settle）と outbound kind の happy-path settle が対称に揃った。

## [1.2.1] - 2026-06-05 — cloud routine 実測 4h への整合

### Fixed

- **SETUP.md「勤務帯の設計」の 24h 常駐例を実測整合へ修正** — cloud routine コンテナの連続稼働は実測で約 4h（プラットフォーム依存・変動しうる）であり、従来例「1日1回 cron ＋ `session_duration_sec=86340`」では上限で切れた後に翌日まで沈黙し常駐にならなかった。常駐は「実測上限と同程度の枠（例 `14400`）＋ その間隔の cron 複数回（例 4h ごと＝ JST 0/4/8/12/16/20）」で実現する旨へ訂正。

### Changed

- **`session_duration_sec` の雛型既定・クイックスタート例を `14400`（4h）へ** — `config.template.json` の既定値と `init-config` 例（README / commands）を、cloud routine 実測上限（約 4h）に合わせた常駐向けの目安 `14400` に統一（従来 `7200`）。`config.template.json` のフィールド説明にも既定値の根拠を明記。
- **本番常駐例を 2h 枠から 4h 枠へ統一** — README クイックスタート注記の本番設定と ROUTINE_PROMPT の `$SHIORI_MAX_TURNS` 算出例を実測 4h に更新（`24h≈507・2h≈42` → `24h≈507・4h≈84`）。`bootstrap.sh` のコメント算出例も同期（挙動・式は不変、例示値のみ）。`580s` 窓（1 ポーリングサイクル長）は session 枠と独立ゆえ不変。
- **`session_config.py` の `MAX_SECONDS` コメントを明確化** — `86400`（24h）は値域の妥当性ガード上限であり、プラットフォームの実セッション上限（実測 約 4h）とは別レイヤーである旨を注記（値は不変）。
- **`wal-redo` 契約を「outbound kind に限り再送する」へ拡張** — 従来「返信は再送しない」（registry kind の redo 専任）だった契約を、entries を registry kind と outbound kind に二分する形へ拡張。**registry kind は不変**（reconcile→upsert→settle、送信前クラッシュ分は offset 再取得が担うため再送しない）で、outbound kind のみ独立ループで1回再送する。`wal-append --kind` の choices に `outbound` を追加。

### Added

- **`proactive-send` サブコマンド（秘書による能動 outbound）** — 受信への返信（`send-reply`）に対し、inbound に紐づかない能動送信を担う双方向化。`SendReply` から `OffsetStore` 依存と offset advance を除いた姉妹 UseCase で、**offset 非干渉**（offset は inbound 専用の既読台帳ゆえ依存に持たない＝「advance して未読 inbound を取りこぼす」事故を構造的に封じる）。lease 検証→添付検証→送信→lease renew の不変条件は send-reply から継承。引数は `--chat-id`（必須）/ `--text-file`（必須）/ `--owner` / `--file`（複数可）/ `--reply-to` で、**`--update-id` は持たない**（send-reply との差分）。exit code は send-reply と同一（0/1/2/3/4）。能力境界（秘書は基本 inbound、口頭 grant で outbound）は SecretaryRole、再送の冪等性設計は DESIGN §3.9 が SSoT。
- **`wal-redo` の outbound 再送（言行一致の outbound 版）** — proactive-send は inbound に紐づかず offset の安全網が無いため、WAL 再送が唯一の冪等性保証になる。起動時に outbound kind の pending を **1回だけ再送**（本文頭に元送信予定時刻＋謝罪プレフィックスを付す）して即 `mark_done` する（再送→即 done で無限再送ループを防ぐ。TTL も content-hash dedup も持たない）。買える保証は at-least-once で、重複は技術で潰さず「受け手の混乱」を社会レイヤで無害化する設計（DESIGN §3.9）。`wal-append --kind outbound`（`chat_id` 必須）で先行書込。

## [1.1.0] - 2026-06-04 — 能力カタログ（abilities）

### Added

- **`abilities` 管理表（registry 4 表目、individuals/tasks/knowledge と同格）** — 秘書が行使できる能力（スキル）のカタログ。同じ CRUD（`abilities {list|get|add|remove}`）・値オブジェクト検証・`registry_sync` での git 永続化を持つ。各レコードは発動シグナル `trigger`・スキル実体パス `skill_path`・起動 `guidance` を保持し、秘書は応答前に `abilities list` で該当能力を引いて外部スキルを行使する（例: 占い依頼 → 占術スキルで鑑定書生成 → `send-reply --file`）。雛型 `templates/ABILITIES.template.json` を追加。**WAL 対象**（4 表一様、§3.8）：能力の自己追記は「『○○できます』と相手に宣言する返信」を伴いうるため、individuals/tasks/knowledge と同様に WAL 先行書込で保護する（`wal-append --kind abilities` 受理、起動時 redo も abilities を反映。宣言したのに push 漏れで未登録、の言行不一致を防ぐ）。
- **ROUTINE_PROMPT「4 表オリエンテーション」** — 手順12を拡充し、4 表（誰と・何を頼まれ・どう判断し・何ができるか）の位置付けと「溜めるだけでなく応答前に能動的に引く」運用方針、abilities の read 配線（`trigger` 該当 → `skill_path` の SKILL.md → `guidance`）を明示。能力の自己追記は実在スキルに限るガード付き（ハルシネーション防止）。

### Changed

- **配布用の一般化リファクタ（用語・テンプレート整合）** — 固有名の一括中立化で生じた末尾スペース（`エージェント␣`、56 箇所）を除去、cloud routine 表記を統一、運用固有名を中立例へ置換。管理表テンプレート（INDIVIDUALS/TASKS/KNOWLEDGE）の保存先記述を `<registry_dir>` へ整合（registry_dir 分離の反映漏れ）、プレースホルダを規約（`<AGENT_NAME>`/`<OWNER>`）へ統一。コードコメントの devlog 参照（配布物に無い無効リンク）を DESIGN §3.6 へ振替。
- **registry/wal CLI の DRY 統合** — `_WAL_KINDS` を `_REGISTRY_SPEC`（SSoT）全種別から導出し二重管理を解消、`_service`/`_build_git`/`_read_json_arg` を共通利用。`wal-append --kind` の choices に abilities を追加し CLI・wal_cli・ドキュメントを整合。`_NON_FF_MARKERS` の冗長要素・テストの未使用 import を整理。
- **archive/分割の位置づけを設計整合** — 「いつ・どの単位で分割/archive するか」は重要度の世界（エージェント判断）であり決定論的に自動実行しない、と DESIGN §2/§3.5・STRUCTURE を訂正（情報の持ち方は情報の主体が決める）。`archive_rotate.py` は純関数（道具）として位置づけを明確化。

### Notes

- 能力をデータ層（Private git）に置き、**稼働 body を触らず拡張する**設計。read 配線を一度通せば、以後の能力追加は `ABILITIES.json` の Private push だけで済む（cloud routine の prompt body 再登録が不要）。配布 template には具体能力を焼かない（母集団スコープ）、運用固有の能力は Private 実データに置く。

## [1.0.0] - 2026-06-03 — 正式リリース（言行一致の WAL）

### Added

- **返信送信前の WAL 先行書込（言行一致の保証、`registry_sync` 有効時）** — registry の push 漏れで「登録しました」と返信したのに未登録、という consistency 違反をゼロにする Write-Ahead Log。内部状態の変更を約束する返信の前に intent を WAL ログ（`registry_dir/wal/WAL.jsonl`、registry と同一固定ブランチ）へ追記・push（**must-succeed**＝push 不能なら send-reply も打たない）し、起動時に未反映 intent を registry へ redo（key 冪等・**返信は再送しない**＝送信前クラッシュ分は offset 再取得が担う役割分担）。ログは直近 24h の会話文脈の短期記憶も兼ね、pending は無条件保持・done は起動時チェックポイントで 24h 掃除。新規 CLI: `wal-append` / `wal-push` / `wal-redo`。durability（冗長化）でなく consistency（言行一致）を**順序**で解く設計。

### Notes

- **0.x → 1.0.0（公開 API の安定宣言）** — 0.1.0（2026-05-26 初版）から積み上げた受信メディアの中身理解・PDF 段階処理・音声 STT・生成物の送り返し・管理表の git 永続化・WAL が出揃い、cloud routine 上の対話秘書として配布可能な完成形に到達した。SemVer に従い、CLI subcommand 群・exit code（0〜4）・config.json スキーマ・emit スキーマ（`v:2`）を公開契約として安定化する（以降の破壊的変更は major で予告）。

## [0.13.0] - 2026-06-03 — 管理表の git 永続化

### Added

- **管理表の git 永続化（`registry_sync` オプトイン、既定無効）** — 秘書が蓄積する管理表（INDIVIDUALS／TASKS／KNOWLEDGE）を固定ブランチ（`registry_branch`、既定 `claude/shiori-registry`）へ永続化し、cloud routine の fresh clone を跨いで残す。更新（add/remove）のたびにイベント駆動で commit&push、起動時に `registry-sync` で fetch。commit はローカル即時・push は best-effort（一時失敗は次回 sync でまとめて再送）。複数 JSON の独立した部分更新を壊さないため **force 不使用**（通常 push の non-fast-forward 拒否で競合を検出、外部更新の例外時のみ `pull --rebase` フォールバック、lease がシングルライターを保証）。
- **`registry-sync` サブコマンド** — 起動時に固定ブランチから管理表を fetch する（`registry_sync` 有効時のみ、無効は no-op）。fetch 失敗は transient（前回ローカル状態で起動し次回再試行）。
- **registry 設定を config.json に集約** — `registry_sync` / `registry_dir` / `registry_branch`（＋ `registry_remote`）を非秘匿の運用設定として config.json（純2層）に追加、雛型 `templates/config.template.json` に反映。cloud routine 起動手順（`ROUTINE_PROMPT.md` の起動時 fetch・更新時 push・`schedule` body の書き戻し先 `outcomes`）と `SETUP.md` の設定手順も整備。

### Changed

- **管理表の保存先を揮発 state と分離** — offset/lease/media（揮発、`state_dir`）と管理表（永続、`registry_dir`）は永続要件が正反対ゆえ物理分離した。`registry_dir` 未設定時は `state_dir` にフォールバックし既存挙動を維持（後方互換）。
- **`registry_dir` のパス解決を cloud routine の実行 cwd に非依存化** — config.json の相対 `registry_dir` を `Path.resolve()`（cwd 基準）で解決すると、registry サブコマンドが skill ディレクトリを cwd として実行されるため、複数リポ並列 clone 構造では Private clone の外側（git 追跡外）の誤ったパスに解決される。bootstrap が起動時 cwd（リポジトリ親）基準で絶対化して `SHIORI_REGISTRY_DIR` に注入し、設定読込が env を優先する方式に統一した（揮発 `state_dir` の絶対化と同型）。env 不在時は従来どおり config.json 値を解決（ローカル運用の後方互換）。

### Verified

- **registry 永続化を実機（cloud routine）で検証** — Telegram 経由でタスクを登録→詳細更新し、固定ブランチ `claude/shiori-registry` への add commit 到達、`TASKS.json` の upsert 冪等（同一 id が `created_at` 保持・`updated_at` 更新で 1 レコードに畳まれる）、起動時 fetch による復元を確認。push 経路の健全性（commit が origin に到達）も併せて確認した。

## [0.12.0] - 2026-06-03

### Changed

- **`SHIORI_MAX_TURNS` を「暴走保険」から「日次総量レートキャップ」へ役割変更（duration 連動の動的算出）** — 固定 `300`（2h セッション前提の `2h/30s≈240+バッファ`）を廃し、`session_duration_sec` から `アイドル下限(duration/POLL_SET_SEC) + 15通/h 枠` で算出（24h→約507、2h→約42）。「≈15通/h を最低保証」する天井になり、`session_duration_sec` を変えても追従する。従来は 24h 運用へ 2h 前提の 300 を流用し、活発な日に deadline 前へ早期到達する不整合があった。停止主軸は引き続き deadline（時刻）で、本キャップは日次総量の上限＝暴走保険を兼ねる（累積カウンタゆえ先食い可・毎時平準化ではない）。`SHIORI_MAX_TURNS` を env で明示すれば従来どおり上書き可、レート定数は 15通/h 固定（`bootstrap.sh` の `_shiori_msg_per_hour`）。短 duration（テスト用、約1.4h 未満）では整数除算で算出が過小/0 になり `/goal` が即停止するため floor=30 を敷く。

## [0.11.1] - 2026-06-02

### Fixed

- **ドキュメントと実装の不整合を解消** — Subcommands 表の記載漏れ（`watch --timeout` / `lease --ttl` / `poll --timeout`、いずれも実装済み）を補完。STRUCTURE.md の管理表 CRUD を実装どおり `list|get|add|remove` に修正（`update` は無く `add` が upsert）。

### Changed

- **運用設定パスを `<INSTALL_DIR>` 基準に汎用化（配置・junction 非依存）** — bootstrap が repo root を `../..`（2階層配置前提）で算出するのを廃止し、自分の物理位置から絶対解決する `INSTALL_DIR` に一本化。ROUTINE_PROMPT / SETUP / bootstrap コメントから運用固有のディレクトリ階層を除去し、`schedule` の body 生成時に `<INSTALL_DIR>` を実配置パスへ置換する手順を追加。env snapshot から派生 `SHIORI_REPO_ROOT` を除去。

### Removed

- **未使用の `watch_loop.sh` を削除** — `/goal` が `watch` を直接呼ぶ設計（D 案）への転換で不要化していた pass-through ラッパーを除去（STRUCTURE / DESIGN / exit_codes.py の言及も整理）。

## [0.11.0] - 2026-06-02

### Added

- **plugins-weave marketplace プラグイン化** — ShioriSecretary を plugins-weave の marketplace プラグインとして配布。skill は `skills/shiori-secretary/`、スラッシュコマンドは `commands/shiori-secretary.md`、`.claude-plugin/plugin.json` を追加。
- **運用設定の単一正典化（config.json）** — 手置換が必要だったプレースホルダ（人格名・private_dir 等）を `config.json`（`<INSTALL_DIR>/config.json`、`.gitignore` 除外）に集約。雛型は `templates/config.template.json`、`init-config` で生成。ROUTINE_PROMPT の Step 0 が config.json から `agent_name`/`private_dir` を動的読込し、**prompt 本文の複製・手置換が不要**に。
- **継続時間の設定可能化（`session_duration_sec`）** — セッション枠を config.json で設定（範囲 1〜86400 秒、fail-fast）。本番（勤務帯調整）／テスト（短縮で keep-alive 高速検証）／観測（cloud routine 実行制限の実測）の三役。
- **`show-config` / `init-config` サブコマンド** — 現設定の read-only 表示（秘匿マスク、未設定でも exit 0）と config.json 生成（範囲検証 + `--force` ガード）。
- **cloud routine ライフサイクル統合（`/shiori-secretary schedule` / `unschedule`）** — 常駐 routine 自体の登録・更新・停止を skill 操作化。`schedule` は upsert（`RemoteTrigger create` or `get→modify→update` ＋ `init-config`）、`unschedule` は `enabled:false` 停止（物理削除は claude.ai UI 手動）。RemoteTrigger スキーマ罠（events v1 ネスト・session_context 全置換）の回避は内蔵 `schedule` skill を正典参照。手順 SSoT は ROUTINE_PROMPT.md。
- **ドキュメント命名統一** — ドキュメント内の旧称 `/secretary`（7 箇所）を skill 実名 `/shiori-secretary` に統一。

### Changed

- **設定を純2層に整理** — env は秘匿（bot token / authorized chats）+ state_dir のみ、非秘匿の運用設定は config.json が単一正典。`config.py` が config.json を直読み（`from_env`→`from_sources`）。`config.json` の場所は `<INSTALL_DIR>` 直下に決め打ち（env で指さない＝鶏卵問題の回避）。
- **Composition Root の導入** — 依存の組み立て点を一箇所（`infrastructure/composition.py`）に集約。設定読み込みを fail-fast 化し、`poll`/`watch` 共通のメディア処理スタック構築を統一。各 CLI ハンドラは組み立て済みの依存を受け取り、自前で生成しない。終了コードの定義も単一の正典に一本化。CLI・終了コード・出力は不変の内部リファクタ。

### Removed

- **`SHIORI_SESSION_DURATION_SEC` の 7200 既定フォールバックを廃止** — `session_duration_sec` は config.json で必須（欠落は fail-fast）。bootstrap は config.json から duration をローカル取得して deadline 計算し、duration 設定値を env に出さない（純2層）。

## [0.10.1] - 2026-05-31

### Verified

- PDF オンデマンド抽出を実機（cloud routine）で検証。受信 PDF を自動で画像化し、エージェントが必要に応じて全文（`render-pdf --text`）や巻末ページ（`--pages`）を能動取得する流れを、テキスト PDF・スキャン PDF・多ページ・大量ページ・保持期限／出力漏洩スキャンにわたり確認。

## [0.10.0] - 2026-05-31 — PDF オンデマンド抽出

### Changed

- PDF を**常に全ページ画像化**する方式へ一本化（テキスト層の有無で経路を分けるのを廃止）。全ページ同一のスタンプや薄いテキスト層による誤判定を構造的に排除。

### Added

- `render-pdf` サブコマンド（`--text`=全ページのテキスト層を抽出／`--pages N-M`=指定ページを画像化）。受信時は先頭ページ（既定 20 枚）のみ事前画像化し、全文や上限超のページは必要時に遅延生成してトークン・ディスクを節約。

## [0.9.0] - 2026-05-30 — PDF の画像化（Vision 経路）

### Added

- 画像 PDF（スキャン・図面）を全ページ画像化し、エージェントが先頭ページから段階的に Vision 解釈。画像化（決定論・低コスト）と Vision（判断・高コスト）を分離し、`page_count` で総量を把握して必要分のみ読む。
- 画像化ページ数の上限 env（`SHIORI_PDF_IMAGE_MAX_PAGES`、既定 20）を追加。

### Notes

- OCR ではなく Vision を採用（図面・写真の比重と、後続の動画キーフレーム解釈との共通基盤のため）。派生画像は保持期限クリーンアップの対象。

## [0.8.1] - 2026-05-30

### Verified

- PDF テキスト抽出を実機検証。`Read` ツールを使わずに PDF 本文へ到達できること、文字化けしやすい PDF もクリーンに抽出できること、スキャン PDF はテキスト層ゼロを正直に返すこと、偽装ファイルを厳格に弾くことを確認。

## [0.8.0] - 2026-05-30 — PDF テキスト抽出

### Added

- PDF のテキスト層を pdfplumber で抽出し、本文を `rendered_text` に載せて返す（`MediaRenderer` の第三実装）。`Read` ツールに依存せず PDF 内容へ到達。テキスト層ゼロ（スキャン PDF 等）は空文字で「読めるテキストなし」を正直に返す。

### Notes

- pdfplumber（MIT、pure-python）を採用、pymupdf（AGPL）は配布制約のため不採用。内部ライブラリは `MediaRenderer` Port で差し替え可能。

## [0.7.5] - 2026-05-30

### Verified

- 音声・動画の文字起こしを cloud routine（Linux）実機で検証。音声ライブラリの導入、各種音声／動画形式の transcript 化、無音・破損ファイルの安全な空応答、保持期限クリーンアップ、出力漏洩スキャンを確認。

### Fixed

- 音声の破損・デコード不可を「失敗」ではなく「音声なし（空 transcript）」として扱うよう統一（クラッシュせず安全側）。媒体ごとに失敗の扱いが異なる点を `render_status` の説明に明記。

## [0.7.4] - 2026-05-29

### Verified

- 常駐セッションが既定枠（約2時間）を通して生存し、強制終了の発火なく正常終了することを実機確認。

### Fixed

- 長時間ポーリングの最終サイクルが窓満了を超過し、シェルのタイムアウトで強制終了されるリスクを修正。最終サイクルの待機を残り時間に丸め、プロセスが自然終了を先に迎えるよう不変条件を保証。

## [0.7.3] - 2026-05-29

### Fixed

- cloud routine のシェルは呼び出しごとに環境変数が揮発する（カレントディレクトリのみ持続する）前提に対応。bootstrap が派生環境変数を snapshot ファイルへ書き出し、各ステップが冒頭で読み直す方式に変更。これによりリース所有者・期限変数が全呼び出しで一貫。
- 相対指定の state ディレクトリがサブシェルの `cd` で実体のないパスに化ける問題を、bootstrap 実行時に絶対パス化して固定することで解消（既定運用は不変）。

## [0.7.2] - 2026-05-29

### Changed

- 音声バンドル（STT 用ライブラリ）を任意化。メディア種別ごとに必要な依存が異なる前提で、軽量構成（ダウンロードのみ）／標準（文書対応）／音声対応の3段階に分離。`SHIORI_BUNDLE_VOICE=false` で音声バンドルを除外可能。
- 音声 STT ライブラリのライセンスは年商規模により商用条件が変わるため、大規模運用は音声バンドル除外または代替ライブラリへの切替で対応。

## [0.7.1] - 2026-05-29

### Verified

- 前面実行の長時間ポーリングで cloud routine のコンテナが枠の間 warm 維持され、期限到達で正常終了することを実機確認。セッション内 keep-alive 方式の成立を確認。

### Fixed

- 起動時にメディア処理用の依存（文書・音声ライブラリ）を一括読み込みしてクラッシュする問題を、遅延構築に変更して解消。メディアを受けるまで重い依存を読み込まず、常駐起動が常に軽い。

## [0.7.0] - 2026-05-29 — 常駐ロングポーリング（keep-alive + 即応）

### Added

- 既定枠（約2時間）の間セッションを warm に保ちつつ、メッセージに即応する keep-alive 設計。各ターンで前面実行の `watch` を1回回し、メッセージ受信で即座に返信→再起動、無メッセージなら窓満了まで long-poll でブロック（待機コスト最小）。
- `watch` に窓満了 exit（`--max-duration`）とメッセージ受信 exit（`--exit-on-message`）を追加。停止の主軸を時刻（期限）に置き、ポーリング回数を判断から切り離す。

## [0.6.0] - 2026-05-28 — 管理表＋ドキュメント体系

### Added

- 秘書の3管理表（関係者 INDIVIDUALS／依頼 TASKS／対応知 KNOWLEDGE）を Clean Architecture 4層で構築。正典は Private な JSON、配布物はテンプレートのみ（個人データを焼き込まない＝配布可能性の担保）。
- 管理表 CRUD の CLI サブコマンド（`individuals|tasks|knowledge`）。操作主体はエージェント、書き込みは決定論的 I/O、入口は将来 `/shiori-secretary` でラップ。
- 肥大化対策：TASKS／INDIVIDUALS は日付アーカイブ、KNOWLEDGE はカテゴリ分割（知識は蓄積が本質のため捨てない）。
- 設計ドキュメント体系を整備（DESIGN／STRUCTURE／SECURITY）。

## [0.5.1] - 2026-05-27

### Fixed

- 返信スレッド機能の入力源（元メッセージ ID）が emit に含まれず、エージェントがスレッド返信に渡す値を取得できなかった設計不整合を修正。
- 送信失敗時のネットワークエラー経路で、token を含む URL が例外メッセージに漏れる経路を塞いだ（全送受信経路で統一）。

## [0.5.0] - 2026-05-27 — 生成物の送り返し

### Added

- エージェント生成物（画像・レポート・文書）を Telegram に送り返す outbound media。`send-reply --file`（複数可、画像は写真・他は文書に自動振り分け）、`--reply-to` で返信スレッド、送信前の typing インジケータ。送信添付のサイズ上限（既定 50MB）を超えると送信前に弾く。
- 送信ファイルの生成はエージェント、コードは決定論的な送信と送信前チェックのみ。

### Notes

- 「公式プラグインにあるから移植」ではなく「秘書の価値は受信の中身理解」を軸に選択的に実装。markdownv2 整形・絵文字リアクション・送信済み編集は必要時に追加する方針で見送り。

## [0.4.0] - 2026-05-27 — 音声・動画の文字起こし

### Added

- voice／audio／video をローカル STT で transcript 化し、本文として読めるようにする。音声はローカル推論で外部に送信しない（機密音声に安全）。文書 Markdown 化と同じ枠（`rendered_text`）に乗せ、emit スキーマは無変更。

### Notes

- STT ライブラリのライセンスは年商規模で商用条件が変わるため、本番商用化前に契約または代替ライブラリ（Apache-2.0 系）への切替を要する。

## [0.3.1] - 2026-05-27

### Fixed

- テスト用フィクスチャが使う書き込み系ライブラリを開発依存に明示追加。宣言された依存だけのクリーン環境でテストが再現するよう修正（開発機の偶然の状態への暗黙依存を排除）。

## [0.3.0] - 2026-05-27 — 文書ファイルの読み取り

### Added

- 文書ファイル（docx／pptx／xlsx・HTML）を Markdown 化して読み取る `MediaRenderer` 抽象を導入。受信メディアを「render してエージェントが読む」流れに一般化。
- レンダリング結果の状態（ok／passthrough／skipped／failed）を構造化。失敗は個別メディア単位でフラグ化し、全体を中断しない。

### Notes

- Markdown 化ライブラリは寛容で不正バイト列にも何か返すため、内容が意味あるテキストかの判断はエージェント側の責務（推論をコード外に出す分業）。

## [0.2.1] - 2026-05-27

### Added

- 受信メディアの保持期限クリーンアップを `watch` ループに配線（一定間隔で期限超過ファイルを自動削除）。手動実行用の `cleanup-media` サブコマンドも追加。

## [0.2.0] - 2026-05-27 — 受信メディア対応

### Added

- 写真・文書・キャプションの受信に対応。認可済みメッセージのメディアをサイズ上限内でダウンロードし、メタ情報とローカルパスを emit。キャプションは本文に統合。
- メディアのサイズ上限（既定 20MB、DoS 防御）と保持期限（既定 24時間、機密書類の長期残存防止）。ダウンロード有無を切り替える Heavy／Medium モード。
- token を含むファイル URL をログ・例外に残さない redact を多層で実装。

## [0.1.2] - 2026-05-26

### Added

- セッション ID を環境変数で統一し、`lease`／`watch`／`send-reply` が同じ所有者を共有する運用に整理（`--owner` の明示が不要に、緊急時のみ上書き）。bootstrap を source／exec 両対応に。

## [0.1.1] - 2026-05-26

### Fixed

- `watch` ループがアイドル時にリースを更新せず、無音期間に並走セッションへ奪取される設計ホールを修正（サイクル末尾で自動更新、奪取検出時は自己終了）。
- 送信前にリース所有者を再検証（二重防御）。レート制限（429）と `Retry-After` を尊重。

### Changed

- 全層のテストを信頼性の証拠として公開する方針に統一。

## [0.1.0] - 2026-05-26 — 初版

### Added

- Clean Architecture 4層で基盤を構築。認可（chat_id allowlist、IDOR 防止）、オフセットの単調増加（冪等性）、heartbeat + TTL リース（並走防止・crash 自己治癒）、入力正規化、プロンプトインジェクション検知フラグ（ブロックせず記録）。
- CLI サブコマンド（`validate-config`／`lease`／`poll`／`watch`／`send-reply`／`test`）と bootstrap スクリプト。
- 応答生成は親プロセスのエージェントが担い、コードは fetch／認可／正規化／送信のみ（推論をサブプロセスで多重起動しない設計原則）。
