.PHONY:  test clean

test: rt.py ast.py ast2shell.py dash.py parse_to_ast.py
	@for f in ../test/tests/*; do \
		LD_LIBRARY_PATH=. ../test/round_trip.sh ./rt.py $$f; \
	done

# Clean
clean:
	rm *.o *.so *.log
