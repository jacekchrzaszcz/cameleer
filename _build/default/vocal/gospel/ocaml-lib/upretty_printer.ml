(**************************************************************************)
(*                                                                        *)
(*  GOSPEL -- A Specification Language for OCaml                          *)
(*                                                                        *)
(*  Copyright (c) 2018- The VOCaL Project                                 *)
(*                                                                        *)
(*  This software is free software, distributed under the MIT license     *)
(*  (as described in file LICENSE enclosed).                              *)
(**************************************************************************)

open Identifier
open Oparsetree
open Uast
open Opprintast
open Oasttypes

let const_hole s fmt _ = pp fmt "%s" s

let rec qualid fmt (q:qualid) = match q with
  | Qpreid pid -> print_pid fmt pid
  | Qdot (q,pid) -> pp fmt "@[%a.%a@]" qualid q print_pid pid

let labelled_arg fmt (l:labelled_arg) = match l with
  | Lnone pid -> print_pid fmt pid
  | Lquestion pid -> pp fmt "@[?%a@]" print_pid pid
  | Lnamed pid -> pp fmt "@[~%a@]" print_pid pid
  | Lghost (pid,ty) -> pp fmt "@[[%a : TY]@]" print_pid pid

let spec f fmt x =
  pp fmt "@[(*@@ %a@ *)@]" f x

(* let pattern fmt pat =
 *   match pat.pat_desc with
 *   | Pwild  -> pp fmt "_"
 *   | Pvar x -> pp fmt "%a" protect_ident x.pid_str
 *   | _ -> assert false (\* TODO *\) *)

let term fmt x = pp fmt "@[TERM ... @]"

let invariant fmt i = pp fmt "@[INVARIANT ... @]"

let list_keyword s fmt x = match x with
  | [] -> ()
  | _ -> pp fmt "%a@\n"
           (list ~sep:"@\n" (const_hole s)) x

let type_spec f ts =
  let ephemeral f e =
    if e then pp f "ephemeral@\n" else () in
  let print_tspec fmt ts =
    pp f "@[<v>%a%a%a@]" ephemeral ts.ty_ephemeral
      (list_keyword "model ...") ts.ty_field
      (list_keyword "invariant ...") ts.ty_invariant in
  if ts.ty_ephemeral || ts.ty_field != [] || ts.ty_invariant != [] then
    pp f "@[%a@]" (spec print_tspec) ts
  else ()

let val_spec fmt vspec =
  match vspec with
  | None -> ()
  | Some vspec ->
     let diverge fmt x = if x then pp fmt "diverges@\n" else () in
     let print_content fmt s =
       pp fmt "@[@[<h>%a%s %a %a@]@\n%a%a%a%a%a%a%a%a%a@]"
         (list ~sep:"," labelled_arg) s.sp_hd_ret
         (if s.sp_hd_ret = [] then "" else " =")
         print_pid s.sp_hd_nm
         (list ~sep:" " labelled_arg) s.sp_hd_args
         (list_keyword "requires ...") s.sp_pre
         (list_keyword "ensures ...") s.sp_post
         (list_keyword "with ...") s.sp_xpost
         (list_keyword "reads ...") s.sp_reads
         (list_keyword "modifies ...") s.sp_writes
         (list_keyword "consumes ...") s.sp_consumes
         (list_keyword "alias ...") s.sp_alias
         diverge s.sp_diverge
         (list_keyword "equivalent ...") s.sp_equiv in
     spec print_content fmt vspec

let value_description f x =
  pp f "@[%a%a@]" core_type x.vtype
    (fun f x ->
      if x.vprim <> []
      then pp f "@ =@ %a" (list constant_string) x.vprim
    ) x

let s_type_declaration f x =
  (* type_declaration has an attribute field,
     but it's been printed by the caller of this method *)
  let priv f =
    match x.tprivate with
    | Public -> ()
    | Private -> pp f "@;private"
  in
  let manifest f =
    match x.tmanifest with
    | None -> ()
    | Some y ->
        if x.tkind = Ptype_abstract then
          pp f "%t@;%a" priv core_type y
        else
          pp f "@;%a" core_type y
  in
  let constructor_declaration f pcd =
    pp f "|@;";
    constructor_declaration reset_ctxt f
      (pcd.pcd_name.txt, pcd.pcd_args, pcd.pcd_res, pcd.pcd_attributes)
  in
  let repr f =
    let intro f =
      if x.tmanifest = None then ()
      else pp f "@;="
    in
    match x.tkind with
    | Ptype_variant xs ->
      let variants fmt xs =
        if xs = [] then pp fmt " |" else
          pp fmt "@\n%a" (list ~sep:"@\n" constructor_declaration) xs
      in pp f "%t%t%a" intro priv variants xs
    | Ptype_abstract -> ()
    | Ptype_record l ->
        pp f "%t%t@;%a" intro priv (record_declaration reset_ctxt) l
    | Ptype_open -> pp f "%t%t@;.." intro priv
  in
  let constraints f =
    List.iter
      (fun (ct1,ct2,_) ->
         pp f "@[<hov2>@ constraint@ %a@ =@ %a@]"
           (core_type) ct1 (core_type) ct2)
      x.tcstrs
  in
  pp f "%t%t%t" manifest repr constraints

let s_type_declaration_rec_flag f (rf,l) =
  let type_decl kwd rf f x =
    let eq =
      if (x.tkind = Ptype_abstract)
         && (x.tmanifest = None) then ""
      else " ="
    in
    pp f "@[@[%s %a%a%s%s%a@]%a@]@\n@[@ @ %a@]" kwd
      nonrec_flag rf
      (type_params reset_ctxt) x.tparams
      x.tname.txt
      eq
      s_type_declaration x
      (item_attributes reset_ctxt) x.tattributes
      type_spec x.tspec
  in
  match l with
  | [] -> assert false
  | [x] -> type_decl "type" rf f x
  | x :: xs -> pp f "@[<v>%a@,%a@]"
                 (type_decl "type" rf) x
                 (list ~sep:"@," (type_decl "and" Oasttypes.Recursive)) xs

let function_ f x =
  let keyword = match x.fun_type with
    | None -> "predicate"
    | Some _ -> "function" in
  let sep f _ =  match x.fun_spec with
    | { fun_req=[];fun_ens=[];fun_variant=[];_ } -> () | _ -> pp f "@\n" in
  let func f x =
    pp f "@[%s %s%a ...%a%a%a%a%a@]"
      keyword
      (if x.fun_rec then "rec " else "")
      print_pid x.fun_name
      (fun f _ -> if x.fun_spec.fun_coer then pp f "@\ncoercion" else ()) ()
      sep ()
      (list_keyword "variant ...") x.fun_spec.fun_variant
      (list_keyword "requires ...") x.fun_spec.fun_req
      (list_keyword "ensures ...") x.fun_spec.fun_ens
  in
  spec func f x

let prop f x =
  let prop f x =
    pp f "@[%s ...@]" (if x.prop_kind = Plemma then "lemma" else "axiom") in
  spec prop f x

let rec s_signature_item f x=
  let s_val_description f vd =
      let intro = if vd.vprim = [] then "val" else "external" in
      pp f "@[<2>%s@ %a@ :@ %a@]%a@\n%a" intro
        protect_ident vd.vname.txt
        value_description vd
        (item_attributes reset_ctxt) vd.vattributes
        val_spec vd.vspec in
  let print_open f od =
      pp f "@[<hov2>open%s@ %a@]%a"
        (override od.popen_override)
        longident_loc od.popen_lid
        (item_attributes reset_ctxt) od.popen_attributes in
  match x.sdesc with
  | Sig_type (rf, l) ->
      s_type_declaration_rec_flag f (rf, l)
  | Sig_val vd -> s_val_description f vd
  | Sig_typext te ->
      type_extension reset_ctxt f te
  | Sig_exception ed ->
      exception_declaration reset_ctxt f ed
  | Sig_class l ->
      let class_description kwd f ({pci_params=ls;pci_name={txt;_};_} as x) =
        pp f "@[<2>%s %a%a%s@;:@;%a@]%a" kwd
          virtual_flag x.pci_virt
          (class_params_def reset_ctxt) ls txt
          (class_type reset_ctxt) x.pci_expr
          (item_attributes reset_ctxt) x.pci_attributes
      in begin
        match l with
        | [] -> ()
        | [x] -> class_description "class" f x
        | x :: xs ->
            pp f "@[<v>%a@,%a@]"
              (class_description "class") x
              (list ~sep:"@," (class_description "and")) xs
      end
  | Sig_module ({mdtype={mdesc=Mod_alias alias;
                            mattributes=[]; _};_} as pmd) ->
      pp f "@[<hov>module@ %s@ =@ %a@]%a" pmd.mdname.txt
        longident_loc alias
        (item_attributes reset_ctxt) pmd.mdattributes
  | Sig_module pmd ->
      pp f "@[<hov>module@ %s@ :@ %a@]%a"
        pmd.mdname.txt
        s_module_type1 pmd.mdtype
        (item_attributes reset_ctxt) pmd.mdattributes
  | Sig_open od -> print_open f od
  | Sig_include incl ->
      pp f "@[<hov2>include@ %a@]%a"
        (s_module_type reset_ctxt) incl.spincl_mod
        (item_attributes reset_ctxt) incl.spincl_attributes
  | Sig_modtype {mtdname=s; mtdtype=md; mtdattributes=attrs} ->
      pp f "@[<hov2>module@ type@ %s%a@]%a"
        s.txt
        (fun f md -> match md with
           | None -> ()
           | Some mt ->
               Format.pp_print_space f () ;
               pp f "@ =@ %a" s_module_type1 mt
        ) md
        (item_attributes reset_ctxt) attrs
  | Sig_class_type (l) -> class_type_declaration_list reset_ctxt f l
  | Sig_recmodule decls ->
      let rec  string_x_module_type_list f ?(first=true) l =
        match l with
        | [] -> () ;
        | pmd :: tl ->
            if not first then
              pp f "@ @[<hov2>and@ %s:@ %a@]%a" pmd.mdname.txt
                s_module_type1 pmd.mdtype
                (item_attributes reset_ctxt) pmd.mdattributes
            else
              pp f "@[<hov2>module@ rec@ %s:@ %a@]%a" pmd.mdname.txt
                s_module_type1 pmd.mdtype
                (item_attributes reset_ctxt) pmd.mdattributes;
            string_x_module_type_list f ~first:false tl
      in
      string_x_module_type_list f decls
  | Sig_attribute a -> floating_attribute reset_ctxt f a
  | Sig_extension(e, a) ->
      item_extension reset_ctxt f e;
      item_attributes reset_ctxt f a
  | Sig_function x -> function_ f x
  | Sig_prop x -> prop f x
  | Sig_ghost_type  (rf,l) ->
     pp f "@[%a@]"
       (spec s_type_declaration_rec_flag) (rf,l)
  | Sig_ghost_val vd -> pp f "@[%a@]" (spec s_val_description) vd
  | Sig_ghost_open od -> pp f "@[%a@]" (spec print_open) od

and s_signature f x = list ~sep:"@\n@\n" s_signature_item f x

and s_module_type f x =
  assert false (* TODO *)
  (* if x.mattributes <> [] then begin
   *   pp f "((%a)%a)" module_type {x with mattributes=[]}
   *     (attributes reset_ctxt) x.mattributes
   * end else
   *   match x.mdesc with
   *   | Mod_functor (_, None, mt2) ->
   *       pp f "@[<hov2>functor () ->@ %a@]" s_module_type mt2
   *   | Mod_functor (s, Some mt1, mt2) ->
   *       if s.txt = "_" then
   *         pp f "@[<hov2>%a@ ->@ %a@]"
   *           s_module_type1 mt1 s_module_type mt2
   *       else
   *         pp f "@[<hov2>functor@ (%s@ :@ %a)@ ->@ %a@]" s.txt
   *           s_module_type mt1 s_module_type mt2
   *   | Mod_with (mt, []) -> s_module_type f mt
   *   | Mod_with (mt, l) ->
   *       let with_constraint f = function
   *         | Wtype (li, ({tparams= ls ;_} as td)) ->
   *             let ls = List.map fst ls in
   *             pp f "type@ %a %a =@ %a"
   *               (list core_type ~sep:"," ~first:"(" ~last:")")
   *               ls longident_loc li s_type_declaration td
   *         | Wmodule (li, li2) ->
   *             pp f "module %a =@ %a" longident_loc li longident_loc li2;
   *         | Wtypesubst (li, ({tparams=ls;_} as td)) ->
   *             let ls = List.map fst ls in
   *             pp f "type@ %a %a :=@ %a"
   *               (list core_type ~sep:"," ~first:"(" ~last:")")
   *               ls longident_loc li
   *               s_type_declaration td
   *         | Wmodsubst (li, li2) ->
   *            pp f "module %a :=@ %a" longident_loc li longident_loc li2 in
   *       pp f "@[<hov2>%a@ with@ %a@]"
   *         s_module_type1 mt (list with_constraint ~sep:"@ and@ ") l
   *   | _ -> s_module_type1 f x *)

and s_module_type1 f x =
  if x.mattributes <> [] then (* s_module_type f x *) assert false (* TODO *)
  else match x.mdesc with
    | Mod_ident li ->
        pp f "%a" longident_loc li;
    | Mod_alias li ->
        pp f "(module %a)" longident_loc li;
    | Mod_signature (s) ->
        pp f "@[<hv0>@[<hv2>sig@ %a@]@ end@]" (* "@[<hov>sig@ %a@ end@]" *)
          (list s_signature_item) s (* FIXME wrong indentation*)
    | Mod_typeof me ->
        pp f "@[<hov2>module@ type@ of@ %a@]" (s_module_expr reset_ctxt) me
    | Mod_extension e -> extension reset_ctxt f e
    | _ -> assert false (* TODO *)(* paren true s_module_type f x *)

and s_module_expr ctxt f x =
  assert false (* TODO *)
  (* if x.spmod_attributes <> [] then
   *   pp f "((%a)%a)" (module_expr ctxt) {x with pmod_attributes=[]}
   *     (attributes ctxt) x.spmod_attributes
   * else match x.spmod_desc with
   *   | Smod_structure (_s) ->
   *       (\* pp f "@[<hv2>struct@;@[<0>%a@]@;<1 -2>end@]"
   *        *   (list (structure_item) ~sep:"@\n") s; *\)
   *       assert false (\* TODO *\)
   *   | Smod_constraint (me, mt) ->
   *       pp f "@[<hov2>(%a@ :@ %a)@]"
   *         (module_expr ctxt) me
   *         (module_type ctxt) mt
   *   | Smod_ident (li) ->
   *       pp f "%a" longident_loc li;
   *   | Smod_functor (_, None, me) ->
   *       pp f "functor ()@;->@;%a" (module_expr ctxt) me
   *   | Smod_functor (s, Some mt, me) ->
   *       pp f "functor@ (%s@ :@ %a)@;->@;%a"
   *         s.txt (module_type ctxt) mt (module_expr ctxt) me
   *   | Smod_apply (me1, me2) ->
   *       pp f "(%a)(%a)" (module_expr ctxt) me1 (module_expr ctxt) me2
   *       (\* Cf: #7200 *\)
   *   | Smod_unpack e ->
   *       pp f "(val@ %a)" (expression ctxt) e
   *   | Smod_extension e -> extension ctxt f e *)

let s_expression _e = assert false (* TODO *)

let rec s_structure_item fmt str =
  match str.sstr_desc with
  | Str_eval (e, _) ->
      pp fmt "%a" s_expression e
  | Str_value (rec_flag, vb_list) ->
      pp fmt "%a" (list (s_value_binding rec_flag)) vb_list
  | _ -> assert false (* TODO *)

and s_value_binding is_rec fmt s_val =
  let intro = "let " ^ (match is_rec with Recursive -> "rec " | _ -> "") in
  pp fmt "@[<2>%s%a@ =@ %a@]%a@\n%a" intro
    pattern s_val.spvb_pat
    s_expression s_val.spvb_expr
    (item_attributes reset_ctxt) s_val.spvb_attributes
    val_spec s_val.spvb_vspec

and structure fmt str = list ~sep:"@\n@\n" s_structure_item fmt str
