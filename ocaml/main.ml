open Dash

let verbose = ref false
let input_src : string option ref = ref None

let set_input_src () =
  match !input_src with
  | None -> setinputtostdin ()
  | Some f -> setinputfile f

let parse_args () =
  Arg.parse
    ["-v",Arg.Set verbose,"verbose mode"]
    (function | "-" -> input_src := None | f -> input_src := Some f)
    "Final argument should be either a filename or - (for STDIN); only the last such argument is used"

let main () = 
  initialize ();
  parse_args ();
  set_input_src ();
  let ns = parse_all () in
  let cs = List.map Ast.of_node ns in
  List.map (fun c -> print_endline (Ast.to_string c)) cs;;

main ()
