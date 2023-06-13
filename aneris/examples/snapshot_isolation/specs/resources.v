From stdpp Require Import list.
From iris.algebra Require Import frac.
From iris.bi.lib Require Import fractional.
From aneris.aneris_lang Require Export resources.
From aneris.examples.reliable_communication.prelude
     Require Import list_minus.
From aneris.examples.snapshot_isolation.specs
     Require Export user_params time events.

Section Resources.

  Reserved Notation "k ↦ₖ eo" (at level 20).
  Reserved Notation "k ↦{ c } vo" (at level 20).

  Inductive local_state `{!KVS_time}: Type :=
   | CanStart
   | Active (ms : gmap Key (option write_event)).

  Class SI_resources Mdl Σ
    `{!anerisG Mdl Σ, !KVS_time, !User_params}:= {

    (** System global invariant *)
    GlobalInv : iProp Σ;
    GlobalInvPersistent :> Persistent GlobalInv;

    (** Logical global points-to connective *)
    OwnMemKey : Key → option write_event → iProp Σ
    where "k ↦ₖ we" := (OwnMemKey k we);

   (** Logical Local points-to connective *)
    OwnLocalKey : Key → val → option val → iProp Σ
    where "k ↦{ c } vo" := (OwnLocalKey k c vo);

   (** Logical points-to connective *)
    ConnectionState : val → local_state → iProp Σ;

    KVS_si : message → iProp Σ;

   (** Cache Key Status *)
    KeyUpdStatus : val → Key → bool → iProp Σ;

    KeyUpdStatus_exclusive c k b b' :
      KeyUpdStatus c k b ⊢ KeyUpdStatus c k b' -∗ False;

    (** Properties of points-to connective *)
    OwnMemKey_timeless k v :> Timeless (k ↦ₖ v);
    OwnMemKey_exclusive k v v' :
      k ↦ₖ v ⊢ k ↦ₖ v' -∗ False;
    OwnMemKey_key k we E :
      nclose KVS_InvName ⊆ E →
      GlobalInv ⊢
      k ↦ₖ Some we ={E}=∗
      k ↦ₖ Some we ∗ ⌜we_key we = k⌝;

(** Properties of local points-to connective *)
    OwnLocalKey_timeless k v c:> Timeless (k ↦{c} v);
    OwnLocalKey_exclusive k c v v' :
      k ↦{c} v ⊢ k ↦{c} v' -∗ False;

    (** Laws *)
    ConnectionState_relation E k r ms we :
    ↑KVS_InvName ⊆ E ->
    GlobalInv ⊢
    ConnectionState r (Active ms) -∗ k ↦ₖ Some we ={E}=∗
    ⌜k ∈ dom ms →
    ∀ we', ms !! k = Some (Some we') → we' ≤ₜ we ⌝;

   OwnMemKey_OwnLocalKey_coh k we vo c E :
      GlobalInv ⊢
      k ↦ₖ Some we -∗ k ↦{c} vo ={E}=∗ ⌜is_Some vo⌝;

   ConnectionState_Keys E r ms :
    ↑KVS_InvName ⊆ E ->
      GlobalInv ⊢
      ConnectionState r (Active ms) ={E}=∗
      ⌜dom ms ⊆ KVS_keys⌝;

  (* ... about keys in domains *)
  }.

End Resources.
(* Arguments SI_resources _ _ : clear implicits. *)

Notation "k ↦ₖ eo" := (OwnMemKey k eo) (at level 20).
Notation "k ↦{ c } vo" := (OwnLocalKey k c vo) (at level 20).
