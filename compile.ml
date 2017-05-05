type var = string

type pat = string

type expr =
  | Var of var (* : whatever the var is *)

  | Int of int (* : int *)
  | Eq of expr * expr (* : bool *)
  | Not of expr (* : int *)


  | Bind of var * expr * expr
  | If of expr * expr * expr

  | Lookup of string (* : string *)
  | Assign of string * expr (* : () *)
  | Execve of string * string list (* : int/pid *)
  | Match of string * pat (* : bool *)
  | Defun of string * expr (* : () *)
  | PushRedir (* : () *)
  | PopRedir (* : () *)
  | Fork of expr (* : int/pid *)
  | Wait of expr (* : int/status code *)
  | Pipe of expr list (* : int/status code *)
  | Capture of expr (* : string *)

  | Arith of expr (* : string *)

  | Str of string (* : string *)
  | Concat of expr list (* : string *)
  | Length of expr (* : int *)

let bind x e1 e2 = Bind(x,e1,e2)

let cond i t e = If(i,t,e)

let fresh : var -> var * expr =
  let ctr = ref 0 in
  fun base -> let s = base ^ string_of_int !ctr in incr ctr; (s,Var s)

let set_status (run : expr) : expr =
  let (ec,ec_var) = fresh "ec" in
  bind ec run (bind "_" (Assign ("?",ec_var)) ec_var)

let rec setup_redir (r : Ast.redirection) : expr = failwith "setup_redir"

let with_redirects (rs : Ast.redirection list) (c : expr) : expr =
  List.fold_right (fun r cmd -> bind "_" (setup_redir r) cmd) rs c

let save_fds (c : expr) : expr =
  let (status,status_var) = fresh "status" in
  bind "_" PushRedir
       (bind status c
             (bind "_" PopRedir status_var))

let split_fields (arg : expr list) : expr = failwith "split_fields"

let expand_paths (fields : expr) : expr = failwith "expand_paths"

let remove_quotes (fields : expr) : expr = failwith "remove_quotes"

(* TODO

$?, etc. -- shell state explicitly or implicitly carried?

pipes -- open followed by dup2/fcntl

break, continue, return -- evalskip/break count
source, eval -- builtin? analyses just have to take account
trap -- need abstract signal handlers

aliases -- just keep a table somewhere

*)

(* invariant: returns status code *)
let rec compile (c : Ast.t) : expr =
  set_status
    (begin match c with
     | Ast.Command (_,assigns,args,redirs) ->
        (* expand assignments
           expand arguments
           determine if it's a command or a built in
           execve command/run builtin/call defun, or error on bad lookup
         *)
        with_redirects redirs (failwith "command")
     | Ast.Pipe (bg,cs) ->
        let (pid,pid_var) = fresh "pid" in
        bind pid (Fork (Pipe (List.map compile cs)))
             (if bg then (Int 0) else Wait pid_var)
     | Ast.Redir (_,c,redirs) ->
        save_fds (with_redirects redirs (compile c))
     | Ast.Background (_,c,redirs) ->
        let (pid,pid_var) = fresh "pid" in
        bind pid (Fork (with_redirects redirs (compile c))) (Int 0)
     | Ast.Subshell (_,c,redirs) ->
        let (pid,pid_var) = fresh "pid" in
        bind pid (Fork (with_redirects redirs (compile c))) (Wait pid_var)
     | Ast.And (c1,c2) ->
        let (status,status_var) = fresh "status" in
        bind status (compile c1) (cond status_var (compile c2) status_var)
     | Ast.Or (c1,c2) ->
        let (status,status_var) = fresh "status" in
        bind status (compile c1) (cond status_var status_var (compile c2))
     | Ast.Not c ->
        let (status,status_var) = fresh "status" in
        bind status (compile c) (Not status_var)
     | Ast.Semi (c1,c2) ->
        bind "_" (compile c1) (compile c2)
     | Ast.If (c_cond,c_then,c_else) ->
        let (status,status_var) = fresh "status" in
        bind status (compile c_cond) (cond status_var (compile c_then) (compile c_else))
     | Ast.While (cond,body) -> failwith "while"
     | Ast.For (_,args,body,var) -> failwith "for"
     | Ast.Case (_,args,cases) -> failwith "cases"
     | Ast.Defun (_,name,body) -> Defun (name,compile body)
     end)

(* invariant: returns expanded string *)
and expands (quoted : bool) (args : Ast.args) : expr =
  Concat (List.map (expand quoted) args) (* TODO insert field separations *)

(* invariant: returns expanded string *)
and expand (quoted : bool) (arg : Ast.arg) : expr =
  (* TODO field splitting, path expansion, quote removal *)
  remove_quotes (expand_paths (split_fields (List.map (expand_char quoted) arg)))

(* invariant: returns expanded string *)
and expand_char (quoted : bool) (a : Ast.arg_char) : expr =
  match a with
  | Ast.C chr -> Str (String.make 1 chr)
  | Ast.E esc -> Str (String.make 1 esc)
  | Ast.A ari -> Arith (expand quoted ari)
  | Ast.V(fmt,nul,var,arg) -> expand_var quoted fmt nul var arg
  | Ast.Q arg -> expand true arg
  | Ast.B cmd -> Capture (compile cmd)

and expand_var (quoted : bool) (fmt : Ast.var_type) (nul : bool) (var : string) (arg : Ast.arg) : expr =
  match var with
  | "@" -> failwith "$@"
  | "*" -> failwith "$*"
  | "?" -> failwith "$?"
  | "$" -> failwith "$$"
  | "#" -> failwith "$#"
  | "!" -> failwith "$!"
  | "-" -> failwith "$-"
  | _ -> let (res,res_var) = fresh "res" in
         bind res (Lookup var)
              (begin match fmt with
               | Ast.Normal -> res_var
               | Ast.Minus -> failwith "${-}"
               | Ast.Plus -> failwith "${+}"
               | Ast.Question -> failwith "${?}"
               | Ast.Assign -> failwith "${=}"
               | Ast.TrimR -> failwith "${%}"
               | Ast.TrimRMax -> failwith "${%%}"
               | Ast.TrimL -> failwith "${#}"
               | Ast.TrimLMax -> failwith "${##}"
               | Ast.Length -> Length res_var
               end)
