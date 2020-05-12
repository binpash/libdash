#!/bin/sh

set -e

cat >META <<EOF
description = "bindings to the dash shell as a library"
requires = "ctypes,ctypes.foreign"
version = "0.1"
archive(native) = "dash.cmxa"
archive(byte) = "dash.cma"
linkopts(native) = "-linkpkg -ccopt -L$(opam var lib) -ccopt -Wl,-rpath -ccopt -Wl,$(opam var lib) -cclib -ldash"
linkopts(byte) = "-dllpath $(opam var lib)/libdash"
EOF

