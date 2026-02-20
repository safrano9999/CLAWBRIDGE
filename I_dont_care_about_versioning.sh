#!/bin/bash
set -euo pipefail

GITHUB_USER="${1:?Usage: ./push.sh <githubuser> [--init] [--auth]}"
PROJECT="$(basename "$PWD")"
REPO="https://github.com/${GITHUB_USER}/${PROJECT}.git"

for arg in "${@:2}"; do
    case "$arg" in
        --auth) gh auth login ;;
        --init)
            git config --global user.name "foo@b.ar"
            git config --global user.email "info@127.0.0.1"
            git init
            git remote add origin "$REPO"
            ;;
    esac
done

git remote set-url origin "$REPO" 2>/dev/null || true
git checkout --orphan tmp_branch 2>/dev/null || true
git add -A
git commit -m "$(date '+%Y-%m-%d %H:%M:%S')" --allow-empty
git branch -D main 2>/dev/null || true
git branch -m main
git push --force origin main
