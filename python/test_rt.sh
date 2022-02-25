#!/bin/sh

compare_files() {
    diff $1 $2
    if [ $? -ne 0 ]
    then
        diff -w $1 $2
        if [ $? -ne 0 ]
        then
            echo "FAIL $3: '$testFile' | $1 $2"
        else
            echo "FAIL_WHITESPACE $3: '$testFile' | $1 $2"
        fi
        exit 1
    fi
}


SHELL_TO_JSON_C=./parse_to_json
JSON_TO_SHELL_C=./json_to_shell


if [ $# -ne 1 ]
then
    echo "Usage: $0 testFile"
    echo
    exit 1
fi


testFile="$1"
testName=$(basename "$testFile")

if [ ! -f "$testFile" ]
then
    echo "Error: cannot read '$testFile'!"
    echo
    exit 1
fi

jsonFile=$(mktemp)
roundTripFile=$(mktemp)

"$SHELL_TO_JSON_C" < "$testFile" > "$jsonFile"
if [ $? -ne 0 ]
then
    echo "ABORT_1: '$testFile'"
    exit 1
fi

"$JSON_TO_SHELL_C" < "$jsonFile" > "$roundTripFile"
if [ $? -ne 0 ]
then
    echo "ABORT_2: '$testFile' | $roundTripFile"
    exit 1
fi

# go around one more time, make sure it's the same thing
# we can't just compare up front because the source program could, e.g., use `until`, or pretty printing could be weird

secondJsonFile=$(mktemp)
secondRoundTripFile=$(mktemp)

"$SHELL_TO_JSON_C" < "$roundTripFile" > "$secondJsonFile"
if [ $? -ne 0 ]
then
    echo "ABORT_1: '$testFile'"
    exit 1
fi

# JSON files here might differ because of different linno values!!!

"$JSON_TO_SHELL_C" < "$secondJsonFile" > "$secondRoundTripFile"
if [ $? -ne 0 ]
then
    echo "ABORT_2: '$testFile' | $secondRoundTripFile"
    exit 1
fi

compare_files "$roundTripFile" "$secondRoundTripFile" "(shell single/double round trip)"

thirdJsonFile=$(mktemp)

"$SHELL_TO_JSON_C" < "$secondRoundTripFile" > "$thirdJsonFile"
if [ $? -ne 0 ]
then
    echo "ABORT_1: '$testFile'"
    exit 1
fi

compare_files "$secondJsonFile" "$thirdJsonFile" "(json double/triple round trip)"

echo "PASS: '$testFile'"

# if we got here, cleanup
rm $roundTripFile $secondRoundTripFile $jsonFile $secondJsonFile $thirdJsonFile
