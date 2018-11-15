[![Build Status](https://travis-ci.com/mgree/libdash.svg?branch=master)](https://travis-ci.com/mgree/libdash)

*libdash* is a fork of the Linux Kernel's `dash` shell that builds a linkable library with extra exposed interfaces. The primary use of libdash is to parse shell scripts, but it could be used for more.

# What are the dependencies?

The C code for dash should build on a wide variety of systems. The library may not build on platforms with esoteric linkers; it's been tested on OS X.

The OCaml code relies on `ctypes-0.11.5` and `ctypes-foreign`; everything else should be in `base`.

# How to build it

In the root directory run:

```
./autogen.sh && ./configure && make
```

This should construct an executable `src/dash` and a static library `src/libdash.a`.

Then run:

```
cd ocaml; make
```

This will build the OCaml library `ocaml/dash.mxa` along with a tester, `ocaml/test.native`. You can then run (still in the `ocaml` directory):

```
make test
```

Which will use `ocaml/round_trip.sh` to ensure that every tester file in `ocaml/tests` round-trips correctly through parsing and pretty printing.

# How to use the parser

The ideal interface to use is `parsecmd_safe` in `parser.c`. Parsing the POSIX shell is a complicated affair: beyond the usual locale issues, aliases affect the lexer, so one must use `setalias` and `unalias` to manage any aliases that ought to exist.

# How work with the parsed nodes

The general AST is described in `nodes.h`. There are some tricky invariants around the precise formatting of control codes; the OCaml code shows some examples of working with the `args` fields in `ocaml/ast.ml`, which converts the C AST to an OCaml AST.
