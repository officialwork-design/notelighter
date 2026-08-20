# notelighter

Claude Codeによるnote記事の半自動生成システムです。

毎朝、Claudeがテーマ管理ファイル（`topics.md`）から実体験確認済みのテーマを1件選び、
note記事を1本自動生成して `drafts/` に保存します。noteへの投稿は行いません。
最終的な投稿判断は必ず人間が行います。

## Note自動生成システム

```text
topics.md
  ↓
[ ] の一番上を取得
  ↓
Claude Code
  ↓
記事生成
  ↓
品質チェック（scripts/validate-note.sh）
  ↓
drafts/ へ保存
  ↓
topics.md を [x] に更新
  ↓
Git commit / push
  ↓
人間が確認
  ↓
noteへ投稿
```

## topics.md ステータス

```text
[idea] = AIが作成したテーマ候補。実体験未確認。記事化しない
[ ]    = 実体験確認済み。自動執筆可能
[x]    = 執筆済み
```

詳細な生成ルール・捏造禁止事項・保存ルールは [`CLAUDE.md`](./CLAUDE.md) を参照してください。

## 毎朝の動作

GitHub Actionsが毎日 **10:00 JST**（`.github/workflows/daily-note.yml` の cron: `0 1 * * *` = 01:00 UTC）に起動し、以下を行います。

1. `topics.md` を読み、`[ ]` の一番上のテーマを1件だけ取得する
2. Claude Codeで記事を1本生成し、`drafts/` に保存する
3. `scripts/validate-note.sh` で品質を機械的に検証する
4. 検証に通った場合のみ、対象テーマを `[x]` に更新し、`git commit` / `push` する
5. 検証に失敗した場合、または `[ ]` が0件の場合は、ファイルを変更せずにワークフローは正常終了する

## 手動実行

GitHubのActionsタブから手動実行できます。

```text
Actions
  ↓
Daily Note Generation
  ↓
Run workflow
```

ローカルで直接実行する場合は次のコマンドです（`ANTHROPIC_API_KEY` の設定が必要です）。

```bash
bash scripts/generate-note.sh
```

## readyテーマ（`[ ]`）がない場合

`topics.md` に `[ ]` のテーマが1件も存在しない場合、記事は生成されず、ファイルも変更されません。
ワークフローは失敗扱いにはならず、正常終了します。

## 新しいテーマの追加方法

1. 新しいテーマ候補は、まず `[idea]` として `topics.md` に登録する（AIが候補を追加することもあります）
2. テーマ・想定読者・読者の悩み・読後のゴールまではAIが推測してよいが、経験・試したこと・失敗・成功・気づき等は空欄のままにする
3. 本人（あなた）の実体験・実際に試したこと・失敗・成功した方法・気づいたこと等を追記する
4. 実体験が確認できたら、ステータスを `[idea]` から `[ ]` に変更する
5. `[ ]` に変更されたテーマは、次回の自動実行で上から順に使用される

## セットアップ手順

1. このリポジトリをGitHubに作成・push する
2. リポジトリの **Settings > Actions > General > Workflow permissions** で
   「Read and write permissions」を有効にする（自動commit/pushに必要）
3. 下記のGitHub Secretsを登録する
4. `topics.md` に実体験入りの `[ ]` テーマを1件以上用意する
5. Actionsタブから `Daily Note Generation` を手動実行し、動作を確認する

## 環境変数 / GitHub Secrets

| Secret名 | 用途 | 登録場所 |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | Claude Code CLIをGitHub Actions上で非対話実行するための認証情報 | リポジトリの Settings > Secrets and variables > Actions |

実際の値はこのREADMEやソースコードには記載しません。Secrets登録画面からのみ設定してください。

Claude Code をAPIキーではなくClaudeサブスクリプション（Max等）の認証で動かしたい場合は、
`claude setup-token` で発行した長期トークンを `CLAUDE_CODE_OAUTH_TOKEN` という名前のSecretとして登録し、
`scripts/generate-note.sh` 内の環境変数参照を読み替えて利用してください（本実装は `ANTHROPIC_API_KEY` を主に想定しています）。

## デプロイ手順

1. 変更をGitHubへpushする
2. Actionsタブでワークフローが正しく認識されていることを確認する
3. `workflow_dispatch` から手動テスト実行し、ログとdraftsの生成物を確認する

## 運用手順

1. `topics.md` に新しいテーマ候補を `[idea]` として追加する（AI提案 or 手動）
2. 実体験（経験・試したこと・失敗・成功・気づき等）を追記する
3. 実体験が入ったテーマのステータスを `[ ]` に変更する
4. 毎朝10:00 JSTに自動生成が実行される
5. `drafts/` に保存された記事を確認する
6. 問題なければ人間の手でnoteへ投稿する

## トラブルシュート

| 症状 | 主な原因・対処 |
| --- | --- |
| `[ ]` がない | `topics.md` に実体験入りの `[ ]` テーマがない状態。テーマを追記・昇格させる |
| Claude認証エラー | `ANTHROPIC_API_KEY`（または `CLAUDE_CODE_OAUTH_TOKEN`）が未設定・失効している。Secretsを再登録する |
| Git push失敗 | リポジトリの Workflow permissions が Read-only になっている可能性。Read and write に変更する |
| 記事品質チェック失敗 | `scripts/validate-note.sh` が有料境界の数・空ファイル・複数ステータス変更等を検知して失敗させている。ワークフローのログを確認する |
| workflowが起動しない | cronのUTC時刻設定、またはデフォルトブランチ・ファイルパスの誤りを確認する |
| 同名ファイルが存在する | `drafts/` に同日・同タイトルのファイルが既にある状態。CLAUDE.mdのルールに従い別名で保存する必要がある |
</content>
