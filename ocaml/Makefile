.PHONY : all install clean

all : dash.cmxa dash.cma

install : all
	if ocamlfind query libdash; then ocamlfind remove libdash; fi
	ocamlfind install libdash META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx

dash.cmxa : dash.mli dash.ml ast.mli ast.ml
	ocamlfind ocamlmklib -g -package ctypes,ctypes.foreign $^ -o dash

clean :
	rm -f *.o *.cmo *.cmi *.cmx dash.a dash.cma dash.cmxa
