FLINE="$1"
FLINE="$FLINE:start(\"$2\")"

bash ../../scripts/run_dist.sh -t "$FLINE" -n "$3"
