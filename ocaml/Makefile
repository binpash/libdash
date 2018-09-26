DASH=..

OCAMLLIB=$(shell opam config var lib)
OCAMLINCLUDES=-I $(OCAMLLIB)/bytes -I $(OCAMLLIB)/ctypes
OCAMLLIBS=unix.cmxa bigarray.cmxa str.cmxa ctypes.cmxa ctypes-foreign-base.cmxa ctypes-foreign-unthreaded.cmxa

all : test.native dash.cmxa

test : test.native $(wildcard tests/*)
	@for f in tests/*; do \
		./round_trip.sh ./test.native $$f 2>test.err; \
	done


test.native : dash.cmx ast.cmx main.cmx 
	ocamlopt.opt -cclib -force_load $(DASH)/src/libdash.a $(OCAMLINCLUDES) $(OCAMLLIBS) $^ -o $@


dash.cmxa : dash.cmx ast.cmx $(DASH)/src/libdash.a
	ocamlopt.opt -cclib -force_load $(DASH)/src/libdash.a $(OCAMLINCLUDES) $^ -a -o $@

%.cmx : %.ml
	ocamlopt.opt $(OCAMLINCLUDES) -c $< -o $@

%.cmi : %.mli
	ocamlopt.opt $(OCAMLINCLUDES) -c $< -o $@

clean :
	rm -f *.o test *~ *.cmi *.cmx test.native dash.a dash.cmxa
	rm -rf _build

# ocamldep output
ast.cmx : dash.cmx ast.cmi
ast.cmi : dash.cmi
dash.cmx : dash.cmi
main.cmx : dash.cmx ast.cmx
