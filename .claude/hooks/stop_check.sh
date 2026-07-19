#!/bin/bash
# Blocks session end until primer.md has been rewritten today.
today=$(date +%F)
primer_date=$(date +%F -r primer.md 2>/dev/null)
if [ "$primer_date" != "$today" ]; then
  echo "primer.md was not updated this session. Per the CLAUDE.md session rule, rewrite primer.md completely (phase status, what was done, exact next action, blockers) before ending." >&2
  exit 2
fi
exit 0
