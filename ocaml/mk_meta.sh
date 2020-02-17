#!/bin/sh

cat >META <<EOF
description = "bindings to the dash shell as a library"
requires = "ctypes,ctypes.foreign"
version = "0.1"
archive(native) = "dash.cmxa"
archive(byte) = "dash.cma"
inkopts="-ccopt -L$(ocamlfind query libdash) -cclib -Wl,-rpath=$(ocamlfind query libdash) -cclib -ldash"
EOF
