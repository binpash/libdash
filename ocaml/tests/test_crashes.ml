(* Regression tests for crashes in libdash's exported C entry points, seen
   through the OCaml binding. See test/test_crashes.py for the Python side.

   Each case is run in its own process (see dune): a bad longjmp kills the
   process, and libdash keeps global state between calls.

   1. parsecmd_safe left `handler` pointing at its own (dead) jmploc, so a
      later sh_error, e.g., from setinputfile on a missing file, longjmp'd
      into a dead frame. Before the first parse, `handler` was NULL.
   2. Dash.setalias was bound straight to C setalias, which expects a whole
      "name=value" buffer rather than two strings. *)

open Libdash

let parse_string (s : string) : string list =
  Dash.setinputstring (Dash.alloc_stack_string s);
  let rec go acc =
    let mark = Dash.init_stack () in
    match Dash.parse_next () with
    | Dash.Done -> Dash.pop_stack mark; Dash.popfile (); List.rev acc
    | Dash.Error -> Dash.pop_stack mark; Dash.popfile (); failwith "parse error"
    | Dash.Null -> Dash.pop_stack mark; go acc
    | Dash.Parsed n ->
       let c = Ast.to_string (Ast.of_node n) in
       Dash.pop_stack mark; go (c :: acc)
  in
  go []

let expect_parse s expected =
  match parse_string s with
  | [got] when got = expected -> ()
  | got -> failwith (Printf.sprintf "parsing %S gave [%s], expected %S"
                       s (String.concat "; " got) expected)

let expect_raise what f =
  match f () with
  | () -> failwith (what ^ ": expected an exception")
  | exception Failure _ -> ()

let missing = "/nonexistent/file"

let cases = [
  (* issue 1 *)
  "missing_file_before_any_parse", (fun () ->
     expect_raise "setinputfile" (fun () -> Dash.setinputfile missing));
  "missing_file_after_a_parse", (fun () ->
     expect_parse "echo hi\n" "echo hi";
     expect_raise "setinputfile" (fun () -> Dash.setinputfile missing));
  "parse_still_works_after_missing_file", (fun () ->
     expect_raise "setinputfile" (fun () -> Dash.setinputfile missing);
     expect_parse "echo hi\n" "echo hi");
  (* issue 2 *)
  "setalias", (fun () ->
     Dash.setalias "ll" "ls -l";
     expect_parse "ll\n" "ls -l");
  "setalias_bad_name", (fun () ->
     expect_raise "setalias \"bad name\"" (fun () -> Dash.setalias "bad name" "x");
     expect_raise "setalias \"\"" (fun () -> Dash.setalias "" "x");
     expect_parse "echo hi\n" "echo hi");
]

let () =
  match Sys.argv with
  | [| _ |] -> List.iter (fun (name, _) -> print_endline name) cases
  | [| _; name |] ->
     Dash.initialize ();
     (List.assoc name cases) ();
     print_endline ("OK " ^ name)
  | _ -> prerr_endline "usage: test_crashes [case]"; exit 2
