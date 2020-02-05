#!/bin/sh

cat >META <<EOF
description = "bindings to the dash shell as a library"
requires = "ctypes,ctypes.foreign"
version = "0.1"
archive(native) = "dash.cmxa"
archive(byte) = "dash.cma"
linkopts="-ccopt -L$(opam var stublibs) -cclib -ldash"
EOF
