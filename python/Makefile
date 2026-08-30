.PHONY:  test test-roundtrip test-line-mapping clean

test: test-roundtrip test-line-mapping

test-roundtrip: rt.py ../libdash/*.py
	@find ../test/tests ../test/pash_tests -type f | while read f; do ../test/round_trip.sh ./rt.py "$$f"; done | tee python.log
	@cat python.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c
	@grep ':' python.log && echo "FAILED" && exit 1 || exit 0

# Per-node line mapping; round_trip.sh cannot see it (rt.py uses only the AST).
test-line-mapping: dump.py ../libdash/*.py
	@../test/line_mapping.sh

clean:
	rm *.o *.so *.log
