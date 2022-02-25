MAKE_PATH:=$(abspath $(lastword $(MAKEFILE_LIST)))
CWD:=$(patsubst %/,%,$(dir $(MAKE_PATH)))

DASH_DIR=$(CWD)/../src/.libs
JSON_C_DIR=$(CWD)/json-c-0.15/install
SCRIPTS_DIR=~/pash/

CC=gcc
CFLAGS=-fPIC -g -O2 -Wall -Werror -I"$(JSON_C_DIR)/include/json-c" -I"../src"
LDFLAGS=-ljson-c -L"$(JSON_C_DIR)/lib" -Wl,-rpath -Wl,"$(JSON_C_DIR)/lib"
DASH_LDFLAGS=-ldash -L"$(DASH_DIR)" -Wl,-rpath -Wl,"$(DASH_DIR)"

.PHONY: all clean

all: parse_to_json json_to_shell libdash.so

json-c-0.15/install/lib: json-c-0.15/build/Makefile
	mkdir -p $@
	$(MAKE) -C json-c-0.15/build install

json-c-0.15/build/Makefile:
	mkdir -p json-c-0.15/build 
	(cd json-c-0.15/build; cmake -DCMAKE_INSTALL_PREFIX=../install ..)

# C binaries
parse_to_json: json-c-0.15/install/lib parse_to_json.o ast.o ast2json.o dash.o Stack.o arg_char.o ArgCharStack.o
	echo JSON_C_DIR=$(JSON_C_DIR) PWD=$(PWD)
	$(CC) $(CFLAGS) $(filter-out json-c-0.15/install/lib,$^) -o $@ $(LDFLAGS) $(DASH_LDFLAGS)
	if [ $(shell uname) = "Darwin" ]; then install_name_tool -change "libjson-c.5.dylib" "@loader_path/json-c-0.15/install/lib/libjson-c.5.dylib" $@; fi

json_to_shell: json-c-0.15/install/lib json_to_shell.o pretty.o
	$(CC) $(CFLAGS) $(filter-out json-c-0.15/install/lib,$^) -o $@ $(LDFLAGS)
	if [ $(shell uname) = "Darwin" ]; then install_name_tool -change "libjson-c.5.dylib" "@loader_path/json-c-0.15/install/lib/libjson-c.5.dylib" $@; fi

#prettyprint_json: prettyprint_json.o
#	$(CC) $(CFLAGS) $^ -o $@ $(LDFLAGS)


# Shared objects
libdash.so: dash.o
	$(CC) -shared $^ -o $@ $(LDFLAGS) $(DASH_LDFLAGS)


# Tests for C binaries
testsA: parse_to_json
	@find "$(SCRIPTS_DIR)" | grep '[.]sh$$' | while read f; do sh test_parse_to_JSON2.sh "$$f"; done | tee /tmp/cdashA.log
	@echo
	@cat /tmp/cdashA.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c

testsB: json_to_shell
	@find "$(SCRIPTS_DIR)" | grep '[.]sh$$' | while read f; do sh test_JSON_to_shell2.sh "$$f"; done | tee /tmp/cdashB.log
	@echo
	@cat /tmp/cdashB.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c

testsRT: test_rt.sh parse_to_json json_to_shell
	@find "$(SCRIPTS_DIR)" | grep '[.]sh$$' | while read f; do sh test_rt.sh "$$f"; done | tee /tmp/cdash_rt.log
	@echo
	@cat /tmp/cdash_rt.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c

# Tests for Python scripts
testsRT_py: test_rt_py.sh
	@find "$(SCRIPTS_DIR)" | grep '[.]sh$$' | while read f; do sh test_rt_py.sh "$$f"; done | tee /tmp/cdash_rt_py.log
	@echo
	@cat /tmp/cdash_rt_py.log | egrep '^[A-Z0-9_]+:' | cut -d ':' -f 1 | sort | uniq -c


# Clean
clean:
	rm parse_to_json json_to_shell *.o *.so
veryclean: clean
	rm -r $(JSON_C_DIR)/install $(JSON_C_DIR)/build
