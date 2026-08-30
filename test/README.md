There are four directories of tests:

  - `tests` are the original libdash tests, mostly handwritten
  - `pash_tests` are shell scripts taken from [`pash`](https://github.com/binpash/pash)
  - `failing` are shell scripts that aren't working right now (which is probably a bug)
  - `line_mapping` holds fixtures for the per-node source line mapping, each with a
    `.expected` golden
  
Both OCaml and Python bindings use the `round_trip.sh` to test round tripping. The `test_ocaml_python.sh` script compares the output from Python and OCaml.

`round_trip.sh` checks that `print . parse` reaches a fixpoint. It cannot
compare against the original source, since the AST drops comments, whitespace
and quoting style -- which leaves the source line mapping (`parsedLines`,
`linno_before`, `linno_after`) uncovered, as `rt.py` discards it and prints only
the AST. `line_mapping.sh` covers that: it runs `python/dump.py --ranges` over
each fixture and diffs against the golden. `REGEN=1 ./line_mapping.sh` updates
the goldens after an intentional change.
