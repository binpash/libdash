#!/bin/sh

: ${SHELL_TO_JSON=shell_to_json}
if ! type shell_to_json >/dev/null 2>&1
then
  SHELL_TO_JSON=$(dirname $0)/$SHELL_TO_JSON
fi

: ${JSON_TO_SHELL=json_to_shell}
if ! type json_to_shell >/dev/null 2>&1
then
  JSON_TO_SHELL=$(dirname $0)/json_to_shell
fi

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
