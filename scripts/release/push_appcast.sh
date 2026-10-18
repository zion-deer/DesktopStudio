#!/bin/bash
# Publish appcast.xml on the gh-pages branch. The file must already be written.
set -euo pipefail

APPCAST_PATH="$1"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORKDIR="${RUNNER_TEMP:-/tmp}/desktop-studio-pages"
cd "$ROOT"
git fetch origin gh-pages || true
rm -rf "$WORKDIR"

if git rev-parse --verify --quiet refs/remotes/origin/gh-pages >/dev/null; then
  git worktree add "$WORKDIR" origin/gh-pages
else
  EMPTY_TREE="$(git hash-object -t tree --stdin < /dev/null)"
  COMMIT="$(git commit-tree "$EMPTY_TREE" -m "Initial update feed")"
  git update-ref refs/heads/gh-pages "$COMMIT"
  git worktree add "$WORKDIR" gh-pages
fi

cp "$APPCAST_PATH" "$WORKDIR/appcast.xml"
cat > "$WORKDIR/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Desktop Studio updates</title></head>
<body>
<p>Desktop Studio publishes updates in <a href="appcast.xml">appcast.xml</a>.</p>
</body>
</html>
HTML

git -C "$WORKDIR" add appcast.xml index.html
git -C "$WORKDIR" \
  -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  -c user.name="github-actions[bot]" \
  commit -m "Publish the Desktop Studio update feed"
git -C "$WORKDIR" push origin HEAD:gh-pages
git -C "$ROOT" worktree remove --force "$WORKDIR"
