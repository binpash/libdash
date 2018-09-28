.PHONY : all install clean

all : dash.cmxa

install : all
	ocamlfind install dash META dash.cmxa dash.a dash.mli dash.cmi dash.cmx ast.mli ast.cmi ast.cmx

dash.cmxa : dash.mli dash.ml ast.mli ast.ml
	ocamlfind ocamlmklib -package ctypes,ctypes.foreign -linkpkg -cclib -ldash $^ -o dash

clean :
	rm -f *.o *.cmi *.cmx dash.a dash.cmxa
