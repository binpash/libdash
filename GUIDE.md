# The dash AST

The dash AST itself is defined in `src/nodes.h` and `src/parser.h`

- `union node` in `src/nodes.h` on line 146 for commands/statements
  node.type type tag
  
  node.nbinary (AND, OR, SEMI)
  
- special characters and codes in `parser.h` on lines 40-64

  CTL* for control codes in words
    breaks multibyte characters/UTF-8 :(
    
  VS* for variable format metadata

The parser in `src/parser.c` is not easy to read, but is a good place
to see dash ASTs being constructed.

Input sources come in a stack (to support, e.g., the `source`/`.`
command). Dash has some subtle invariants around its own string
allocation stack... it took quite some time to get it right in Smoosh,
so don't try to "optimize" things! (See
https://github.com/mgree/smoosh/pull/18 for test cases.)

To get a gist for how they're used, look at `evaltree` at line 200 in
`src/eval.c`. To see how the special characters and codes are used,
see `argstr` at line 23 in `src/expand.c`.

# OCaml bindings

The core OCaml bindings are in `ocaml/dash.ml`. The bindings are
dynamically loaded by ctypes. (It's a longstanding TODO to make these
bindings static, as it would significantly simplify the build process.)

Lines 69 through 233 are just copying the definitions from
`src/nodes.h`.

The primary API entry point is `parse_next`, which returns one of a
few results:

  - `Done` when EOF (dash returns the special node `neof`, not `NULL`!) has been
    reached for the current input.
    
  - `Error` when parsing failed (dash returns the special node `nerr`,
    not `NULL`!).
    
  - `Null` when there was no command, e.g., a blank line (dash returns
    `NULL` here).
    
  - `Parsed n` for some `node`, `n`. Note that `n` is a dash AST,
    i.e., a ctypes structure.

These nodes are dash AST nodes not yet a usable OCaml structure.

# AST translation

See `ocaml/ast.ml` (or Smoosh's `src/shim.ml` for a more
battle-hardened, nearly but not quite identical version of the same
code) for the `of_node` entry point that converts dash AST nodes to
OCaml structures.

`parse_arg` is a funny a stack machine, best thought of as a for loop
with an explicit stack. There are some tricky extra bits of
information to track (i.e., when tildes are possible, whether we're in
an assignment).

# General approach

Call `Dash.initialize`, then `Dash.parse` with the string you
have. Call `Ast.of_node` on the resulting dash AST to get a nice OCaml
structure.
