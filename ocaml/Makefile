.PHONY : all install clean

all : dash.cmxa dash.cma META

install : all
#	if ocamlfind query libdash; then ocamlfind remove libdash; fi
	ocamlfind install libdash META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx

META : mk_meta.sh
	./mk_meta.sh

dash.cmxa : dash.mli dash.ml ast.mli ast.ml
	ocamlfind ocamlmklib -g -package str,ctypes,ctypes.foreign -dllpath `opam var lib`/libdash $^ -o dash

clean :
	rm -f *.o *.cmo *.cmi *.cmx dash.a dash.cma dash.cmxa
