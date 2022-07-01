MAKE_PATH:=$(abspath $(lastword $(MAKEFILE_LIST)))
CWD:=$(patsubst %/,%,$(dir $(MAKE_PATH)))

DASH_DIR=$(CWD)/../src/.libs
SCRIPTS_DIR=$(PASH_TOP)

LDFLAGS=-ljson-c -L"$(JSON_C_DIR)/lib" -Wl,-rpath -Wl,"$(JSON_C_DIR)/lib"
DASH_LDFLAGS=-ldash -L"$(DASH_DIR)" -Wl,-rpath -Wl,"$(DASH_DIR)"

.PHONY: all test clean

test: test_roundtrip.log

# Tests comparing OCaml and Python
test_roundtrip.log: test_rt.sh ast.py ast2shell.py dash.py parse_to_ast.py
	@echo "LOCAL TESTS"
	@find "../test" | grep '[.]sh$$' | while read f; do sh test_rt.sh "$$f"; done | tee $@
	@echo
	@cat $@ | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c

	@find "$(SCRIPTS_DIR)" | grep '[.]sh$$' | while read f; do sh test_rt.sh "$$f"; done | tee $@
	@echo
	@cat $@ | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c

# Clean
clean:
	rm *.o *.so *.log
