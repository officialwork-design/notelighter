#!/usr/bin/env bash
#
# generate-note.sh の後段で呼び出す検証スクリプト。
# Claudeの自己申告を信用せず、git差分の実態から品質条件を機械的にチェックする。
# 条件を1つでも満たさない場合は非ゼロで終了する（呼び出し元がcommitしないようにするため）。

set -uo pipefail

TOPICS_FILE="topics.md"
DRAFTS_DIR="drafts"
PAID_MARKER="───ここから有料エリア───"

fail() {
  echo "VALIDATION FAILED: $1" >&2
  exit 1
}

if [ ! -f "$TOPICS_FILE" ]; then
  fail "$TOPICS_FILE が見つかりません"
fi

# 1. topics.md の変更が「[ ] が1件減り、[x] が1件増える」のみであること
if git diff --quiet -- "$TOPICS_FILE"; then
  fail "$TOPICS_FILE が更新されていません（[x] への変更が見つかりません）"
fi

diff_lines="$(git diff --unified=0 -- "$TOPICS_FILE" | grep -E '^[+-]\* \[' || true)"

removed_ready="$(printf '%s\n' "$diff_lines" | grep -c '^-\* \[ \]$' || true)"
added_done="$(printf '%s\n' "$diff_lines" | grep -c '^+\* \[x\]$' || true)"
total_status_changes="$(printf '%s\n' "$diff_lines" | grep -c '^[+-]\* \[' || true)"

[ "$removed_ready" -eq 1 ] || fail "'[ ]' が1件だけ削除されている必要があります（実際: ${removed_ready}件）"
[ "$added_done" -eq 1 ] || fail "'[x]' が1件だけ追加されている必要があります（実際: ${added_done}件）"
[ "$total_status_changes" -eq 2 ] || fail "topics.md のステータス変更が想定外です（実際の変更行数: ${total_status_changes}）"

# 2. drafts/ に新規ファイルが1件だけ追加されていること
new_files="$(git status --porcelain -- "$DRAFTS_DIR" | grep -E '^\?\? ' | awk '{print $2}' || true)"
new_count="$(printf '%s\n' "$new_files" | grep -c . || true)"

[ "$new_count" -eq 1 ] || fail "drafts/ 配下の新規ファイルは1件のみである必要があります（実際: ${new_count}件）"

draft_file="$(printf '%s\n' "$new_files" | head -n1)"

# 3. 記事本文が空でないこと
[ -s "$draft_file" ] || fail "生成された記事が空です: ${draft_file}"

# 4. 有料エリア境界が正確に1回だけ存在すること
marker_count="$(grep -c -- "$PAID_MARKER" "$draft_file" || true)"
[ "$marker_count" -eq 1 ] || fail "有料エリア境界（${PAID_MARKER}）は1回だけ存在する必要があります（実際: ${marker_count}回, ファイル: ${draft_file}）"

echo "VALIDATION PASSED: ${draft_file}"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "draft_file=${draft_file}" >> "$GITHUB_OUTPUT"
fi

exit 0
</content>
