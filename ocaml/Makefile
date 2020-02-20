.PHONY : all install clean

all : dash.cmxa dash.cma META

install : all
#	if ocamlfind query libdash; then ocamlfind remove libdash; fi
	ocamlfind install libdash META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx

META : mk_meta.sh
	./mk_meta.sh

dash.cmxa : dash.mli dash.ml ast.mli ast.ml
	ocamlfind ocamlmklib -g -package str,ctypes,ctypes.foreign -dllpath `opam var lib`/libdash $^ -o dash

test : test.native test.byte $(wildcard ../test/tests/*)
	@echo "TESTING test.native"
	@for f in ../test/tests/*; do \
		../test/round_trip.sh ./test.native $$f 2>test.err; \
	done
	@echo "TESTING test.byte"
	@for f in ../test/tests/*; do \
		../test/round_trip.sh ./test.byte $$f 2>test.err; \
	done

BUILD=$(abspath ../_build/lib)

test.native : test.ml dash.cmxa
	ocamlfind ocamlopt -g -package str,ctypes,ctypes.foreign -linkpkg -ccopt -L$(BUILD) -ccopt -Wl,-rpath -ccopt -Wl,$(BUILD) dash.cmxa test.ml -o $@

test.byte : test.ml dash.cmxa
	ocamlfind ocamlc -g -package str,ctypes,ctypes.foreign -linkpkg -I $(BUILD) -ccopt -L$(BUILD) -dllpath $(BUILD) dash.cma test.ml -o $@

test.ml : ../test/test.ml
	cp $< $@

clean :
	rm -f *.o *.cmo *.cmi *.cmx dash.a dash.cma dash.cmxa
