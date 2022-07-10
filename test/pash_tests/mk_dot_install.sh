#!/bin/sh

set -e

libdash_files=$(ls _build/lib)
bindings_files="META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx"

files=
for f in ${libdash_files}
do
    files="${files} \"_build/lib/${f}\""
done

for f in ${bindings_files}
do
    files="${files} \"ocaml/${f}\""
done

cat >libdash.install <<EOF
lib: [${files} ]
EOF

