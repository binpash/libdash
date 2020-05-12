#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: ${0##*/} program target"
    exit 2
fi

p=$1
tgt=$2

orig=$(${p} ${tgt} 2>&1)
if [ "$?" -ne 0 ];
then echo "${tgt} FAILED, couldn't run (output: ${orig})"; exit 2
fi

rt=$(${p} ${tgt} | ${p} 2>&1)
if [ "$?" -ne 0 ];
then echo "${tgt} FAILED round trip, couldn't run (output: $rt)"; exit 3
fi

if [ "${orig}" = "${rt}" ];
then echo ${tgt} OK; exit 0
else
    echo ${tgt} FAILED
    echo ${orig}
    echo ==========
    echo ${rt}
    exit 1
fi
