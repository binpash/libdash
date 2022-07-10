#!/bin/sh

set -e

cd _build/lib

trylink() {
    [ -f "$2" ] || ln -sf $1 $2
}

trylink dlldash.so.0.0.0 dlldash.so
trylink dlldash.so.0.0.0 dlldash.so.0

trylink libdash.so.0.0.0 libdash.so 
trylink libdash.so.0.0.0 libdash.so.0

