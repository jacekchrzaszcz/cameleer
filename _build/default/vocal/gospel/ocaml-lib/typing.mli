(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2019   --   Inria - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

open Utils
open Tast
open Tmodule

(** Parsing environment *)
type parse_env

(** `penv load_paths module_nm` creates a `parse_env` for typing a
   module with name `module_nm`. The paths in `load_paths` are to be
   used when searching for modules dependencies. *)
val penv : string list -> Sstr.t -> parse_env

(** `process_sig_item penv muc s` returns a new module under
   construction after type checking `s` and the typed signature
   obtained from `s` and `muc`. *)
val process_sig_item : parse_env -> module_uc -> Uast.s_signature_item ->
                       module_uc * signature_item

(** the same as above but it drops the typed signature *)
val type_sig_item : parse_env -> module_uc -> Uast.s_signature_item -> module_uc

val process_str_item : parse_env -> module_uc -> Uast.s_structure_item ->
                       module_uc * t_structure_item

val type_str_item : parse_env -> module_uc -> Uast.s_structure_item -> module_uc
