(* Line numbers on AST nodes. See test/test_linno.py for the Python side,
   which has the same cases.

   Every node that carries a linno (Command, Redir, Background, Subshell,
   For, Case, Defun) should report the line its construct starts on. Each
   case lists those nodes in source (pre-)order, as (kind, linno).

   For Background, `cmd &` wraps any command that is not already an NPIPE or
   NREDIR in a fresh nredir (list() in src/parser.c), which must get the
   line the backgrounded command starts on; an uninitialized linno shows up
   as 0 in a fresh process and garbage later. *)

open Libdash
open Ast

let parse_string (s : string) : t list =
  Dash.setinputstring (Dash.alloc_stack_string s);
  let rec go acc =
    let mark = Dash.init_stack () in
    match Dash.parse_next () with
    | Dash.Done -> Dash.pop_stack mark; Dash.popfile (); List.rev acc
    | Dash.Error -> Dash.pop_stack mark; Dash.popfile (); failwith "parse error"
    | Dash.Null -> Dash.pop_stack mark; go acc
    | Dash.Parsed n ->
       let c = of_node n in
       Dash.pop_stack mark; go (c :: acc)
  in
  go []

(* (kind, linno) for every linno-carrying node, in pre-order, descending into
   words (command substitutions); same order as the Python walk *)
let rec node (n : t) : (string * int) list =
  match n with
  | Command (l, assigns, args, rs) ->
     ("Command", l) ::
       List.concat_map (fun (_, a) -> arg a) assigns
       @ List.concat_map arg args @ redirs rs
  | Pipe (_, cs) -> List.concat_map node cs
  | Redir (l, c, rs) -> ("Redir", l) :: node c @ redirs rs
  | Background (l, c, rs) -> ("Background", l) :: node c @ redirs rs
  | Subshell (l, c, rs) -> ("Subshell", l) :: node c @ redirs rs
  | Not c -> node c
  | And (a, b) | Or (a, b) | Semi (a, b) | While (a, b) -> node a @ node b
  | If (a, b, c) -> node a @ node b @ node c
  | For (l, args, body, _) -> ("For", l) :: List.concat_map arg args @ node body
  | Case (l, a, cases) ->
     ("Case", l) :: arg a
     @ List.concat_map (fun c -> List.concat_map arg c.cpattern @ node c.cbody) cases
  | Defun (l, _, body) -> ("Defun", l) :: node body
and redirs rs =
  List.concat_map (function File (_, _, a) | Dup (_, _, a) | Heredoc (_, _, a) -> arg a) rs
and arg a = List.concat_map arg_char a
and arg_char = function
  | C _ | E _ | T _ -> []
  | A a | Q a | V (_, _, _, a) -> arg a
  | B n -> node n

let filler n =
  String.concat "" (List.init n (fun i -> Printf.sprintf "echo %d\n" (i + 1)))

let c l = ("Command", l)
let r l = ("Redir", l)
let bg l = ("Background", l)
let s l = ("Subshell", l)
let f l = ("For", l)
let k l = ("Case", l)
let d l = ("Defun", l)

let cases = [
  (* constructs without & *)
  "simple", "echo a\necho b\n", [c 1; c 2];
  "semi", "a; b\nc\n", [c 1; c 1; c 2];
  "continuation", "echo a \\\n  b\necho c\n", [c 1; c 3];
  "comments", "# c\n\necho a # trailing\n\n# c\necho b\n", [c 3; c 6];
  "pipe", "a |\n  b\n", [c 1; c 2];
  "if", "if true\nthen\n  echo y\nelse\n  echo n\nfi\n", [c 1; c 3; c 5];
  "for", "for x in a b\ndo\n  echo $x\ndone\n", [f 1; c 3];
  "case", "case $x in\n  a) echo a ;;\n  b)\n    echo b ;;\nesac\n", [k 1; c 2; c 4];
  "defun", "f() {\n  echo f\n}\ng()\n{\n  echo g\n}\n", [d 1; c 2; d 4; c 6];
  "subshell", "(\n  echo a\n)\n", [s 1; c 2];
  "redir", "{\n  echo a\n} >/dev/null\nwhile true\ndo echo w\ndone 2>&1\n",
  [r 1; c 2; r 4; c 4; c 5];
  "heredoc", "cat <<EOF\nx\ny\nEOF\necho after\n", [c 1; c 5];
  "cmdsubst", "echo $(\n  echo inner\n)\necho after\n", [c 1; c 2; c 4];
  "backquote", "echo `echo inner`\n", [c 1; c 1];

  (* Background *)
  "bg_first_line", "sleep 1 &\n", [bg 1; c 1];
  (* deep enough into a parse that stale stack holds nonzero garbage *)
  "bg_after_30_lines", filler 30 ^ "sleep 1 &\n",
  List.init 30 (fun i -> c (i + 1)) @ [bg 31; c 31];
  (* the wrapped NAND has no linno of its own *)
  "bg_and_list", "a && b &\n", [bg 1; c 1; c 1];
  "bg_brace_group", "echo 1\n{\n  echo a\n  echo b\n} &\n", [c 1; bg 2; c 3; c 4];
  "bg_subshell", "( echo a ) &\n", [bg 1; s 1; c 1];
  "bg_two_on_one_line", "a & b &\n", [bg 1; c 1; bg 1; c 1];
  "bg_in_function", "f() {\n  sleep 1 &\n}\n", [d 1; bg 2; c 2];
  (* an NREDIR is retyped in place and keeps its own linno *)
  "bg_already_nredir", "{ echo a; } >/dev/null &\n", [bg 1; c 1];
]

let show l =
  "[" ^ String.concat "; " (List.map (fun (k, l) -> Printf.sprintf "%s %d" k l) l) ^ "]"

let () =
  Dash.initialize ();
  let failed =
    List.filter (fun (name, script, expected) ->
        let got = List.concat_map node (parse_string script) in
        if got = expected
        then (print_endline ("OK " ^ name); false)
        else (Printf.printf "FAIL %s:\n  got      %s\n  expected %s\n"
                name (show got) (show expected);
              true))
      cases
  in
  Printf.printf "%d/%d failed\n" (List.length failed) (List.length cases);
  if failed <> [] then exit 1
