#!/usr/bin/env bash
set -euo pipefail

upstream_repo="${UPSTREAM_REPO:-https://github.com/MetaCubeX/meta-rules-dat.git}"
upstream_branch="${UPSTREAM_BRANCH:-sing}"
target_dir="${TARGET_DIR:-geo}"
repo_root="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"

cd "$repo_root"

if [[ ! -d "$target_dir" ]]; then
  echo "Target directory not found: $target_dir" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

upstream_dir="$tmp_dir/meta-rules-dat"

echo "Cloning $upstream_repo branch $upstream_branch..."
git clone --depth 1 --filter=blob:none --sparse --single-branch --branch "$upstream_branch" "$upstream_repo" "$upstream_dir"
git -C "$upstream_dir" sparse-checkout set "$target_dir"

copied_count=0
missing_count=0
json_list="$tmp_dir/target-json.txt"
missing_file="$tmp_dir/missing.txt"
: > "$json_list"
: > "$missing_file"

git ls-files -- "$target_dir" \
  | grep '\.json$' \
  | LC_ALL=C sort \
  > "$json_list" || true

if [[ ! -s "$json_list" ]]; then
  echo "No tracked JSON files found under $target_dir."
  exit 0
fi

while IFS= read -r json_file; do
  [[ -z "$json_file" ]] && continue

  source_file="$upstream_dir/$json_file"
  if [[ -f "$source_file" ]]; then
    cp "$source_file" "$json_file"
    copied_count=$((copied_count + 1))
  else
    echo "$json_file" >> "$missing_file"
    missing_count=$((missing_count + 1))
  fi
done < "$json_list"

echo "Copied JSON files: $copied_count"
echo "Missing upstream JSON files: $missing_count"

if [[ "$missing_count" -gt 0 ]]; then
  echo "Files kept unchanged because upstream has no same-path JSON:"
  cat "$missing_file"
fi
