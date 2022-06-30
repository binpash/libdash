MAKE_PATH:=$(abspath $(lastword $(MAKEFILE_LIST)))
CWD:=$(patsubst %/,%,$(dir $(MAKE_PATH)))

DASH_DIR=$(CWD)/../src/.libs
SCRIPTS_DIR=$(HOME)/pash

LDFLAGS=-ljson-c -L"$(JSON_C_DIR)/lib" -Wl,-rpath -Wl,"$(JSON_C_DIR)/lib"
DASH_LDFLAGS=-ldash -L"$(DASH_DIR)" -Wl,-rpath -Wl,"$(DASH_DIR)"

.PHONY: all test clean

test: test_python_roundtrip.log

# Tests comparing OCaml and Python
test_python_roundtrip.log: test_rt_py.sh
	@find "$(SCRIPTS_DIR)" | grep '[.]sh$$' | while read f; do sh test_rt_py.sh "$$f"; done | tee $@
	@echo
	@cat $@ | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c

# Clean
clean:
	rm *.o *.so *.log
