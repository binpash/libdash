.PHONY : all install clean

all : dash.cmxa dash.cma

install : all
	if ocamlfind query dash; then ocamlfind remove dash; fi
	ocamlfind install dash META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx

dash.cmxa : dash.mli dash.ml ast.mli ast.ml
	ocamlfind ocamlmklib -g -package ctypes,ctypes.foreign -ccopt -Wl,-rpath=`ocamlfind query libdash` -cclib -ldash $^ -o dash

clean :
	rm -f *.o *.cmo *.cmi *.cmx dash.a dash.cma dash.cmxa
