DASH=$(shell (cd ../dash; pwd))
DASHSRC=$(DASH)/src

OCAMLLIB=$(shell opam config var lib)
OCAMLINCLUDES=-I $(OCAMLLIB)/bytes -I $(OCAMLLIB)/ctypes -I /usr/local/lib/ocaml
OCAMLLIBS=unix.cmxa bigarray.cmxa str.cmxa ctypes.cmxa ctypes-foreign-base.cmxa ctypes-foreign-unthreaded.cmxa

test : main.native $(wildcard tests/*)
	@for f in tests/*; do \
		./round_trip.sh ./main.native $$f 2>test.err; \
	done


#/usr/local/bin/ocamlopt.opt -cclib -force_load /Users/mgree/fsh/dash/libdash.a -I /Users/mgree/.opam/coq-8.4/lib/bytes -I /Users/mgree/.opam/coq-8.4/lib/ctypes -I /usr/local/lib/ocaml /usr/local/lib/ocaml/unix.cmxa /usr/local/lib/ocaml/bigarray.cmxa /usr/local/lib/ocaml/str.cmxa /Users/mgree/.opam/coq-8.4/lib/ctypes/ctypes.cmxa /Users/mgree/.opam/coq-8.4/lib/ctypes/ctypes-foreign-base.cmxa /Users/mgree/.opam/coq-8.4/lib/ctypes/ctypes-foreign-unthreaded.cmxa dash.cmx ast.cmx compile.cmx main.cmx -o main.native

main.native : dash.cmx ast.cmx compile.cmx main.cmx 
	ocamlopt.opt -cclib -force_load $(DASH)/libdash.a $(OCAMLINCLUDES) $(OCAMLLIBS) $^ -o $@
#	ocamlbuild -log build.log -no-hygiene -pkg ctypes.foreign -lflags "-cclib -force_load $(DASH)/libdash.a" $@

dash.cmxa : dash.cmx ast.cmx compile.cmx
	ocamlopt.opt -cclib -force_load $(DASH)/libdash.a $(OCAMLINCLUDES) $^ -a -o $@

%.cmx : %.ml
	ocamlopt.opt $(OCAMLINCLUDES) -c -o $@ $<

clean :
	rm -f *.o test *~ *.cmi *.cmx main.native dash.a dash.cmxa
	rm -rf _build
