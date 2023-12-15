type linno = int

exception ParseException of string
           
type t =
  | Command of (linno * assign list * args * redirection list) (* assign, args, redir *)
  | Pipe of (bool * t list) (* background?, commands *)
  | Redir of (linno * t * redirection list)
  | Background of (linno * t * redirection list)
  | Subshell of (linno * t * redirection list)
  | And of (t * t)
  | Or of (t * t)
  | Not of (t)
  | Semi of (t * t)
  | If of (t * t * t) (* cond, then, else *)
  | While of (t * t) (* test, body *) (* until encoded as a While . Not *)
  | For of (linno * arg list * t * string) (* args, body, var *)
  | Case of (linno * arg * case list)
  | Defun of (linno * string * t) (* name, body *)
 and assign = string * arg
 and redirection =
   | File of (redir_type * int * arg)
   | Dup of (dup_type * int * arg)
   | Heredoc of (heredoc_type * int * arg)
 and redir_type = To | Clobber | From | FromTo | Append
 and dup_type = ToFD | FromFD
 and heredoc_type = Here | XHere (* for when in a quote... not sure when this comes up *)
 and args = arg list
 and arg = arg_char list
 and arg_char =
   | C of char
   | E of char (* escape... necessary for expansion *)
   | T of string option (* tilde *)
   | A of arg (* arith *)
   | V of (var_type * bool (* VSNUL? *) * string * arg)
   | Q of arg (* quoted *)
   | B of t (* backquote *)
 and var_type =
   | Normal
   | Minus
   | Plus
   | Question
   | Assign
   | TrimR
   | TrimRMax
   | TrimL
   | TrimLMax
   | Length
 and case = { cpattern : arg list; cbody : t }

let var_type = function
 | 0x0 -> (* VSNORMAL ${var} *) Normal
 | 0x2 -> (* VSMINUS ${var-text} *) Minus
 | 0x3 -> (* VSPLUS ${var+text} *) Plus
 | 0x4 -> (* VSQUESTION ${var?message} *) Question
 | 0x5 -> (* VSASSIGN ${var=text} *) Assign
 | 0x6 -> (* VSTRIMRIGHT ${var%pattern} *) TrimR
 | 0x7 -> (* VSTRIMRIGHTMAX ${var%%pattern} *) TrimRMax
 | 0x8 -> (* VSTRIMLEFT ${var#pattern} *) TrimL
 | 0x9 -> (* VSTRIMLEFTMAX ${var##pattern} *) TrimLMax
 | 0xa -> (* VSLENGTH ${#var}) *) Length
 | vs -> failwith ("Unknown VSTYPE: " ^ string_of_int vs)

let string_of_var_type = function
 | Normal -> ""
 | Minus -> "-"
 | Plus -> "+"
 | Question -> "?"
 | Assign -> "="
 | TrimR -> "%"
 | TrimRMax -> "%%"
 | TrimL -> "#"
 | TrimLMax -> "##" 
 | Length -> "#" 

(* Some possible further simplifications:

     * Drop bool from pipe
       dash *always* forks for a pipe, but sometimes it waits
     * Drop redirection from Command, etc. 
         Just use Redir... though this may affect subshell behavior.
           NCMD: expredir, pushredir, redirectsafe REDIR_PUSH|REDIR_SAVEFD2
           NREDIR: expredir, pushredir, redirectsafe REDIR_PUSH
           NBACKGND: expredir, redirect 0
*)


open Ctypes
open Dash

let rec last = function
  | [] -> None
  | [x] -> Some x
  | _::xs -> last xs

let skip = Command (-1,[],[],[])

type quote_mode =
    QUnquoted
  | QQuoted
  | QHeredoc

let rec of_node (n : node union ptr) : t =
  if nullptr n
  then skip
  else
  match (n @-> node_type) with
  (* NCMD *)
  | 0  ->
     let n = n @-> node_ncmd in
     Command (getf n ncmd_linno,
              to_assigns (getf n ncmd_assign),
              to_args (getf n ncmd_args),
              redirs (getf n ncmd_redirect))
  (* NPIPE *)
  | 1 ->
     let n = n @-> node_npipe in
     Pipe (getf n npipe_backgnd <> 0,
           List.map of_node (nodelist (getf n npipe_cmdlist)))
  (* NREDIR *)
  | 2  -> let (ty,fd,arg) = of_nredir n in Redir (ty,fd,arg)
  (* NBACKGND *)
  | 3  -> let (ty,fd,arg) = of_nredir n in Background (ty,fd,arg)
  (* NSUBSHELL *)
  | 4  -> let (ty,fd,arg) = of_nredir n in Subshell (ty,fd,arg)
  (* NAND *)
  | 5  -> let (l,r) = of_binary n in And (l,r)
  (* NOR *)
  | 6  -> let (l,r) = of_binary n in Or (l,r)
  (* NSEMI *)
  | 7  -> let (l,r) = of_binary n in Semi (l,r)
  (* NIF *)
  | 8  ->
     let n = n @-> node_nif in
     If (of_node (getf n nif_test),
         of_node (getf n nif_ifpart),
         of_node (getf n nif_elsepart))
  (* NWHILE *)
  | 9  -> let (t,b) = of_binary n in While (t,b)
  (* NUNTIL *)
  | 10 -> let (t,b) = of_binary n in While (Not t,b)
  (* NFOR *)
  | 11 ->
     let n = n @-> node_nfor in
     For (getf n nfor_linno,
          to_args (getf n nfor_args),
          of_node (getf n nfor_body),
          getf n nfor_var)
  (* NCASE *)
  | 12 ->
     let n = n @-> node_ncase in
     Case (getf n ncase_linno,
           to_arg (getf n ncase_expr @-> node_narg),
           List.map
             (fun (pattern,body) ->
               { cpattern = to_args pattern;
                 cbody = of_node body})
             (caselist (getf n ncase_cases)))
  (* NDEFUN *)
  | 14 ->
     let n = n @-> node_ndefun in
     Defun (getf n ndefun_linno,
            getf n ndefun_text,
            of_node (getf n ndefun_body))
  (* NNOT *)
  | 25 -> Not (of_node (getf (n @-> node_nnot) nnot_com))
  | nt -> failwith ("Unexpected top level node_type " ^ string_of_int nt)

and of_nredir (n : node union ptr) =
  let n = n @-> node_nredir in
  (getf n nredir_linno, of_node (getf n nredir_n), redirs (getf n nredir_redirect))

and redirs (n : node union ptr) =
  if nullptr n
  then []
  else
    let mk_file ty =
      let n = n @-> node_nfile in
      File (ty,getf n nfile_fd,to_arg (getf n nfile_fname @-> node_narg)) in
    let mk_dup ty =
      let n = n @-> node_ndup in
      let vname = getf n ndup_vname in
      let tgt =
        if nullptr vname
        then let dupfd = getf n ndup_dupfd in
             if dupfd = -1
             then [C '-']
             else List.map (fun c -> C c) (explode (string_of_int dupfd))
        else to_arg (vname @-> node_narg)
      in
      Dup (ty,getf n ndup_fd,tgt) in
    let mk_here ty =
      let n = n @-> node_nhere in
      Heredoc (ty,getf n nhere_fd,to_arg (getf n nhere_doc @-> node_narg)) in
    let h = match n @-> node_type with
      (* NTO *)
      | 16 -> mk_file To
      (* NCLOBBER *)
      | 17 -> mk_file Clobber
      (* NFROM *)
      | 18 -> mk_file From
      (* NFROMTO *)
      | 19 -> mk_file FromTo
      (* NAPPEND *)
      | 20 -> mk_file Append
      (* NTOFD *)      
      | 21 -> mk_dup ToFD
      (* NFROMFD *)              
      | 22 -> mk_dup FromFD
      (* NHERE quoted heredoc---no expansion)*)
      | 23 -> mk_here Here
      (* NXHERE unquoted heredoc (param/command/arith expansion) *)
      | 24 -> mk_here XHere
      | nt -> failwith ("unexpected node_type in redirlist: " ^ string_of_int nt)
    in
    h :: redirs (getf (n @-> node_nfile) nfile_next)

and of_binary (n : node union ptr) =
  let n = n @-> node_nbinary in
  (of_node (getf n nbinary_ch1), of_node (getf n nbinary_ch2))

and to_arg (n : narg structure) : arg =
  let a,s,bqlist,stack = parse_arg ~assign:false (explode (getf n narg_text)) (getf n narg_backquote) [] in
  (* we should have used up the string and have no backquotes left in our list *)
  assert (s = []);
  assert (nullptr bqlist);
  assert (stack = []);
  a  

and parse_arg ?tilde_ok:(tilde_ok=false) ~assign:(assign:bool) (s : char list) (bqlist : nodelist structure ptr) stack =
  match s,stack with
  | [],[] -> [],[],bqlist,[]
  | [],`CTLVar::_ -> failwith "End of string before CTLENDVAR"
  | [],`CTLAri::_ -> failwith "End of string before CTLENDARI"
  | [],`CTLQuo::_ -> failwith "End of string before CTLQUOTEMARK"
  (* CTLESC *)
  | '\129'::c::s,_ -> arg_char assign (E c) s bqlist stack
  (* CTLVAR *)
  | '\130'::t::s,_ ->
     let var_name,s = split_at (fun c -> c = '=') s in
     let t = int_of_char t in
     let v,s,bqlist,stack = match t land 0x0f, s with
     (* VSNORMAL and VSLENGTH get special treatment

     neither ever gets VSNUL
     VSNORMAL is terminated just with the =, without a CTLENDVAR *)
     (* VSNORMAL *)
     | 0x1,'='::s ->
        V (Normal,false,implode var_name,[]),s,bqlist,stack
     (* VSLENGTH *)
     | 0xa,'='::'\131'::s ->
        V (Length,false,implode var_name,[]),s,bqlist,stack
     | 0x1,c::_ | 0xa,c::_ ->
        failwith ("Missing CTLENDVAR for VSNORMAL/VSLENGTH, found " ^ Char.escaped c)
     (* every other VSTYPE takes mods before CTLENDVAR *)
     | vstype,'='::s ->
        let a,s,bqlist,stack' = parse_arg ~tilde_ok:true ~assign s bqlist (`CTLVar::stack) in
        V (var_type vstype,t land 0x10 = 0x10,implode var_name,a), s, bqlist, stack'
     | _,c::_ -> failwith ("Expected '=' terminating variable name, found " ^ Char.escaped c)
     | _,[] -> failwith "Expected '=' terminating variable name, found EOF"
     in
     arg_char assign v s bqlist stack
  | '\130'::s, _ ->
     (* original behavior *)
     (* raise (ParseException "bad substitution (missing variable name in ${}?") *)
     (* ignoring malformed stuff (e.g., from arrays) to behave the same as pash's python bindings *)
     let a,s,bqlist,stack = parse_arg ~assign s bqlist stack in
     (C '\194'::C '\130'::a,s,bqlist,stack)

  (* CTLENDVAR *)
  | '\131'::s,`CTLVar::stack' -> [],s,bqlist,stack'
  | '\131'::_,`CTLAri::_ -> failwith "Saw CTLENDVAR before CTLENDARI"
  | '\131'::_,`CTLQuo::_ -> failwith "Saw CTLENDVAR before CTLQUOTEMARK"
  | '\131'::_,[] -> failwith "Saw CTLENDVAR outside of CTLVAR"
  (* CTLBACKQ *)
  | '\132'::s,_ ->
     if nullptr bqlist
     then failwith "Saw CTLBACKQ but bqlist was null"
     else arg_char assign (B (of_node (bqlist @-> nodelist_n))) s (bqlist @-> nodelist_next) stack
  (* CTLARI *)
  | '\134'::s,_ ->
     let a,s,bqlist,stack' = parse_arg ~assign s bqlist (`CTLAri::stack) in
     assert (stack = stack');
     arg_char assign (A a) s bqlist stack'
  (* CTLENDARI *)
  | '\135'::s,`CTLAri::stack' -> [],s,bqlist,stack'
  | '\135'::_,`CTLVar::_' -> failwith "Saw CTLENDARI before CTLENDVAR"
  | '\135'::_,`CTLQuo::_' -> failwith "Saw CTLENDARI before CTLQUOTEMARK"
  | '\135'::_,[] -> failwith "Saw CTLENDARI outside of CTLARI"
  (* CTLQUOTEMARK *)
  | '\136'::s,`CTLQuo::stack' -> [],s,bqlist,stack'
  | '\136'::s,_ ->
     let a,s,bqlist,stack' = parse_arg ~assign s bqlist (`CTLQuo::stack) in
     assert (stack' = stack);
     arg_char assign (Q a) s bqlist stack'
  (* tildes *)
  | '~'::s,stack ->
     if List.exists (fun m -> m = `CTLQuo || m = `CTLAri) stack
     then (* we're in arithmetic or double quotes, so tilde is ignored *)
       arg_char assign (C '~') s bqlist stack
     else
       let _ = tilde_ok in (* unused? *)
       let uname,s' = parse_tilde [] s in
       arg_char assign (T uname) s' bqlist stack
  (* ordinary character *)
  | c::s,_ ->
     arg_char assign (C c) s bqlist stack

and parse_tilde acc s =
  match s with
  (* CTLESC, CTLVAR, CTLQUOTEMARK, CTLBACKQ, CTLARI: no tilde prefix *)
  | '\129'::_ | '\130'::_ | '\132'::_ | '\134'::_ | '\136'::_ -> None, s
  (* CTLENDVAR, CTLENDARI, /, :, EOF: terminate tilde prefix *)
  | '\131'::_ | '\135'::_
  | ':'::_ | '/'::_ | [] ->
     if acc = [] then (None, s) else (Some (implode acc), s)
  (* ordinary char *)
  (* TODO 2019-01-03 only characters from the portable character set *)
  | c::s' -> parse_tilde (acc @ [c]) s'  
              
and arg_char assign c s bqlist stack =
  let tilde_ok = 
    match c with
    | C _ -> assign && (match last s with
                       | Some ':' -> true
                       | _ -> false)
    | _ -> false
  in
  let a,s,bqlist,stack = parse_arg ~tilde_ok ~assign s bqlist stack in
  (c::a,s,bqlist,stack)

and extract_assign v = function
  | [] -> failwith ("Never found an '=' sign in assignment, got " ^ implode (List.rev v))
  | '=' :: a -> (implode (List.rev v),a)
  | '\129'::_ -> failwith "Unexpected CTLESC in variable name"
  | '\130'::_ -> failwith "Unexpected CTLVAR in variable name"
  | '\131'::_ -> failwith "Unexpected CTLENDVAR in variable name"
  | '\132'::_ -> failwith "Unexpected CTLBACKQ in variable name"
  | '\133'::_ -> failwith "Unexpected CTL??? in variable name"
  | '\134'::_ -> failwith "Unexpected CTLARI in variable name"
  | '\135'::_ -> failwith "Unexpected CTLENDARI in variable name"
  | '\136'::_ -> failwith "Unexpected CTLQUOTEMARK in variable name"
  | c :: a ->
     extract_assign (c::v) a

and to_assign (n : narg structure) : (string * arg) =
  let (v,t) = extract_assign [] (explode (getf n narg_text)) in
  let a,s,bqlist,stack = parse_arg ~tilde_ok:true ~assign:true t (getf n narg_backquote) [] in
  (* we should have used up the string and have no backquotes left in our list *)
  assert (s = []);
  assert (nullptr bqlist);
  assert (stack = []);
  (v,a)
    
and to_assigns n = 
  if nullptr n
  then [] 
  else (assert (n @-> node_type = 15);
        let n = n @-> node_narg in
        to_assign n::to_assigns (getf n narg_next))
    
and to_args (n : node union ptr) : args =
  if nullptr n
  then [] 
  else (assert (n @-> node_type = 15);
        let n = n @-> node_narg in
        to_arg n::to_args (getf n narg_next))

let separated f l = intercalate " " (List.map f l)

let show_unless expected actual =
  if expected = actual
  then ""
  else string_of_int actual

let background s = "{ " ^ s ^ " & }"

let lines = Str.split (Str.regexp "[\n]+")

let fresh_marker heredoc =  
  let eofs_in_line line =
    if String.length line > 2 && String.get line 0 = 'E' && String.get line 1 == 'O'
    then
      try String.rindex line 'F' - 1
      with Not_found -> 0
    else 0
  in
  let rec find_eofs lines max_fs =
    match lines with
    | [] -> max_fs
    | line::lines -> find_eofs lines (max max_fs (eofs_in_line line))
  in
  "EOF" ^ String.make (find_eofs heredoc 0) 'F'
  
let rec to_string = function
  | Command (_,assigns,cmds,redirs) ->
     separated string_of_assign assigns ^
     (if List.length assigns = 0 || List.length cmds = 0 then "" else " ") ^
     separated string_of_arg cmds ^ string_of_redirs redirs
  | Pipe (bg,ps) ->
     let p = intercalate " | " (List.map to_string ps) in
     if bg then background p else p
  | Redir (_,a,redirs) ->
     to_string a ^ string_of_redirs redirs
  | Background (_,a,redirs) ->
     (* we translate 
           cmds... &
        to
           { cmds & }
        this avoids issues with parsing; in particular,
          cmd1 & ; cmd2 & ; cmd3
        doesn't parse; it must be:
          cmd1 & cmd2 & cmd3
        it's a little too annoying to track "was the last thing
        backgrounded?" so the braces resolve the issue. testing
        indicates that they're semantically equivalent.
      *)
     background (to_string a ^ string_of_redirs redirs)
  | Subshell (_,a,redirs) ->
     parens (to_string a ^ string_of_redirs redirs)
  | And (a1,a2) -> braces (to_string  a1) ^ " && " ^ braces (to_string a2)
  | Or (a1,a2) -> braces (to_string a1) ^ " || " ^ braces (to_string a2)
  | Not a -> "! " ^ braces (to_string a)
  | Semi (a1,a2) -> braces (to_string a1) ^ " \n " ^ braces (to_string a2)
  | If (c,t,e) -> string_of_if c t e
  | While (Not t,b) ->
     "until " ^ to_string t ^ "; do " ^ to_string b ^ "; done "
  | While (t,b) ->
     "while " ^ to_string t ^ "; do " ^ to_string b ^ "; done "
  | For (_,a,body,var) ->
     "for " ^ var ^ " in " ^ separated string_of_arg a ^ "; do " ^
     to_string body ^ "; done"
  | Case (_,a,cs) ->
     "case " ^ string_of_arg a ^ " in " ^
     separated string_of_case cs ^ " esac"
  | Defun (_,name,body) -> name ^ "() {\n" ^ to_string body ^ "\n}"
                                                 
and string_of_if c t e =
  "if " ^ to_string c ^
  "; then " ^ to_string t ^
  (match e with
   | Command (-1,[],[],[]) -> "; fi" (* one-armed if *)
   | If (c,t,e) -> "; el" ^ string_of_if c t e
   | _ -> "; else " ^ to_string e ^ "; fi")
                                                 
and string_of_arg_char ?quote_mode:(quote_mode=QUnquoted) = function
  | E c ->
     (* removed ! from chars_to_escape to have the right behavior in non-interactive shells *)
     let chars_to_escape = "'\"`(){}$&|;" in
     let chars_to_escape_when_no_quotes = "*?[]#<>~ " in
     if String.contains chars_to_escape c
     then "\\" ^ String.make 1 c
     else if String.contains chars_to_escape_when_no_quotes c && quote_mode=QUnquoted
     then "\\" ^ String.make 1 c
     else Char.escaped c
  | C '"' when quote_mode=QQuoted -> "\\\""
  | C c -> String.make 1 c
  | T None -> "~"
  | T (Some u) -> "~" ^ u
  | A a -> "$((" ^ string_of_arg ~quote_mode a ^ "))"
  | V (Length,_,name,_) -> "${#" ^ name ^ "}"
  | V (vt,nul,name,a) ->
     "${" ^ name ^ (if nul then ":" else "") ^ string_of_var_type vt ^ string_of_arg ~quote_mode a ^ "}"
  | Q a -> "\"" ^ string_of_arg ~quote_mode:QQuoted a ^ "\""
  | B t -> "$(" ^ to_string t ^ ")"

and string_of_arg ?quote_mode:(quote_mode=QUnquoted) = function
  | [] -> ""
  | c :: a ->
     let char = string_of_arg_char ~quote_mode c in
     if char = "$" && next_is_escaped a
     then "\\$" ^ string_of_arg ~quote_mode a
     else char ^ string_of_arg ~quote_mode a

and next_is_escaped = function
  | E _ :: _ -> true
  | _ -> false
                
and string_of_assign (v,a) = v ^ "=" ^ string_of_arg a
                                                   
and string_of_case c =
  let pats = List.map string_of_arg c.cpattern in
  intercalate "|" pats ^ ") " ^ to_string c.cbody ^ ";;"

and string_of_redir = function
  | File (To,fd,a)      -> show_unless 1 fd ^ ">" ^ string_of_arg a
  | File (Clobber,fd,a) -> show_unless 1 fd ^ ">|" ^ string_of_arg a
  | File (From,fd,a)    -> show_unless 0 fd ^ "<" ^ string_of_arg a
  | File (FromTo,fd,a)  -> show_unless 0 fd ^ "<>" ^ string_of_arg a
  | File (Append,fd,a)  -> show_unless 1 fd ^ ">>" ^ string_of_arg a
  | Dup (ToFD,fd,tgt)   -> show_unless 1 fd ^ ">&" ^ string_of_arg tgt
  | Dup (FromFD,fd,tgt) -> show_unless 0 fd ^ "<&" ^ string_of_arg tgt
  | Heredoc (t,fd,a) ->
     let heredoc = string_of_arg ~quote_mode:QHeredoc a in
     let marker = fresh_marker (lines heredoc) in
     show_unless 0 fd ^ "<<" ^
     (if t = XHere then marker else "'" ^ marker ^ "'") ^ "\n" ^ heredoc ^ marker ^ "\n"
                                                                               
and string_of_redirs rs =
  let ss = List.map string_of_redir rs in
  (if List.length ss > 0 then " " else "") ^ intercalate " " ss
