open Ctypes

module Types = Types_generated
open Types

module Functions (F : Ctypes.FOREIGN) = struct
  open F

  let setstackmark = foreign "setstackmark" (ptr stackmark @-> returning void)
  let popstackmark = foreign "popstackmark" (ptr stackmark @-> returning void)

  let alloc_stack_string = foreign "sstrdup" (string @-> returning (ptr char))
  let free_stack_string = foreign "stunalloc" (ptr char @-> returning void)

  let dash_init = foreign "init" (void @-> returning void)
  let initialize_dash_errno = foreign "initialize_dash_errno" (void @-> returning void)

  let popfile = foreign "popfile" (void @-> returning void)
  let setinputstring = foreign "setinputstring" (ptr char @-> returning void)
  let setinputfd = foreign "setinputfd" (int @-> int @-> returning void)
  let raw_setinputfile = foreign "setinputfile" (string @-> int @-> returning int)

  let raw_setvar = foreign "setvar" (string @-> string @-> int @-> returning (ptr void))

  let setalias = foreign "setalias" (string @-> string @-> returning void)
  let unalias = foreign "unalias" (string @-> returning void) 

  (* Unix/ExtUnix don't let you renumber things the way you want *)
  let freshfd_ge10 = foreign "freshfd_ge10" (int @-> returning int)

  let parsecmd_safe = foreign "parsecmd_safe" (int @-> returning (ptr node))
  let neof = foreign_value "tokpushback" node
  let nerr = foreign_value "lasttoken" node
end


