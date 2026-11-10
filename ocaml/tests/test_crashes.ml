(* libdash's exported C entry points, seen through the OCaml binding, must
   report errors, not crash. See test/test_crashes.py for the Python side.

   Each case is run in its own process (see dune): a bad longjmp kills the
   process, and libdash keeps global state between calls.

   - After a parse, an error from another call (e.g., Dash.setinputfile on a
     missing file) must raise Failure, not longjmp into a dead frame.
   - Dash.setalias takes the alias name and value as two strings (raw C
     setalias wants a "name=value" buffer), and raises Failure on a bad
     name. *)

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
  (* errors outside a parse *)
  "missing_file_before_any_parse", (fun () ->
     expect_raise "setinputfile" (fun () -> Dash.setinputfile missing));
  "missing_file_after_a_parse", (fun () ->
     expect_parse "echo hi\n" "echo hi";
     expect_raise "setinputfile" (fun () -> Dash.setinputfile missing));
  "parse_still_works_after_missing_file", (fun () ->
     expect_raise "setinputfile" (fun () -> Dash.setinputfile missing);
     expect_parse "echo hi\n" "echo hi");
  (* Dash.setalias takes the name and value as two strings *)
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
