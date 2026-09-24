#!/bin/sh

PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:/root/bin"

SCRIPT="$1"

## The status crosses the pipe on fd 3. Do not tidy this line: flattening the
## brace groups, moving the 3>&1, or dropping logger's >&2 each silently restore
## the old behaviour, where every caller was told the command succeeded.
exit "$( { { "$@" 2>&1 ; printf '%s\n' "$?" >&3 ; } | logger -t "$SCRIPT" >&2 ; } 3>&1 )"
