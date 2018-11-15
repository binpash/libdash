.PHONY : all test clean

all : test.native

test : test.native $(wildcard tests/*)
	@for f in tests/*; do \
		./round_trip.sh ./test.native $$f 2>test.err; \
	done

test.native : test.ml
	ocamlfind ocamlopt -package dash,ctypes,ctypes.foreign -linkpkg test.ml -o test.native

clean :
	rm -f *.o *.cmi *.cmx test.native test.err
