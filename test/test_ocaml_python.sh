#!/bin/sh

: ${RT_OCAML=../ocaml/rt.sh}
: ${RT_PYTHON=../python/rt.py}

if [ $# -ne 1 ]
then
    echo "Usage: $0 testFile"
    echo
    exit 1
fi

testFile="$1"

if [ ! -f "$testFile" ]
then
    echo "Error: cannot read '$testFile'!"
    echo
    exit 1
fi

ocaml_rt=$(mktemp)
ocaml_err=$(mktemp)
python_rt=$(mktemp)
python_err=$(mktemp)

"$RT_OCAML" "$testFile" >"$ocaml_rt" 2>"$ocaml_err"
ocaml_ec=$?
"$RT_PYTHON" < "$testFile" >"$python_rt" 2>"$python_err"
python_ec=$?

if [ "$ocaml_ec" -ne 0 ] && [ "$python_ec" -ne 0 ]
then
    echo "PASS '$testFile' | both abort"
    exit 0
elif [ "$ocaml_ec" -ne 0 ]
then
    echo "OCAML_ABORT: '$testFile'"
    cat "$ocaml_err" >&2
    exit 1
elif [ "$python_ec" -ne 0 ]
then
   echo "PYTHON_ABORT: '$testFile'"
   cat "$python_err" >&2
   exit 1
fi

diff "$ocaml_rt" "$python_rt" >/dev/null
if [ $? -ne 0 ]
then
    diff -w "$ocaml_rt" "$python_rt" >/dev/null
    if [ $? -ne 0 ]
    then
        diff -w "$ocaml_rt" "$python_rt" >/dev/null
        echo "FAIL: '$testFile' | $ocaml_rt $python_rt"
    else
        diff "$ocaml_rt" "$python_rt" >/dev/null
        echo "FAIL_WHITESPACE: '$testFile' | $ocaml_rt $python_rt"
    fi
    exit 1
fi

echo "PASS '$testFile'"
