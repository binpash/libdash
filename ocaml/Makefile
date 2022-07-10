BUILD=$(abspath ../_build/lib)

.PHONY : all install clean

all : dash.cmxa META shell_to_json json_to_shell

install : all
	ocamlfind install libdash META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx shell_to_json json_to_shell

META : mk_meta.sh
	./mk_meta.sh

shell_to_json: dash.cmxa ast_json.mli ast_json.ml shell_to_json.ml
	ocamlfind ocamlopt -g -thread -package threads,str,atdgen,ctypes,ctypes.foreign -linkpkg -cclib -L$(BUILD) -cclib -ldash $^ -o $@

json_to_shell: dash.cmxa ast_json.mli ast_json.ml json_to_shell.ml
	ocamlfind ocamlopt -g -thread -package threads,str,atdgen,ctypes,ctypes.foreign -linkpkg -cclib -L$(BUILD) -cclib -ldash $^ -o $@

ast_json.mli: ast_json.ml

ast_json.ml : ast_atd.atd
	atdgen -j -j-std ast_atd.atd
	sed -i -e '/type char = Ast.char/d' ast_atd_j.ml
	sed -i -e '/type char = Ast.char/d' ast_atd_j.mli
	mv ast_atd_j.ml $@
	mv ast_atd_j.mli $(subst ml,mli,$@)

dash.cmxa : dash.mli dash.ml ast.mli ast.ml
	ocamlfind ocamlmklib -g -package str,ctypes,ctypes.foreign -L$(BUILD) -ldash $^ -o dash

test : $(wildcard ../test/*)
	@type json_to_shell >/dev/null 2>&1 && type shell_to_json >/dev/null 2>&1 || $(MAKE) json_to_shell shell_to_json
	@find ../test/tests ../test/pash_tests -type f | while read f; do ../test/round_trip.sh ./rt.sh "$$f"; done | tee ocaml.log
	@cat ocaml.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c
	@grep ':' ocaml.log && echo "FAILED" && exit 1 || exit 0

clean :
	rm -f *.o *.cmo *.cmi *.cmx dash.a dash.cma dash.cmxa
