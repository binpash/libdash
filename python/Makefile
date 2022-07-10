.PHONY:  test clean

test: rt.py ast.py ast2shell.py dash.py parse_to_ast.py
	@find ../test/tests ../test/pash_tests -type f | while read f; do ../test/round_trip.sh ./rt.py "$$f"; done | tee python.log
	@cat python.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c
	@grep ':' python.log && echo "FAILED" && exit 1 || exit 0

clean:
	rm *.o *.so *.log
