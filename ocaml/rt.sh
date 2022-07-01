#!/bin/sh

: ${SHELL_TO_JSON=$(dirname $0)/shell_to_json}
: ${JSON_TO_SHELL=$(dirname $0)/json_to_shell}

if [ $# -ne 1 ]
then
    echo "Usage: $0 testFile" >&2
    exit 1
fi

testFile="$1"

if [ ! -f "$testFile" ]
then
    echo "Error: cannot read '$testFile'!" >&2
    exit 1
fi

json=$(mktemp)

"$SHELL_TO_JSON" "$testFile" >"$json"
if [ $? -ne 0 ]
then
    echo "OCAML_PARSE_ABORT: '$testFile'" >&2
    exit 1
fi

rt=$(mktemp)

"$JSON_TO_SHELL" "$json" >"$rt"
if [ $? -ne 0 ]
then
    echo "OCAML_UNPARSE_ABORT: '$testFile' -> '$json'" >&2
    exit 1
fi

cat "$rt"
