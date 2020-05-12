BUILD=$(abspath ../_build/lib)

.PHONY : all install clean

all : dash.cmxa dash.cma META

install : all
	ocamlfind install libdash META dash.cmxa dash.cma dash.a dash.mli dash.cmi dash.cmo dash.cmx ast.mli ast.cmi ast.cmo ast.cmx

META : mk_meta.sh
	./mk_meta.sh

dash.cmxa : dash.mli dash.ml ast.mli ast.ml
	ocamlfind ocamlmklib -g -package str,ctypes,ctypes.foreign -L$(BUILD) -ldash $^ -o dash

test : test.native test.byte $(wildcard ../test/tests/*)
	@echo "TESTING test.native"
	@for f in ../test/tests/*; do \
		LD_LIBRARY_PATH=$(BUILD) ../test/round_trip.sh ./test.native $$f 2>test.err; \
	done
	@echo "TESTING test.byte"
	@for f in ../test/tests/*; do \
		LD_LIBRARY_PATH=$(BUILD) ../test/round_trip.sh ./test.byte $$f 2>test.err; \
	done

test.native : test.ml dash.cmxa
	LD_LIBRARY_PATH=$(BUILD) ocamlfind ocamlopt -g -package str,ctypes,ctypes.foreign -linkpkg -ccopt -L$(BUILD) -ccopt -Wl,-rpath -ccopt -Wl,$(BUILD) -cclib -ldash dash.cmxa test.ml -o $@

test.byte : test.ml dash.cmxa
	LD_LIBRARY_PATH=$(BUILD) ocamlfind ocamlc -g -package str,ctypes,ctypes.foreign -linkpkg -I $(BUILD) -ccopt -L$(BUILD) -dllpath $(BUILD) -cclib -ldash dash.cma test.ml -o $@

test.ml : ../test/test.ml
	cp $< $@

clean :
	rm -f *.o *.cmo *.cmi *.cmx dash.a dash.cma dash.cmxa
