#!/bin/sh
# All historical workloads retain their payload sizes at 1/100 of the run.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
mkdir -p build/ziran
work=$(mktemp -d "$root/build/ziran/parser-replay-test.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
for form in source saved; do
    for target in c cpp; do
        T9_BENCH_DIVISOR=100 sh scripts/parser-replay.sh "$target" "$form" > "$work/results"
        python3 - "$work/results" <<'PY'
import json
import sys

# Golden row/byte totals from the original C benchmark's payloads, before
# removing that consumer. These check UTF-8, padding, hex and control bytes.
expected = {
    "startup": (1, 24), "ansi_flood": (180, 17640),
    "unicode_table": (60, 5280), "alternate_redraw": (28, 2651),
    "dense_sgr": (90, 12775), "wrap_reflow": (70, 13790),
    "scrollback_flood": (500, 33500), "cursor_matrix": (240, 4465),
    "paste_burst": (120, 19440), "hyperlink_grid": (70, 9520),
    "search_corpus": (180, 17760), "search_visible": (5, 17760),
    "resize_reflow": (1, 8300),
}
with open(sys.argv[1]) as source:
    results = [json.loads(line) for line in source]
assert len(results) == len(expected), results
assert [r["workload"] for r in results] == list(expected), results
for result in results:
    assert result["bench"] == "parser_replay", result
    assert (result["lines"], result["bytes"]) == expected[result["workload"]], result
    assert isinstance(result["elapsed_ms"], int) and result["elapsed_ms"] >= 0, result
PY
    done
done
echo 'All 13 Terminal parser workloads retain their payloads in source/saved-IR C/C++ runs'
