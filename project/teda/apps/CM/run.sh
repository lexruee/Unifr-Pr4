#! /bin/sh
FLINE="$1"
FLINE="$FLINE:start(\"$2\")"
bash ../../scripts/run_local.sh -f "$FLINE" -n "$3"
