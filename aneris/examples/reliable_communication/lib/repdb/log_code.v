(* This file is automatically generated from the OCaml source file
<repository_root>/ml_sources/examples/reliable_communication/lib/repdb/log_code.ml *)

From aneris.aneris_lang Require Import ast.
From aneris.aneris_lang.lib Require Import list_code.

(**  Operations on log of requests  *)

Definition log_create : val := λ: <>, ref ([], #0).

Definition log_add_entry : val :=
  λ: "log" "req",
  let: "lp" := ! "log" in
  let: "data" := Fst "lp" in
  let: "next" := Snd "lp" in
  let: "data'" := list_append "data" [("req", "next")] in
  "log" <- ("data'", ("next" + #1)).

Definition log_next : val := λ: "log", Snd ! "log".

Definition log_length : val := λ: "log", Snd ! "log".

Definition log_get : val := λ: "log" "i", list_nth (Fst ! "log") "i".

Definition log_wait_until : val :=
  λ: "log" "mon" "i",
  letrec: "aux" <> :=
    let: "n" := log_next "log" in
    (if: "n" = "i"
     then  monitor_wait "mon";;
           "aux" #()
     else  assert: ("i" < "n")) in
    (if: ("i" < #0) || ((log_next "log") < "i")
     then  assert: #false
     else  "aux" #()).
