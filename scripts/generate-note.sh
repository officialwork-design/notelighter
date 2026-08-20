#!/usr/bin/env bash
#
# GitHub Actions（毎朝10:00 JST / workflow_dispatch）から呼び出す
# note自動生成処理の入口スクリプト。
#
# 手順:
#   1. topics.md / drafts/ の存在確認
#   2. `[ ]`（実体験確認済み・自動執筆可能）のテーマが存在するか確認
#      存在しなければ正常終了（exit 0）
#   3. Claude Code を非対話モードで実行し、CLAUDE.md のルールに従って
#      記事を1本だけ生成させる
#   4. scripts/validate-note.sh で結果を機械的に検証する
#   5. 検証に失敗した場合は変更を破棄し、非ゼロで終了する
#
# コミット/プッシュ自体はこのスクリプトの責務ではなく、
# 呼び出し元（GitHub Actions workflow）が行う。

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TOPICS_FILE="topics.md"
DRAFTS_DIR="drafts"

if [ ! -f "$TOPICS_FILE" ]; then
  echo "ERROR: ${TOPICS_FILE} が見つかりません" >&2
  exit 1
fi

mkdir -p "$DRAFTS_DIR"

if ! grep -qE '^\* \[ \]$' "$TOPICS_FILE"; then
  echo "実体験確認済み（[ ]）のテーマがありません。記事生成をスキップして正常終了します。"
  exit 0
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  echo "ERROR: ANTHROPIC_API_KEY または CLAUDE_CODE_OAUTH_TOKEN が設定されていません" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: claude コマンドが見つかりません（Claude Code CLI が未インストール）" >&2
  exit 1
fi

PROMPT='CLAUDE.mdに書かれているnote自動生成ルールに厳密に従い、topics.mdから記事を1本だけ生成してください。[idea]のテーマは絶対に使用しないでください。[ ]が0件の場合は何もせず終了してください。ステータス変更は対象テーマのみに行い、他のテーマ・他のファイルは変更しないでください。'

echo "Claude Code を実行します..."
claude -p "$PROMPT" --dangerously-skip-permissions
claude_exit=$?

if [ "$claude_exit" -ne 0 ]; then
  echo "ERROR: claude がエラー終了しました（exit code: ${claude_exit}）" >&2
  echo "中途半端な変更を破棄します。"
  git checkout -- "$TOPICS_FILE" 2>/dev/null || true
  git clean -fd -- "$DRAFTS_DIR" 2>/dev/null || true
  exit 1
fi

echo "生成結果を検証します..."
if ! bash "${SCRIPT_DIR}/validate-note.sh"; then
  echo "ERROR: 品質検証に失敗しました。変更を破棄します。" >&2
  git checkout -- "$TOPICS_FILE" 2>/dev/null || true
  git clean -fd -- "$DRAFTS_DIR" 2>/dev/null || true
  exit 1
fi

echo "記事の生成と検証が完了しました。"
exit 0
