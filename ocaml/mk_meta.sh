#!/bin/sh

set -e

cat >META <<EOF
description = "bindings to the dash shell as a library"
requires = "ctypes,ctypes.foreign,str"
version = "0.1"
archive(native) = "dash.cmxa"
archive(byte) = "dash.cma"
linkopts(native) = "-ccopt -L$(opam var libdash:lib) -ccopt -Wl,-rpath -ccopt -Wl,$(opam var libdash:lib) -cclib -ldash"
linkopts(byte) = "-dllpath $(opam var libdash:lib)/libdash"
EOF

