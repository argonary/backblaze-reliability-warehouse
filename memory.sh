#!/bin/bash
echo '=== BACKBLAZE SESSION START ==='
echo "Branch: $(git branch --show-current)"
echo ''
echo 'Last 5 commits:'
git log --oneline -5 2>/dev/null || echo '(no commits yet)'
echo ''
echo 'Modified files:'
git status --short
echo ''
echo '--- primer.md ---'
cat primer.md
echo '=== END ==='
