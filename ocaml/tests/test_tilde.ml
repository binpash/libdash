(* Tilde prefixes in the AST. See test/test_tilde.py for the Python side,
   which has the same cases and expected strings, and for the rules (from
   dash's argstr and exptilde in src/expand.c, and POSIX XCU 2.6.1):

   - A tilde prefix starts only at the start of a word or, in an assignment,
     right after the first '=' or an unquoted ':'. Elsewhere '~' is C '~'.
   - The prefix runs to an unquoted '/' or the end of the word; in an
     assignment, an unquoted ':' also ends it.
   - If a quote, escape, or expansion interrupts the prefix, there is no
     tilde prefix: the '~' and what follows are ordinary characters. *)

open Libdash
open Ast

let parse_command (s : string) =
  Dash.setinputstring (Dash.alloc_stack_string (s ^ "\n"));
  let mark = Dash.init_stack () in
  let c = match Dash.parse_next () with
    | Dash.Parsed n -> of_node n
    | _ -> failwith ("expected one command: " ^ s)
  in
  Dash.pop_stack mark;
  (match Dash.parse_next () with Dash.Done -> () | _ -> failwith ("trailing input: " ^ s));
  Dash.popfile ();
  match c with
  | Command (_, assigns, args, redirs) -> assigns, args, redirs
  | _ -> failwith ("expected a simple command: " ^ s)

(* a compact, binding-neutral rendering of a word; same as show in the
   Python test *)
let rec show (a : arg) : string =
  String.concat ", " (List.map show_char a)
and show_char = function
  | C c -> Printf.sprintf "C '%c'" c
  | E c -> Printf.sprintf "E '%c'" c
  | T None -> "T None"
  | T (Some u) -> Printf.sprintf "T '%s'" u
  | Q a -> "Q[" ^ show a ^ "]"
  | V (_, _, x, a) -> "V " ^ x ^ "[" ^ show a ^ "]"
  | B _ -> "B"
  | A _ -> failwith "unexpected arithmetic"

let word kind text =
  let assigns, args, redirs = parse_command text in
  match kind with
  | `Arg -> show (List.nth args 1)
  | `Assign -> show (snd (List.hd assigns))
  | `Redir ->
     (match List.hd redirs with
      | File (_, _, a) | Dup (_, _, a) | Heredoc (_, _, a) -> show a)

let cases = [
  (* tilde prefixes *)
  "bare", `Arg, "echo ~", "T None";
  "home_slash", `Arg, "echo ~/a", "T None, C '/', C 'a'";
  "user_slash", `Arg, "echo ~ab/d", "T 'ab', C '/', C 'd'";
  "double_quoted", `Arg, "echo \"~\"", "Q[E '~']";
  "escaped", `Arg, "echo \\~", "E '~'";
  "assign_start", `Assign, "x=~/a", "T None, C '/', C 'a'";
  "assign_after_colon", `Assign, "x=a:~/b", "C 'a', C ':', T None, C '/', C 'b'";
  "assign_colon_ends_prefix", `Assign, "x=~a:b", "T 'a', C ':', C 'b'";
  "assign_two_colons", `Assign, "x=~a:~/c", "T 'a', C ':', T None, C '/', C 'c'";
  "var_word", `Arg, "echo ${x:-~/a}", "V x[T None, C '/', C 'a']";
  "redir_target", `Redir, "echo >~/f", "T None, C '/', C 'f'";

  (* an interrupted prefix is no prefix, and keeps its characters *)
  "interrupted_by_escape", `Arg, "echo ~ab\\c", "C '~', C 'a', C 'b', E 'c'";
  "interrupted_by_quote", `Arg, "echo ~ab\"c\"", "C '~', C 'a', C 'b', Q[C 'c']";
  "interrupted_by_var", `Arg, "echo ~ab$x", "C '~', C 'a', C 'b', V x[]";
  "interrupted_by_backquote", `Arg, "echo ~ab`c`", "C '~', C 'a', C 'b', B";
  "interrupted_right_away", `Arg, "echo ~\\c", "C '~', E 'c'";
  "interrupted_in_assign", `Assign, "x=~ab\\c", "C '~', C 'a', C 'b', E 'c'";

  (* a tilde prefix only at the start of a word (or after = and : in an
     assignment) *)
  "mid_word", `Arg, "echo a~b", "C 'a', C '~', C 'b'";
  "after_slash", `Arg, "echo ~/a~b", "T None, C '/', C 'a', C '~', C 'b'";
  "after_colon_not_assign", `Arg, "echo a:~/b", "C 'a', C ':', C '~', C '/', C 'b'";
  "mid_assign", `Assign, "x=a~b", "C 'a', C '~', C 'b'";
  "mid_var_word", `Arg, "echo ${x:-a~b}", "V x[C 'a', C '~', C 'b']";
  "mid_redir_target", `Redir, "echo >a~b", "C 'a', C '~', C 'b'";

  (* outside assignments, ':' is part of the prefix *)
  "colon_in_prefix", `Arg, "echo ~a:b", "T 'a:b'";
]

let () =
  Dash.initialize ();
  let failed =
    List.filter (fun (name, kind, text, expected) ->
        match word kind text with
        | got when got = expected -> print_endline ("OK " ^ name); false
        | got ->
           Printf.printf "FAIL %s: %s\n  got      %s\n  expected %s\n" name text got expected;
           true
        | exception e ->
           Printf.printf "FAIL %s: %s\n  raised %s\n" name text (Printexc.to_string e);
           true)
      cases
  in
  Printf.printf "%d/%d failed\n" (List.length failed) (List.length cases);
  if failed <> [] then exit 1
