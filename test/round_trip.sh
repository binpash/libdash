#!/bin/sh

if [ $# -ne 2 ]; then
    echo "Usage: ${0##*/} program target"
    exit 2
fi

p=$1
tgt=$2

two_roundtrips() {
    [ "$(head -n1 "$tgt")" != '# TEST: single roundtrip' ]
}

orig=$(mktemp)

"$p" "$tgt" >"$orig"
if [ "$?" -ne 0 ]
then
    echo "RT_ABORT_1: '$tgt' -> '$orig'"
    exit 3
fi

rt=$(mktemp)

"$p" "$orig" >"$rt"
if [ "$?" -ne 0 ]
then
    echo "RT_ABORT_2: '$tgt' -> '$orig' -> '$rt'"
    exit 4
fi

if diff -b "$orig" "$rt" >/dev/null
then 
     echo "PASS '$tgt'"
     exit 0
else
    if two_roundtrips
    then
        # try one more time around the loop
        rtrt=$(mktemp)

        "$p" "$rt" >"$rtrt"
        if [ "$?" -ne 0 ]
        then
            echo "RT_ABORT_3: '$tgt' -> '$orig' -> '$rt' -> '$rtrt'"
            exit 5
        fi

        if diff -b "$rt" "$rtrt" >/dev/null
        then
            echo "PASS '$tgt' (two runs to fixpoint)"
            exit 0
        fi
    fi

    echo "FAIL: '$tgt' first time"
    diff -ub "$orig" "$rt"
    if two_roundtrips
    then
        echo ">>> '$tgt' second time"
        diff -ub "$rt" "$rtrt"
    fi
    exit 1
fi
