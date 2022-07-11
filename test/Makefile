SCRIPTS_DIR=$(PASH_TOP)

PYTHON_FILES=../python/rt.py $(addprefix ../libdash/,__init__.py _dash.py ast.py parser.py printer.py)
OCAML_FILES=../ocaml/rt.sh

.PHONY : test clean

test: test_ocaml_python.sh $(PYTHON_FILES) $(OCAML_FILES)
	@echo "LOCAL TESTS"
	@find tests -type f | while read f; do ./test_ocaml_python.sh "$$f"; done | tee ocaml_python.log

	@echo "PASH TESTS"
	@find pash_tests -type f | while read f; do ./test_ocaml_python.sh "$$f"; done | tee -a ocaml_python.log
	@cat ocaml_python.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c

clean :
	rm -f ocaml_python.log
