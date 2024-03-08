From iris.algebra Require Import gset auth gmap excl excl_auth csum.
From iris.base_logic.lib Require Import mono_nat ghost_map.
From iris.algebra.lib Require Import mono_list.
From aneris.algebra Require Import monotone.
From aneris.aneris_lang Require Import network resources proofmode.
From aneris.lib Require Import gen_heap_light.
From aneris.aneris_lang.lib Require Import
     list_proof inject lock_proof.
From aneris.aneris_lang.lib.serialization
  Require Import serialization_proof.
From aneris.examples.reliable_communication.spec
     Require Import ras.
From aneris.aneris_lang.program_logic Require Import lightweight_atomic.
From aneris.examples.transactional_consistency
     Require Import code_api.
From aneris.examples.transactional_consistency.read_committed.specs
  Require Import resources.
From aneris.examples.transactional_consistency Require Import user_params aux_defs.

Set Default Proof Using "Type".

Section Specification.
  Context `{!anerisG Mdl Σ, !User_params,
            !KVS_transaction_api, !RC_resources Mdl Σ}.

  Definition write_spec : Prop :=
    ∀ (c : val) (sa : socket_address) (E : coPset) 
      (k : Key) (v : SerializableVal) (vo : option val),
      ⌜↑KVS_InvName ⊆ E⌝ -∗
      ⌜k ∈ KVS_keys⌝ -∗
      IsConnected c sa -∗
      {{{ k ↦{c} vo }}}
        TC_write c #k v @[ip_of_address sa] E
      {{{ RET #(); k ↦{c} Some v.(SV_val) }}}.

  Definition read_spec : Prop :=
    ∀ (c : val) (sa : socket_address) (E : coPset) 
      (k : Key) (vo : option val),
      ⌜↑KVS_InvName ⊆ E⌝ -∗
      ⌜k ∈ KVS_keys⌝ -∗
      IsConnected c sa -∗
    {{{ k ↦{c} vo }}}
    <<< ∀∀ (V : Vals), k ↦ₖ V >>>
      TC_read c #k @[ip_of_address sa] E
    <<<▷ k ↦ₖ V >>>
    {{{ (wo : option val), RET $wo; 
      k ↦{c} vo ∗ 
      ((⌜vo = None⌝ ∧ ⌜wo ∈ V ∨ wo = None⌝) ∨ 
      (⌜vo ≠ None⌝ ∧ ⌜wo = vo⌝)) }}}.

  Definition start_spec : Prop :=
    ∀ (c : val) (sa : socket_address) (E : coPset),
      ⌜↑KVS_InvName ⊆ E⌝ -∗
      IsConnected c sa -∗
      {{{ ConnectionState c sa CanStart }}}
      <<< ∀∀ (m : gmap Key Vals), 
          [∗ map] k ↦ V ∈ m, k ↦ₖ V >>>
        TC_start c @[ip_of_address sa] E
      <<<▷ ([∗ map] k ↦ V ∈ m, k ↦ₖ V) >>>
      {{{ RET #(); 
          ConnectionState c sa (Active (dom m)) ∗
          ([∗ map] k ↦ _ ∈ m, k ↦{c} None) }}}.

  Definition commit_spec : Prop :=
    ∀ (c : val) (sa : socket_address) (E : coPset)
      (mc : gmap Key (option val)) (s : gset Key),
      ⌜↑KVS_InvName ⊆ E⌝ -∗
      IsConnected c sa -∗
      {{{ ConnectionState c sa (Active s) ∗
          ⌜dom mc = s⌝ ∗ ([∗ map] k ↦ vo ∈ mc, k ↦{c} vo) }}}
      <<< ∀∀ (m : gmap Key Vals), 
          ⌜dom m = s⌝ ∗ ([∗ map] k ↦ V ∈ m, k ↦ₖ V) >>>
        TC_commit c @[ip_of_address sa] E
      <<<▷∃∃ (b : bool), 
          (** Transaction has been commited. *)
          ((⌜b = true⌝ ∗ ([∗ map] k↦ V;vo ∈ m; mc, k ↦ₖ (V ∪ {[vo]}))) ∨
          (** Transaction has been aborted. *)
          (⌜b = false⌝ ∗ [∗ map] k ↦ V ∈ m, k ↦ₖ V)) >>>
      {{{ RET #b; 
          ConnectionState c sa CanStart }}}.

  Definition init_client_proxy_spec : Prop :=
    ∀ (sa : socket_address),
      {{{ unallocated {[sa]} ∗
          KVS_address ⤇ KVS_rc ∗
          sa ⤳ (∅, ∅) ∗
          KVS_ClientCanConnect sa ∗
          free_ports (ip_of_address sa) {[port_of_address sa]} }}}
        TC_init_client_proxy (s_serializer KVS_serialization)
                              #sa #KVS_address @[ip_of_address sa]
      {{{ cstate, RET cstate; ConnectionState cstate sa CanStart ∗
                              IsConnected cstate sa }}}.

  Definition init_kvs_spec : Prop :=
    {{{ KVS_address ⤇ KVS_rc ∗ 
        KVS_address ⤳ (∅,∅) ∗
        free_ports (ip_of_address KVS_address) {[port_of_address KVS_address]} ∗
        KVS_Init }}}
        TC_init_server (s_serializer KVS_serialization)
                        #KVS_address @[(ip_of_address KVS_address)]
      {{{ RET #(); True }}}.

End Specification.

Section RC_Module.
  Context `{!anerisG Mdl Σ, !User_params, !KVS_transaction_api}.

  Class RC_client_toolbox `{!RC_resources Mdl Σ} := {
    RC_init_kvs_spec : init_kvs_spec ;
    RC_init_client_proxy_spec : init_client_proxy_spec;
    RC_read_spec : read_spec ;
    RC_write_spec : write_spec;
    RC_start_spec : start_spec;
    RC_commit_spec : commit_spec;
  }.
 
   Class RC_init := {
    RC_init_module E (clients : gset socket_address) :
      ↑KVS_InvName ⊆ E →
       ⊢ |={E}=>
      ∃ (res : RC_resources Mdl Σ),
        ([∗ set] k ∈ KVS_keys, k ↦ₖ ∅) ∗
        KVS_Init ∗
        GlobalInv ∗
        ([∗ set] sa ∈ clients, KVS_ClientCanConnect sa) ∗
        ⌜init_kvs_spec⌝ ∗
        ⌜init_client_proxy_spec⌝ ∗
        ⌜read_spec⌝ ∗
        ⌜write_spec⌝ ∗
        ⌜start_spec⌝ ∗
        ⌜commit_spec⌝
     }.
   
End RC_Module.