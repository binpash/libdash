DASH=$(shell (cd ../dash; pwd))
DASHSRC=$(DASH)/src

TESTING : main.native $(wildcard tests/*)
	@for f in tests/*; do \
		./round_trip.sh ./main.native $$f 2>test.err; \
	done

main.native : main.ml dash.ml ast.ml compile.ml
	ocamlbuild -no-hygiene -pkg ctypes.foreign -lflags "-cclib -force_load $(DASH)/libdash.a" $@

test : test.c
	gcc -Wall -I $(DASHSRC) -L $(DASH) -ldash $^ -o $@

clean :
	rm -f *.o test *~ *.cmi *.cmx main.native
	rm -rf _build
