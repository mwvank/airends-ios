#!/usr/bin/env bash
# Turns compiler and test errors from a build log into GitHub annotations,
# so failures show up on the pull request without opening the raw log.
log="$1"
[ -f "$log" ] || exit 0

grep -E ':[0-9]+:[0-9]+: error: ' "$log" | sort -u | head -50 |
  sed -E 's#^(.*):([0-9]+):([0-9]+): error: (.*)$#::error file=\1,line=\2,col=\3::\4#' |
  sed -E "s#file=${GITHUB_WORKSPACE:-.}/#file=#"

# Swift Testing failures and anything else: include the end of the log.
tail_text=$(tail -n 40 "$log" | sed -e 's/%/%25/g' | awk '{printf "%s%%0A", $0}')
echo "::error title=Last lines of $(basename "$log")::${tail_text}"
