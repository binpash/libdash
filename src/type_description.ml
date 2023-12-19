open Ctypes

module Types (F : Ctypes.TYPE) = struct
  open F
  
  (* stackmarks [used for string allocation in dash] *)
  type stackmark
                
  let stackmark : stackmark structure typ = structure "stackmark"
  let stackp = field stackmark "stackp" (ptr void)
  let nxt = field stackmark "nxt" string
  let size = field stackmark "stacknleft" F.size_t
  let () = seal stackmark

  (* AST nodes *)

  (* define the node type... *)
  type node       
  let node : node union typ = union "node"
  let node_type = field node "type" int
  (* ...but don't seal it yet! *)
  
  type nodelist
  let nodelist : nodelist structure typ = structure "nodelist"       
  let nodelist_next = field nodelist "next" (ptr nodelist)
  let nodelist_n = field nodelist "n" (ptr node)
  let () = seal nodelist
                         
  type ncmd
  
  let ncmd : ncmd structure typ = structure "ncmd"
  let ncmd_type = field ncmd "type" int
  let ncmd_linno = field ncmd "linno" int
  let ncmd_assign = field ncmd "assign" (ptr node)
  let ncmd_args = field ncmd "args" (ptr node)
  let ncmd_redirect = field ncmd "redirect" (ptr node)
  let () = seal ncmd
  
  let node_ncmd = field node "ncmd" ncmd
  
  type npipe
  
  let npipe : npipe structure typ = structure "npipe"
  let npipe_type = field npipe "type" int
  let npipe_backgnd = field npipe "backgnd" int
  let npipe_cmdlist = field npipe "cmdlist" (ptr nodelist)
  let () = seal npipe
  
  let node_npipe = field node "npipe" npipe
                             
  type nredir
  
  let nredir : nredir structure typ = structure "nredir"
  let nredir_type = field nredir "type" int
  let nredir_linno = field nredir "linno" int
  let nredir_n = field nredir "n" (ptr node)
  let nredir_redirect = field nredir "redirect" (ptr node)
  let () = seal nredir
  
  let node_nredir = field node "nredir" nredir
  
  type nbinary
  
  let nbinary : nbinary structure typ = structure "nbinary"
  let nbinary_type = field nbinary "type" int
  let nbinary_ch1 = field nbinary "ch1" (ptr node)
  let nbinary_ch2 = field nbinary "ch2" (ptr node)
  let () = seal nbinary
  
  let node_nbinary = field node "nbinary" nbinary
  
  type nif
  
  let nif : nif structure typ = structure "nif"
  let nif_type = field nif "type" int
  let nif_test = field nif "test" (ptr node)
  let nif_ifpart = field nif "ifpart" (ptr node)
  let nif_elsepart = field nif "elsepart" (ptr node)
  let () = seal nif
  
  let node_nif = field node "nif" nif
  
  type nfor
  
  let nfor : nfor structure typ = structure "nfor"
  let nfor_type = field nfor "type" int
  let nfor_linno = field nfor "linno" int
  let nfor_args = field nfor "args" (ptr node)
  let nfor_body = field nfor "body" (ptr node)
  let nfor_var = field nfor "var" string
  let () = seal nfor
  
  let node_nfor = field node "nfor" nfor
  
  type ncase
  
  let ncase : ncase structure typ = structure "ncase"
  let ncase_type = field ncase "type" int
  let ncase_linno = field ncase "linno" int
  let ncase_expr = field ncase "expr" (ptr node)
  let ncase_cases = field ncase "cases" (ptr node)
  let () = seal ncase
  
  let node_ncase = field node "ncase" ncase
  
  type nclist
  
  let nclist : nclist structure typ = structure "nclist"
  let nclist_type = field nclist "type" int
  let nclist_next = field nclist "next" (ptr node)
  let nclist_pattern = field nclist "pattern" (ptr node)
  let nclist_body = field nclist "body" (ptr node)
  let () = seal nclist
  
  let node_nclist = field node "nclist" nclist
  
  type ndefun
  
  let ndefun : ndefun structure typ = structure "ndefun"
  let ndefun_type = field ndefun "type" int
  let ndefun_linno = field ndefun "linno" int
  let ndefun_text = field ndefun "text" string
  let ndefun_body = field ndefun "body" (ptr node)
  let () = seal ndefun
  
  let node_ndefun = field node "ndefun" ndefun
  
  type narg
  
  let narg : narg structure typ = structure "narg"
  let narg_type = field narg "type" int
  let narg_next = field narg "next" (ptr node)
  let narg_text = field narg "text" string
  let narg_backquote = field narg "backquote" (ptr nodelist)
  let () = seal narg
  
  let node_narg = field node "narg" narg
  
  type nfile
  
  let nfile : nfile structure typ = structure "nfile"
  let nfile_type = field nfile "type" int
  let nfile_next = field nfile "next" (ptr node)
  let nfile_fd = field nfile "fd" int
  let nfile_fname = field nfile "fname" (ptr node)
  let nfile_expfname = field nfile "expfname" string
  let () = seal nfile
  
  let node_nfile = field node "nfile" nfile
  
  type ndup
  
  let ndup : ndup structure typ = structure "ndup"
  let ndup_type = field ndup "type" int
  let ndup_next = field ndup "next" (ptr node)
  let ndup_fd = field ndup "fd" int
  let ndup_dupfd = field ndup "dupfd" int
  let ndup_vname = field ndup "vname" (ptr node)
  let () = seal ndup
  
  let node_ndup = field node "ndup" ndup
  
  type nhere
  
  let nhere : nhere structure typ = structure "nhere"
  let nhere_type = field nhere "type" int
  let nhere_next = field nhere "next" (ptr node)
  let nhere_fd = field nhere "fd" int
  let nhere_doc = field nhere "doc" (ptr node)
  let () = seal nhere
  
  let node_nhere = field node "nhere" nhere
  
  type nnot
  
  let nnot : nnot structure typ = structure "nnot"
  let nnot_type = field nnot "type" int
  let nnot_com = field nnot "com" (ptr node)
  let () = seal nnot
  
  let node_nnot = field node "nnot" nnot
  let () = seal node

end
