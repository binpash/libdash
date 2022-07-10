There are three directories of tests:

  - `tests` are the original libdash tests, mostly handwritten
  - `pash_tests` are shell scripts taken from [`pash`](https://github.com/binpash/pash)
  - `failing` are shell scripts that aren't working right now (which is probably a bug)
  
Both OCaml and Python bindings use the `round_trip.sh` to test round tripping. The `test_ocaml_python.sh` script compares the output from Python and OCaml.
