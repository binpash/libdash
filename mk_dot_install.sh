#!/bin/sh

set -e

libdash_files=$(ls _build/lib)
bindings_files="META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx"

lib_files=
for f in ${libdash_files}
do
    lib_files="${lib_files} \"_build/lib/${f}\""
done

for f in ${bindings_files}
do
    lib_files="${lib_files} \"ocaml/${f}\""
done

bin_files="\"ocaml/shell_to_json\" \"ocaml/json_to_shell\""

cat >libdash.install <<EOF
bin: [${bin_files}]
lib: [${lib_files}]
EOF

