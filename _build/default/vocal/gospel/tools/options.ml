(**************************************************************************)
(*                                                                        *)
(*  GOSPEL -- A Specification Language for OCaml                          *)
(*                                                                        *)
(*  Copyright (c) 2018- The VOCaL Project                                 *)
(*                                                                        *)
(*  This software is free software, distributed under the MIT license     *)
(*  (as described in file LICENSE enclosed).                              *)
(**************************************************************************)

open Arg

(** Get *.mli files in directory *)
let mli_in_dir dir =
  let is_mli f = Filename.extension f = ".mli" in
  Sys.readdir dir
  |> Array.to_list
  |> List.filter is_mli
  |> List.rev_map (Filename.concat dir)

let valid_dir d =
  try if Sys.is_directory d then d else raise Exit with
    Sys_error _ | Exit -> raise (Bad ("invalid directory: " ^ d))

let files = ref []

let print_intermediate = ref false
let parse_ocaml_only = ref false
let parse_only = ref false
let print_parsed = ref false
let bench_mode = ref false
let load_path = ref []

let specialist = [
  "--print-intermediate", Unit (fun () -> print_intermediate := true),
    " Print intermediate form";
  "--parse-ocaml-only", Unit (fun () -> parse_ocaml_only := true),
    " Stop after parsing OCaml signatures";
  "--parse-only", Unit (fun () -> parse_only := true),
    " Stop after parsing phase";
  "--print-parsed", Unit (fun () -> print_parsed := true),
    " Print after parsing";
  "--bench-mode", Unit (fun () -> bench_mode := true),
    " Run in bench mode: parses, type checks, and prints status for files in given directory";
  "-L", String (fun d -> load_path := (valid_dir d) :: !load_path),
    "load-path Include directory in load pah";
  ]

let anon_fun s =
  let open Filename in
  let open Sys in
  if file_exists s && is_directory s then begin
    files := mli_in_dir s @ !files;
    load_path := s :: !load_path
  end else begin
      files := s :: !files;
      load_path := dirname s :: !load_path
    end

let usage_msg = "Usage: gospel <options> file.mli [file.mli]"

let parse () =
  parse (align specialist) anon_fun usage_msg;
  if !files = [] then begin
      Format.eprintf "%s: no input file(s)@.." Sys.argv.(0);
      usage specialist usage_msg;
      exit 0 end;
  files := List.rev !files;
  load_path := List.rev !load_path
