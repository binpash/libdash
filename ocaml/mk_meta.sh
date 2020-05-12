#!/bin/sh

set -e

cat >META <<EOF
description = "bindings to the dash shell as a library"
requires = "ctypes,ctypes.foreign"
version = "0.1"
archive(native) = "dash.cmxa"
archive(byte) = "dash.cma"
linkopts(native) = "-cclib -ldash"
linkopts(byte) = "-dllpath $(opam var lib)/libdash"
EOF

