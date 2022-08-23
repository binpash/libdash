[![Main workflow](https://github.com/mgree/libdash/actions/workflows/build.yml/badge.svg)](https://github.com/mgree/libdash/actions/workflows/build.yml)

*libdash* is a fork of the Linux Kernel's `dash` shell that builds a linkable library with extra exposed interfaces. The primary use of libdash is to parse shell scripts, but it could be used for more.

The Python bindings are packaged as the [`libdash` PyPi package](https://pypi.org/project/libdash/).

The OCaml bindings---packaged as the [`libdash` OPAM package](https://opam.ocaml.org/packages/libdash/)---include two executables, `shell_to_json` and `json_to_shell`, which let you conveniently parse POSIX shell scripts into a JSON AST.

# What are the dependencies?

The C code for dash should build on a wide variety of systems; it requires `libtool` and `autotools` (`aclocal`, `autoheader`, `automake`, `autoconf`). The library may not build on platforms with esoteric linkers; it's been tested on macOS and Linux.

The Python and OCaml bindings depend on being able to build the C code. See `libdash.opam` for details on the OCaml code's dependencies, which includes the build-time external dependencies. Python wheels have no need for these build-time dependencies, but building from a Python source distribution will only succeed when `libtool` and `autotools` are present.

The CI scripts (in `.github/workflows/build.yml`) give build details.

## How to build `libdash` from source

### Python

Run `python3 setup.py install`. On macOS, you must first install the build dependencies via `brew install libtool autoconf automake`.

You can test the Python bindings by running:

```
cd python; make test
```

### OCaml

Install the OPAM file: `opam pin add .` or `opam install .`. This will build the OCaml library and install it in your OPAM repository. There are tests in another directory; they will only build when libdash is actually installed.

You can test the OCaml bindings by running:

```
cd ocaml; make test
```

### Testing

The tests use `test/round_trip.sh` to ensure that every tester file in `test/tests` round-trips correctly through parsing and pretty printing.

Additionally, you can run tests that compare the OCaml and Python implementations (after you've installed them both):

```
cd test; make
```

# How to use the parser

For Python, see [`python/rt.py`](https://github.com/mgree/libdash/blob/master/python/rt.py), an example tool that does a round-trip: shell syntax to AST back to shell syntax.

For OCaml, see [`ocaml/shell_to_json.ml`](https://github.com/mgree/libdash/blob/master/ocaml/shell_to_json.ml), a tool that parses shell syntax and produces JSON (using the [atdgen](https://opam.ocaml.org/packages/atdgen/) bindings).

The ideal low-level interface to use is `parsecmd_safe` in `parser.c`; you'll need to ensure that dash's initialization routines have been called and that the stack marks are managed correctly. Parsing the POSIX shell is a complicated affair: beyond the usual locale issues, aliases affect the lexer, so one must use `setalias` and `unalias` to manage any aliases that ought to exist.

# How work with the parsed nodes

The general AST is described in `nodes.h`. There are some tricky invariants around the precise formatting of control codes; the OCaml code shows some examples of working with the `args` fields in `ocaml/ast.ml`, which converts the C AST to an OCaml AST.

The OCaml tools `shell_to_json` and `json_to_shell` will produce JSON ASTs, allowing you to work with these ASTs in any language.

# Pretty printing

The pretty printer does its best to produce valid shell scripts, but it's possible to manually construct AST nodes that don't directly correspond to valid scripts.

For example, the Python AST `[[['Q', [['C', 34]]]]]` represents a quoted field containing a double quote character. Translated literally, this would yield the string `"""`, which is not a valid shell script. The pretty printer will instead automatically escape the inner quote, rendering `"\""`.

While the printer tries to get things right either way, you should use escapes to signal to the printer when to escape: you should use the Python AST `[[['Q', [['E', 34]]]]]` to mark the inner double quote as escaped.

# Known issues

We currently do not escape the character `!` (exclamation point). In an interactive shell, `!` is likely treated as a history substitution (and so should be escaped), but in a non-interactive shell, `!` is treated normally. We currently cater to non-interactive shells; eventually this behavior will be controllable.
