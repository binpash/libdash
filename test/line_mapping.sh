#!/bin/sh
#
# Checks the per-node source line mapping (parsedLines, linno_before,
# linno_after) -- invisible to round_trip.sh, which only sees the AST.
#
# Each fixture in line_mapping/ has a .expected golden, one line per node.
# REGEN=1 rewrites the goldens after an intentional change.

: ${DUMP=../python/dump.py}

cd "$(dirname "$0")" || exit 2

status=0

# dump.py falls back to the working tree, so a stale PYTHONPATH can swap the
# library under test; say which one we got.
echo "# libdash: $("$DUMP" --which 2>/dev/null || echo '<unknown>')"

for tgt in line_mapping/*.sh
do
    expected="${tgt%.sh}.expected"
    actual=$(mktemp)

    if ! "$DUMP" --ranges "$tgt" >"$actual" 2>&1
    then
        echo "LINE_MAPPING_ABORT: '$tgt'"
        cat "$actual" >&2
        rm -f "$actual"
        status=1
        continue
    fi

    if [ "$REGEN" ]
    then
        cp "$actual" "$expected"
        echo "REGEN '$tgt'"
        rm -f "$actual"
        continue
    fi

    if [ ! -f "$expected" ]
    then
        echo "LINE_MAPPING_NO_GOLDEN: '$tgt' (run REGEN=1 $0)"
        rm -f "$actual"
        status=1
        continue
    fi

    if diff "$expected" "$actual" >/dev/null
    then
        echo "PASS '$tgt'"
    else
        echo "LINE_MAPPING_FAIL: '$tgt'"
        diff -u "$expected" "$actual"
        status=1
    fi

    rm -f "$actual"
done

exit $status
