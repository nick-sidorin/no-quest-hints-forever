#!/usr/bin/env bash
# Shared regression gate: called by both PR CI and the final release publisher.
# Automatically discovers new test_*.lua suites; no hand-edited CI test lists.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "::group::Verify pinned development standards"
python3 scripts/standards.py check
echo "::endgroup::"

echo "::group::Verify addon TOC and runtime file list"
python3 scripts/package_addon.py --check
echo "::endgroup::"

shopt -s nullglob
lua_files=(NoQuestHintsForever/*.lua tests/test_*.lua)
tests=(tests/test_*.lua)

if (( ${#lua_files[@]} == 0 || ${#tests[@]} < 10 )); then
  echo "::error::Missing Lua files or expected regression suites" >&2
  exit 1
fi

echo "::group::Lua 5.1 syntax verification"
for file in "${lua_files[@]}"; do
  luac5.1 -p "$file"
done
echo "Syntax valid in ${#lua_files[@]} Lua files"
echo "::endgroup::"

echo "::group::Run all Lua 5.1 regression suites"
for file in "${tests[@]}"; do
  echo "Running $file"
  lua5.1 "$file"
done
echo "::endgroup::"
echo "PASS: ${#tests[@]} Lua 5.1 regression suites; source syntax; TOC integrity"
