#!/bin/sh

set -e

LIB="$1"
: ${LIB:=$(opam var lib)/libdash}

cat >META <<EOF
description = "bindings to the dash shell as a library"
requires = "ctypes,ctypes.foreign,str"
version = "0.1"
archive(native) = "dash.cmxa"
archive(byte) = "dash.cma"
linkopts(native) = "-ccopt -L${LIB} -ccopt -Wl,-rpath -ccopt -Wl,${LIB} -cclib -ldash"
linkopts(byte) = "-dllpath ${LIB}"
EOF

