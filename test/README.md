There are four directories of tests:

  - `tests` are the original libdash tests, mostly handwritten
  - `pash_tests` are shell scripts taken from [`pash`](https://github.com/binpash/pash)
  - `failing` are shell scripts that aren't working right now (which is probably a bug)
  - `line_mapping` holds fixtures for the per-node source line mapping, each with a
    `.expected` golden
  
Both OCaml and Python bindings use the `round_trip.sh` to test round tripping, i.e., that `print . parse` reaches a fixpoint.
It cannot compare against the original source, since the AST drops comments, whitespace and quoting style.
The `test_ocaml_python.sh` script ensures that Python and OCaml round-trip to the same output (or fail together).

Round trip tests, however, can hide important bugs.
Two other tests check parses more concretely.

`check_structs.py` checks the ctypes mirrors in `libdash/_dash.py` against
dash's real structs, comparing `sizeof` and every field offset via a probe
compiled from `src/*.h`. 
This test needs a C compiler and a built tree.
This test only runs on the Python code, as OCaml's ctypes automatically computes offsets, but `_dash.py` hand-writes them.

`line_mapping.sh` covers source line mapping (`parsedLines`, `linno_before`, `linno_after`).
It runs `python/dump.py --ranges` over each fixture and diffs against the `.expected` output.
Run `REGEN=1 ./line_mapping.sh` to automatically update the expected output after an intentional change.
