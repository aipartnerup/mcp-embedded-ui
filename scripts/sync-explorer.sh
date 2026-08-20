#!/usr/bin/env bash
#
# Copy docs/explorer.html into every sibling SDK repo that is checked out.
#
# Each SDK ships a byte-identical copy of the shared template and asserts it in
# its own suite (the "drift check"). This script is the single place that
# performs the copy — the post-commit hook and `make sync-html` both call it,
# so there is no second implementation to drift.
#
# Written for bash 3.2 (the version macOS ships): no associative arrays, no
# empty-array expansion under `set -u`.

set -euo pipefail

# The template's path inside the spec repo. Used both to read the working copy
# and to look up the committed baseline — keep it in one place so the two can
# never disagree.
SRC_REL="docs/explorer.html"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
spec_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
src="$spec_root/$SRC_REL"
parent="$(dirname "$spec_root")"

if [ ! -f "$src" ]; then
  echo "sync-explorer: $src not found" >&2
  exit 1
fi

# repo directory : path of its embedded copy, relative to that repo
TARGETS="
mcp-embedded-ui-python:src/mcp_embedded_ui/explorer.html
mcp-embedded-ui-typescript:src/explorer.html
mcp-embedded-ui-rust:src/explorer.html
"

copied=0
unchanged=0
skipped=0
warned=0
commit_hints=""

echo "sync-explorer: $SRC_REL"

# Iterate the table on newlines only, with globbing off: an entry containing a
# space or a glob character would otherwise be split or expanded against the
# filesystem.
saved_ifs="$IFS"
IFS=$'\n'
set -f

for entry in $TARGETS; do
  repo="${entry%%:*}"
  rel="${entry#*:}"
  repo_dir="$parent/$repo"
  dest="$repo_dir/$rel"

  if [ ! -d "$repo_dir" ]; then
    echo "  -  $repo (not checked out)"
    skipped=$((skipped + 1))
    continue
  fi

  if [ ! -d "$(dirname "$dest")" ]; then
    echo "  -  $repo (no $(dirname "$rel")/ — unexpected layout)"
    skipped=$((skipped + 1))
    continue
  fi

  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    echo "  =  $repo (already in sync)"
    unchanged=$((unchanged + 1))
    continue
  fi

  # Never clobber a copy that was edited in the SDK itself — that is precisely
  # what the drift check exists to surface, and overwriting it would hide the
  # problem instead of reporting it.
  #
  # The test is against the spec, not against the SDK's git status: a copy
  # matching the spec's last commit is the result of an earlier sync (committed
  # there or not) and is safe to replace. A copy matching the spec's working
  # tree was handled above. Anything else was written by someone editing the
  # SDK's copy directly.
  if [ -f "$dest" ]; then
    if git -C "$spec_root" cat-file -e "HEAD:$SRC_REL" 2>/dev/null; then
      if ! git -C "$spec_root" show "HEAD:$SRC_REL" | cmp -s - "$dest"; then
        echo "  !  $repo/$rel matches neither the spec working tree nor spec HEAD" >&2
        echo "     looks edited in the SDK itself — NOT overwritten" >&2
        warned=1
        skipped=$((skipped + 1))
        continue
      fi
    else
      # $SRC_REL has never been committed in the spec repo, so there is no
      # baseline that would let us tell an earlier sync from a local edit.
      # The spec is the source of truth and a first sync has to be possible,
      # so proceed — but say so rather than overwriting silently.
      echo "  ~  no committed baseline for $SRC_REL yet; replacing $repo/$rel"
    fi
  fi

  cp "$src" "$dest"
  echo "  ->  $repo/$rel"
  copied=$((copied + 1))
  commit_hints="${commit_hints}  git -C \"$repo_dir\" commit -am \"chore: sync explorer.html from spec\"
"
done

set +f
IFS="$saved_ifs"

echo
echo "$copied copied, $unchanged unchanged, $skipped skipped."

if [ "$copied" -gt 0 ]; then
  echo
  echo "The copies are written but NOT committed. In each repo that changed:"
  printf '%s' "$commit_hints"
fi

if [ "$warned" -eq 1 ]; then
  echo
  echo "Resolve the flagged repo(s) by hand, then re-run. Their drift-check" >&2
  echo "tests will keep failing until the copy matches the spec." >&2
  exit 1
fi
