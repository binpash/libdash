open Ctypes
include Cdash.Functions
include Cdash.Types

(* First, some dash trivia. *)

type stackmark_t = Stackmark.stackmark

let init_stack () : stackmark =
  let stack = Ctypes.make stackmark in
  setstackmark (addr stack);
  stack

let pop_stack stack : unit =
  popstackmark (addr stack)
 
let initialize () : unit =
  initialize_dash_errno ();
  dash_init ()

let setinputtostdin () : unit =
  setinputfd 0 0 (* don't bother pushing the file *)

let setinputfile ?push:(push=false) (s : string) : unit =
  let _ = raw_setinputfile s (if push then 1 else 0) in
  ()

let setvar (x : string) (v : string) : unit =
  let _ = raw_setvar x v 0 in
  ()

let addrof p = raw_address_of_ptr (to_voidp p)

let eqptr p1 p2 = addrof p1 = addrof p2
                                  
let nullptr (p : 'a ptr) = addrof p = Nativeint.zero

type parse_result = Done | Error | Null | Parsed of (node union ptr)

let parse_next ?interactive:(i=false) () =
  let n = parsecmd_safe (if i then 1 else 0) in
  if eqptr n neof
  then Done
  else if eqptr n nerr
  then Error
  else if nullptr n
  then Null (* comment or blank line or error ... *)
  else Parsed n
            
let (@->) (s : ('b, 'c) structured ptr) (f : ('a, ('b, 'c) structured) field) =
  getf (!@ s) f

let rec arglist (n : narg structure) : (narg structure) list =
  let next = getf n narg_next in
  if nullptr next
  then [n] 
  else
    (assert (next @-> node_type = 15);
     n::arglist (next @-> node_narg))

let rec nodelist (n : nodelist structure ptr) : (node union ptr) list =
  if nullptr n
  then []
  else (n @-> nodelist_n)::nodelist (n @-> nodelist_next)
                  
let rec redirlist (n : node union ptr) =
  if nullptr n
  then []
  else
    let h = match n @-> node_type with
      (* NTO *)
      | 16 -> `File (1,">",n @-> node_nfile)
      (* NCLOBBER *)
      | 17 -> `File (1,">|",n @-> node_nfile)
      (* NFROM *)
      | 18 -> `File (0,"<",n @-> node_nfile)
      (* NFROMTO *)
      | 19 -> `File (0,"<>",n @-> node_nfile)
      (* NAPPEND *)
      | 20 -> `File (1,">>",n @-> node_nfile)
      (* NTOFD *)      
      | 21 -> `Dup (1,">&",n @-> node_ndup)
      (* NFROMFD *)              
      | 22 -> `Dup (0,"<&",n @-> node_ndup)
      (* NHERE quoted heredoc---no expansion)*)
      | 23 -> `Here (0,"<<",false,n @-> node_nhere)
      (* NXHERE unquoted heredoc (param/command/arith expansion) *)
      | 24 -> `Here (0,"<<",true,n @-> node_nhere)
      | nt -> failwith ("unexpected node_type in redirlist: " ^ string_of_int nt)
    in
    h :: redirlist (getf (n @-> node_nfile) nfile_next)

let rec caselist (n : node union ptr) =
  if nullptr n
  then []
  else    
    let n = n @-> node_nclist in
    assert (getf n nclist_type = 13); (* NCLIST *)
    (getf n nclist_pattern, getf n nclist_body)::caselist (getf n nclist_next)
                   
let explode s =
  let rec exp i l =
    if i < 0 then l else exp (i - 1) (s.[i] :: l) in
  exp (String.length s - 1) []

let implode l =
  let s = Bytes.create (List.length l) in
  let rec imp i l =
    match l with
    | []  -> ()
    | (c::l) -> (Bytes.set s i c; imp (i+1) l)
  in
  imp 0 l;
  Bytes.unsafe_to_string s
                   
let rec intercalate p ss =
  match ss with
  | [] -> ""
  | [s] -> s
  | s::ss -> s ^ p ^ intercalate p ss          

let lines = Str.split (Str.regexp "[\n\r]+")

let rec fresh_marker ls s =
  if List.mem s ls
  then fresh_marker ls (s ^ (String.sub s (String.length s - 1) 1))
  else s
                      
let rec split_at p xs =
  match xs with
  | [] -> ([],[])
  | x::xs ->
     if p x
     then ([],x::xs)
     else let (xs,ys) = split_at p xs in
          (x::xs, ys)

let string_of_vs = function
  | 0x1 -> (* VSNORMAL ${var} *) []
  | 0x2 -> (* VSMINUS ${var-text} *) ['-']
  | 0x3 -> (* VSPLUS ${var+text} *) ['+']
  | 0x4 -> (* VSQUESTION ${var?message} *) ['?']
  | 0x5 -> (* VSASSIGN ${var=text} *) ['=']
  | 0x6 -> (* VSTRIMRIGHT ${var%pattern} *) ['%']
  | 0x7 -> (* VSTRIMRIGHTMAX ${var%%pattern} *) ['%';'%']
  | 0x8 -> (* VSTRIMLEFT ${var#pattern} *) ['#']
  | 0x9 -> (* VSTRIMLEFTMAX ${var##pattern} *) ['#';'#']
  | vs -> failwith ("Unknown VSTYPE: " ^ string_of_int vs)
                   
let braces s = "{ " ^ s ^ " ; }"
let parens s = "( " ^ s ^ " )"
                  
let rec show (n : node union ptr) : string =
  match (n @-> node_type) with
  (* NCMD *)
  | 0  ->
     let n = n @-> node_ncmd in
     let raw_cmd = intercalate " " (List.map sharg (arglist (getf n ncmd_args @-> node_narg))) in
     let vars = if nullptr (getf n ncmd_assign) then "" else intercalate " " (List.map sharg (arglist (getf n ncmd_assign @-> node_narg))) ^ " " in
     vars ^ raw_cmd ^ shredir (getf n ncmd_redirect)
  (* NPIPE *)
  | 1  ->
     let n = n @-> node_npipe in
     let cmds = nodelist (getf n npipe_cmdlist) in
     intercalate " | " (List.map show cmds) ^ if (getf n npipe_backgnd) = 0 then "" else " &"
  (* NREDIR *)
  | 2  -> shnredir braces n 
  (* NBACKGND *)
  | 3  -> shnredir braces n ^ " &"
  (* NSUBSHELL *)
  | 4  -> shnredir parens n
  (* NAND *)
  | 5  -> shbinary "&&" (n @-> node_nbinary)
  (* NOR *)
  | 6  -> shbinary "||" (n @-> node_nbinary)
  (* NSEMI *)
  | 7  -> shbinary ";" (n @-> node_nbinary)
  (* NIF *)
  | 8  -> shif (n @-> node_nif)
  (* NWHILE *)
  | 9  ->
     let n = n @-> node_nbinary in
     "while " ^ show (getf n nbinary_ch1) ^ "; do " ^ show (getf n nbinary_ch2) ^ "; done"
  (* NUNTIL *)
  | 10 ->
     let n = n @-> node_nbinary in
     "until " ^ show (getf n nbinary_ch1) ^ "; do " ^ show (getf n nbinary_ch2) ^ "; done"
  (* NFOR *)
  | 11 ->
     let n = n @-> node_nfor in
     "for " ^ (getf n nfor_var) ^ " in " ^ intercalate " " (List.map sharg (arglist (getf n nfor_args @-> node_narg))) ^ "; do " ^ show (getf n nfor_body) ^ "; done"
  (* NCASE *)
  | 12 ->
     let n = n @-> node_ncase in
     "case " ^ sharg (getf n ncase_expr @-> node_narg) ^ " in " ^ shclist (getf n ncase_cases) ^ " esac"
  (* NDEFUN *)
  | 14 ->
     let n = n @-> node_ndefun in
     (getf n ndefun_text) ^ "() " ^ braces (show (getf n ndefun_body))
  (* NARG *)
  | 15 -> failwith "Didn't expect narg at the top-level"
  (* NNOT *)
  | 25 -> "! { " ^ show (getf (n @-> node_nnot) nnot_com) ^ " }"
  | nt -> failwith ("unexpected node_type " ^ string_of_int nt)

and shbinary (op : string) (n : nbinary structure) : string =
  show (getf n nbinary_ch1) ^ " " ^ op ^ " " ^ show (getf n nbinary_ch2)

and shnredir parenthesize n =
  let nr = n @-> node_nredir in
  parenthesize (show (getf nr nredir_n)) ^ shredir (getf nr nredir_redirect)

and shif n =
  "if " ^ show (getf n nif_test) ^
  "; then " ^ show (getf n nif_ifpart) ^
  (let else_part = getf n nif_elsepart in
   if nullptr else_part
   then "; fi"
   else if (else_part @-> node_type = 8)
   then "; el" ^ shif (else_part @-> node_nif)
   else "; else " ^ show else_part ^ "; fi")

and shclist clist = intercalate " " (List.map shcase (caselist clist)) (* handles NCLIST = 13 *)
    
and shcase (pat,body) =
  assert (pat @-> node_type = 15);
  sharg (pat @-> node_narg) ^ ") " ^ show body ^ ";;"
    
and shredir (n : node union ptr) : string =
  let redirs = redirlist n in
  if redirs = []
  then ""
  else " " ^ intercalate " " (List.map show_redir redirs)
and show_redir n : string =
  match n with
  | `File (src,sym,f) -> show_redir_src (getf f nfile_fd) src ^ sym ^ sharg ((getf f nfile_fname) @-> node_narg)
  | `Dup (src,sym,d) -> 
      let vname = getf d ndup_vname in
      let tgt =
        if nullptr vname
        then string_of_int (getf d ndup_dupfd)
        else sharg (vname @-> node_narg)
      in
     show_redir_src (getf d ndup_fd) src ^ sym ^ tgt
  | `Here (src,sym,exp,h) ->
     let heredoc = sharg ((getf h nhere_doc) @-> node_narg) in
     let marker = fresh_marker (lines heredoc) "EOF" in
     show_redir_src (getf h nhere_fd) src ^ sym ^ (if exp then marker else "'" ^ marker ^ "'") ^ "\n" ^ heredoc ^ marker
and show_redir_src actual expected =
  if actual = expected
  then ""
  else string_of_int actual
                                                    
and sharg (n : narg structure) : string =
  let str,s',bqlist,stack = show_arg (explode (getf n narg_text)) (getf n narg_backquote) [] in
  (* we should have used up the string and have no backquotes left in our list *)
  assert (s' = []);
  assert (nullptr bqlist);
  assert (stack = []);
  str    
and show_arg (s : char list) (bqlist : nodelist structure ptr) stack =
  (* we have to look at the string and interpret control characters... *)
  match s,stack with
  | [],[] -> "",[],bqlist,[]
  | [],`CTLVar::stack' -> failwith "End of string before CTLENDVAR"
  | [],`CTLAri::stack' -> failwith "End of string before CTLENDARI"
  | [],`CTLQuo::stack' -> failwith "End of string before CTLQUOTEMARK"
  (* CTLESC *)
  | '\129'::c::s',_ -> 
     let str,s'',bqlist',stack' = show_arg s' bqlist stack in
     let c' = match c with
      | '\'' -> "\\'"
      | '\"' -> "\\\""
      | _ -> String.make 1 c
     in
     c' ^ str,s'',bqlist',stack'
  (* CTLVAR *)
  | '\130'::t::s',_ -> 
     let v,s'',bqlist',stack' = show_var (int_of_char t) s' bqlist stack in
     assert (stack = stack');
     let str,s''',bqlist'',stack'' = show_arg s'' bqlist' stack' in
     "${" ^ v ^ "}" ^ str, s''', bqlist'', stack''
  (* CTLENDVAR *)
  | '\131'::s',`CTLVar::stack' -> "",[],bqlist,stack' (* s' gets handled by CTLVAR *)
  | '\131'::s',`CTLAri::stack' -> failwith "Saw CTLENDVAR before CTLENDARI"
  | '\131'::s',`CTLQuo::stack' -> failwith "Saw CTLENDVAR before CTLQUOTEMARK"
  | '\131'::s',[] -> failwith "Saw CTLENDVAR outside of CTLVAR"
  (* CTLBACKQ *)
  | '\132'::s',_ ->
     if nullptr bqlist
     then failwith "Saw CTLBACKQ but bqlist was null"
     else
       let n = bqlist @-> nodelist_n in
       (* MMG: !!! dash has a bug in its sharg function... it doesn't advance the list! *)
       let bqlist' = bqlist @-> nodelist_next in
       let str,s'',bqlist'',stack' = show_arg s' bqlist' stack in
       "$(" ^ show n ^ ")" ^ str,s'',bqlist'',stack'
  (* CTLARI *)
  | '\134'::s',_ ->
     let ari,s'',bqlist',stack' = show_arg s' bqlist (`CTLAri::stack) in
     assert (stack = stack');
     let str,s''',bqlist'',stack'' = show_arg s'' bqlist' stack' in
     "$((" ^ ari ^ "))" ^ str, s''', bqlist'', stack''
  (* CTLENDARI *)
  | '\135'::s',`CTLAri::stack' -> "",s',bqlist,stack'
  | '\135'::s',`CTLVar::stack' -> failwith "Saw CTLENDARI before CTLENDVAR"
  | '\135'::s',`CTLQuo::stack' -> failwith "Saw CTLENDARI before CTLQUOTEMARK"
  | '\135'::s',[] -> failwith "Saw CTLENDARI outside of CTLARI"
  (* CTLQUOTEMARK *)
  | '\136'::s',[`CTLQuo] -> "",s',bqlist,[]
  | '\136'::s',_ ->
     let quoted,s'',bqlist',stack' = show_arg  s' bqlist [`CTLQuo] in
     assert (stack' = []);
     let str,s''',bqlist'',stack'' = show_arg s'' bqlist' stack in
     "\"" ^ quoted ^ "\"" ^ str, s''', bqlist'', stack''
  (* ordinary character *)
  | c::s',_ -> 
     let str,s',bqlist',stack' = show_arg s' bqlist stack in
     let c' = match c with
      | '\'' -> "\\'"
      | '\"' -> "\\\""
      | _ -> String.make 1 c
     in
     c' ^ str,s',bqlist',stack'
and show_var (t : int) (s : char list) (bqlist : nodelist structure ptr) stack =
  let var_name,s' = split_at (fun c -> c = '=') s in
  (* mask out VSNUL, check VSTYPE *)
  match t land 0x0f, s' with
  (* VSNORMAL and VSLENGTH get special treatment

     neither ever gets VSNUL
     VSNORMAL is terminated just with the =, without a CTLENDVAR *)
  (* VSNORMAL *)
  | 0x1,'='::s'' -> implode var_name, s'', bqlist, stack
  (* VSLENGTH *)
  | 0xa,'='::'\131'::s'' -> implode (['#'] @ var_name), s'', bqlist, stack
  | 0x1,c::_ | 0xa,c::_ -> failwith ("Missing CTLENDVAR for VSNORMAL/VSLENGTH, found " ^ Char.escaped c)
  (* every other VSTYPE takes mods before CTLENDVAR *)
  | vstype,'='::s' ->
     (* check VSNUL *)
     let vsnul = if t land 0x10 = 1 then [] else [':'] in
     let mods,s'',bqlist',stack' = show_arg s' bqlist (`CTLVar::stack) in
     implode (var_name @ vsnul @ string_of_vs vstype) ^ mods, s'', bqlist', stack'
  | _,c::s' -> failwith ("Expected '=' terminating variable name, found " ^ Char.escaped c)
  | _,[] -> failwith "Expected '=' terminating variable name, found EOF"

