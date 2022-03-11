(* Distributed under the terms of the MIT license. *)
(* For primitive integers and floats  *)
From Coq Require Numbers.Cyclic.Int63.Int63 Floats.PrimFloat Floats.FloatAxioms.
From MetaCoq.Template Require Import utils BasicAst Universes.
Require Import ssreflect.
From Equations Require Import Equations.

#[program,global] Instance reflect_prim_int : ReflectEq Numbers.Cyclic.Int63.Int63.int :=
  { eqb := Numbers.Cyclic.Int63.Int63.eqb }.
Next Obligation.
  destruct (Int63.eqb x y) eqn:eq; constructor.
  now apply (Numbers.Cyclic.Int63.Int63.eqb_spec x y) in eq.
  now apply (Numbers.Cyclic.Int63.Int63.eqb_false_spec x y) in eq.
Qed.
 
Derive NoConfusion EqDec for SpecFloat.spec_float.

Local Obligation Tactic := idtac.

#[program,global] 
Instance reflect_prim_float : ReflectEq PrimFloat.float :=
  { eqb x y := eqb (ReflectEq := EqDec_ReflectEq SpecFloat.spec_float) (FloatOps.Prim2SF x) (FloatOps.Prim2SF y) }.
Next Obligation.
  intros. cbn -[eqb].
  destruct (eqb_spec (ReflectEq := EqDec_ReflectEq SpecFloat.spec_float) (FloatOps.Prim2SF x) (FloatOps.Prim2SF y)); constructor.
  now apply FloatAxioms.Prim2SF_inj.
  intros e; apply n. rewrite e.
  reflexivity.
Qed.

Definition eq_prop_level l1 l2 :=
  match l1, l2 with
  | PropLevel.lProp, PropLevel.lProp => true
  | PropLevel.lSProp, PropLevel.lSProp => true
  | _, _ => false
  end.

#[global, program] Instance reflect_prop_level : ReflectEq PropLevel.t := {
  eqb := eq_prop_level
}.
Next Obligation.
  destruct x, y.
  all: unfold eq_prop_level.
  all: try solve [ constructor ; reflexivity ].
  all: try solve [ constructor ; discriminate ].
Defined.

Definition eq_levels (l1 l2 : PropLevel.t + Level.t) :=
  match l1, l2 with
  | inl l, inl l' => eqb l l'
  | inr l, inr l' => eqb l l'
  | _, _ => false
  end.

#[global, program] Instance reflect_levels : ReflectEq (PropLevel.t + Level.t) := {
  eqb := eq_levels
}.
Next Obligation.
  destruct x, y.
  cbn -[eqb]. destruct (eqb_spec t t0). subst. now constructor.
  all:try (constructor; cong).
  cbn -[eqb]. destruct (eqb_spec t t0). subst; now constructor.
  constructor; cong.
Defined.


Definition eq_name na nb :=
  match na, nb with
  | nAnon, nAnon => true
  | nNamed a, nNamed b => eqb a b
  | _, _ => false
  end.

#[global, program] Instance reflect_name : ReflectEq name := {
  eqb := eq_name
}.
Next Obligation.
  intros x y. destruct x, y.
  - cbn. constructor. reflexivity.
  - cbn. constructor. discriminate.
  - cbn. constructor. discriminate.
  - unfold eq_name. destruct (eqb_spec i i0); nodec.
    constructor. f_equal. assumption.
Defined.

Definition eq_relevance r r' :=
  match r, r' with
  | Relevant, Relevant => true
  | Irrelevant, Irrelevant => true
  | _, _ => false
  end.

#[global, program] Instance reflect_relevance : ReflectEq relevance := {
  eqb := eq_relevance
}.
Next Obligation.
  intros x y. destruct x, y.
  - cbn. constructor. reflexivity.
  - cbn. constructor. discriminate.
  - cbn. constructor. discriminate.
  - simpl. now constructor.
Defined.

Definition eq_aname (na nb : binder_annot name) :=
  eqb na.(binder_name) nb.(binder_name) &&
  eqb na.(binder_relevance) nb.(binder_relevance).
  
#[global, program] Instance reflect_aname : ReflectEq aname := {
  eqb := eq_aname
}.
Next Obligation.
  intros x y. unfold eq_aname.
  destruct (eqb_spec x.(binder_name) y.(binder_name));
  destruct (eqb_spec x.(binder_relevance) y.(binder_relevance));
  constructor; destruct x, y; simpl in *; cong.
Defined.

Definition eq_def {A} `{ReflectEq A} (d1 d2 : def A) : bool :=
  match d1, d2 with
  | mkdef n1 t1 b1 a1, mkdef n2 t2 b2 a2 =>
    eqb n1 n2 && eqb t1 t2 && eqb b1 b2 && eqb a1 a2
  end.

#[global, program] Instance reflect_def : forall {A} `{ReflectEq A}, ReflectEq (def A) := {
  eqb := eq_def
}.
Next Obligation.
  intros A RA.
  intros x y. destruct x as [n1 t1 b1 a1], y as [n2 t2 b2 a2].
  unfold eq_def.
  destruct (eqb_spec n1 n2) ; nodec.
  destruct (eqb_spec t1 t2) ; nodec.
  destruct (eqb_spec b1 b2) ; nodec.
  destruct (eqb_spec a1 a2) ; nodec.
  cbn. constructor. subst. reflexivity.
Defined.

Definition eq_cast_kind (c c' : cast_kind) : bool :=
  match c, c' with
  | VmCast, VmCast
  | NativeCast, NativeCast
  | Cast, Cast => true
  | RevertCast, RevertCast => true
  | _, _ => false
  end.

#[global, program] Instance reflect_cast_kind : ReflectEq cast_kind :=
  { eqb := eq_cast_kind }.
Next Obligation.
  induction x, y. all: cbn. all: nodec.
  all: left. all: reflexivity.
Defined.

(* TODO: move *)
Lemma eq_universe_iff (u v : Universe.nonEmptyUnivExprSet) :
  u = v <-> u = v :> UnivExprSet.t.
Proof.
  destruct u, v; cbn; split. now inversion 1.
  intros ->. f_equal. apply uip.
Qed.
Lemma eq_universe_iff' (u v : Universe.nonEmptyUnivExprSet) :
  u = v <-> UnivExprSet.elements u = UnivExprSet.elements v.
Proof.
  etransitivity. apply eq_universe_iff.
  destruct u as [[u1 u2] ?], v as [[v1 v2] ?]; cbn; clear; split.
  now inversion 1. intros ->. f_equal. apply uip.
Qed.

#[global] Instance reflect_case_info : ReflectEq case_info := EqDec_ReflectEq case_info.

Derive NoConfusion NoConfusionHom for sig.
Derive NoConfusion NoConfusionHom for prod.

Definition eqb_context_decl {term : Type} (eqterm : term -> term -> bool) 
  (x y : BasicAst.context_decl term) :=
  let (na, b, ty) := x in
  let (na', b', ty') := y in
  eqb na na' && eq_option eqterm b b' && eqterm ty ty'.

#[global] Instance eq_decl_reflect {term} {Ht : ReflectEq term} : ReflectEq (BasicAst.context_decl term).
Proof.
  refine {| eqb := eqb_context_decl eqb |}.
  intros.
  destruct x as [na b ty], y as [na' b' ty']. cbn -[eqb].
  change (eq_option eqb b b') with (eqb b b').
  destruct (eqb_spec na na'); subst;
    destruct (eqb_spec b b'); subst;
      destruct (eqb_spec ty ty'); subst; constructor; congruence.
Qed.

Definition eqb_recursivity_kind r r' :=
  match r, r' with
  | Finite, Finite => true
  | CoFinite, CoFinite => true
  | BiFinite, BiFinite => true
  | _, _ => false
  end.

#[global] Instance reflect_recursivity_kind : ReflectEq recursivity_kind.
Proof.
  refine {| eqb := eqb_recursivity_kind |}.
  destruct x, y; simpl; constructor; congruence.
Defined.

Definition eqb_ConstraintType x y :=
  match x, y with
  | ConstraintType.Le n, ConstraintType.Le m => Z.eqb n m
  | ConstraintType.Eq, ConstraintType.Eq => true
  | _, _ => false
  end.

#[global] Instance reflect_ConstraintType : ReflectEq ConstraintType.t.
Proof.
  refine {| eqb := eqb_ConstraintType |}.
  destruct x, y; simpl; try constructor; try congruence.
  destruct (Z.eqb_spec z z0); constructor. now subst.
  cong.
Defined.

#[global] Instance Z_as_int : ReflectEq Int.Z_as_Int.t.
Proof.
  refine {| eqb := Z.eqb |}.
  apply Z.eqb_spec.
Defined.


Scheme level_lt_ind_dep := Induction for Level.lt_ Sort Prop.
Scheme constraint_type_lt_ind_dep := Induction for ConstraintType.lt_ Sort Prop.
Scheme constraint_lt_ind_dep := Induction for UnivConstraint.lt_ Sort Prop.
Derive Signature for UnivConstraint.lt_.
Derive Signature for le.
Set Equations With UIP.

Derive NoConfusion EqDec for comparison.

Lemma string_compare_irrel {s s'} {c} (H H' : string_compare s s' = c) : H = H'.
Proof.
  apply uip.
Qed.  

Scheme le_ind_prop := Induction for le Sort Prop.

Lemma nat_le_irrel {x y : nat} (l l' : x <= y) : l = l'.
Proof.
  induction l using le_ind_prop; depelim l'.
  - reflexivity.
  - lia.
  - lia.
  - f_equal. apply IHl.
Qed.

Lemma lt_level_irrel {x y : Level.t} (l l' : Level.lt_ x y) : l = l'.
Proof.
  induction l using level_lt_ind_dep; depelim l'; auto.
  - now replace l with l0 by apply uip.
  - f_equal. apply nat_le_irrel.
Qed.

Lemma constraint_type_lt_level_irrel {x y} (l l' : ConstraintType.lt_ x y) : l = l'.
Proof.
  induction l using constraint_type_lt_ind_dep; depelim l'; auto.
  f_equal. apply uip.
Qed.

Require Import RelationClasses.
    
Lemma constraint_lt_irrel (x y : UnivConstraint.t) (l l' : UnivConstraint.lt_ x y) : l = l'.
Proof.
  revert l'. induction l using constraint_lt_ind_dep.
  - intros l'. depelim l'.
    now rewrite (lt_level_irrel l l4).
    now elim (irreflexivity (R:=ConstraintType.lt) l4).
    now elim (irreflexivity l4).
  - intros l'; depelim l'.
    now elim (irreflexivity (R:=ConstraintType.lt) l).
    now rewrite (constraint_type_lt_level_irrel l l4).
    now elim (irreflexivity l4).
  - intros l'; depelim l'.
    now elim (irreflexivity l).
    now elim (irreflexivity l).
    now rewrite (lt_level_irrel l l4).
Qed.

Module LevelSetsUIP.
  Import LevelSet.Raw.
  
  Fixpoint levels_tree_eqb (x y : LevelSet.Raw.t) := 
  match x, y with
  | LevelSet.Raw.Leaf, LevelSet.Raw.Leaf => true
  | LevelSet.Raw.Node h l o r, LevelSet.Raw.Node h' l' o' r' => 
    eqb h h' && levels_tree_eqb l l' && eqb o o' && levels_tree_eqb r r'
  | _, _ => false
  end.
  
  Scheme levels_tree_rect := Induction for LevelSet.Raw.tree Sort Type.

  #[global] Instance levels_tree_reflect : ReflectEq LevelSet.Raw.t.
  Proof.
    refine {| eqb := levels_tree_eqb |}.
    induction x using levels_tree_rect; destruct y; try constructor; auto; try congruence.
    cbn [levels_tree_eqb].
    destruct (eqb_spec t0 t2); try constructor; auto; try congruence.
    destruct (IHx1 y1); try constructor; auto; try congruence.
    destruct (eqb_spec t1 t3); try constructor; auto; try congruence.
    destruct (IHx2 y2); try constructor; auto; try congruence.
  Qed.
  
  Derive NoConfusion for LevelSet.Raw.tree.
  Derive Signature for LevelSet.Raw.bst.
  
  Definition eqb_LevelSet x y :=
    eqb (LevelSet.this x) (LevelSet.this y).
  
  Lemma ok_irrel (x : t) (o o' : Ok x) : o = o'.
  Proof.
    unfold Ok in *.
    induction o.
    - now depelim o'.
    - depelim o'. f_equal; auto.
      clear -l0 l2. red in l0, l2.
      extensionality y. extensionality inl.
      apply lt_level_irrel.
      extensionality y. extensionality inl.
      apply lt_level_irrel.
  Qed.

  #[global] Instance reflect_LevelSet : ReflectEq LevelSet.t.
  Proof.
    refine {| eqb := eqb_LevelSet |}.
    intros [thisx okx] [thisy oky].
    unfold eqb_LevelSet.
    cbn -[eqb].
    destruct (eqb_spec thisx thisy); subst; constructor.
    - f_equal. apply ok_irrel.
    - congruence.
  Defined.
End LevelSetsUIP.

Module ConstraintSetsUIP.
  Import ConstraintSet.Raw.

  Fixpoint cs_tree_eqb (x y : t) := 
    match x, y with
    | ConstraintSet.Raw.Leaf, ConstraintSet.Raw.Leaf => true
    | ConstraintSet.Raw.Node h l o r, ConstraintSet.Raw.Node h' l' o' r' => 
      eqb h h' && cs_tree_eqb l l' && eqb o o' && cs_tree_eqb r r'
    | _, _ => false
    end.

  Scheme cs_tree_rect := Induction for ConstraintSet.Raw.tree Sort Type.

  #[global] Instance cs_tree_reflect : ReflectEq ConstraintSet.Raw.t.
  Proof.
    refine {| eqb := cs_tree_eqb |}.
    induction x using cs_tree_rect; destruct y; try constructor; auto; try congruence.
    cbn [cs_tree_eqb].
    destruct (eqb_spec t0 t1); try constructor; auto; try congruence.
    destruct (IHx1 y1); try constructor; auto; try congruence.
    destruct (eqb_spec p p0); try constructor; auto; try congruence.
    destruct (IHx2 y2); try constructor; auto; try congruence.
  Qed.

  Definition eqb_ConstraintSet x y :=
    eqb (ConstraintSet.this x) (ConstraintSet.this y).

  Derive NoConfusion for ConstraintSet.Raw.tree.
  Derive Signature for ConstraintSet.Raw.bst.

  Lemma ok_irrel (x : t) (o o' : Ok x) : o = o'.
  Proof.
    unfold Ok in *.
    induction o.
    - now depelim o'.
    - depelim o'. f_equal; auto.
      clear -l0 l2. red in l0, l2.
      extensionality y. extensionality inl.
      apply constraint_lt_irrel.
      extensionality y. extensionality inl.
      apply constraint_lt_irrel.
  Qed.

  #[global] Instance reflect_ConstraintSet : ReflectEq ConstraintSet.t.
  Proof.
    refine {| eqb := eqb_ConstraintSet |}.
    intros [thisx okx] [thisy oky].
    unfold eqb_ConstraintSet. cbn.
    cbn -[eqb].
    destruct (eqb_spec thisx thisy); subst; constructor.
    - f_equal. apply ok_irrel.
    - congruence.
  Defined.

End ConstraintSetsUIP.

Ltac finish_reflect :=
  (repeat
    match goal with
    | |- context[eqb ?a ?b] => destruct (eqb_spec a b); [subst|constructor; congruence]
    end);
  constructor; trivial; congruence.

Definition eqb_universes_decl x y :=
  match x, y with
  | Monomorphic_ctx, Monomorphic_ctx => true
  | Polymorphic_ctx cx, Polymorphic_ctx cy => eqb cx cy
  | _, _ => false
  end.
  
#[global] Instance reflect_universes_decl : ReflectEq universes_decl.
Proof.
  refine {| eqb := eqb_universes_decl |}.
  unfold eqb_universes_decl.
  intros [] []; finish_reflect.
Defined.

Definition eqb_allowed_eliminations x y :=
  match x, y with
  | IntoSProp, IntoSProp
  | IntoPropSProp, IntoPropSProp
  | IntoSetPropSProp, IntoSetPropSProp
  | IntoAny, IntoAny => true
  | _, _ => false
  end.

#[global] Instance reflect_allowed_eliminations : ReflectEq allowed_eliminations.
Proof.
  refine {| eqb := eqb_allowed_eliminations |}.
  intros [] []; simpl; constructor; congruence.
Defined.

Local Infix "==?" := eqb (at level 20).

Definition eqb_Variance x y :=
  match x, y with
  | Variance.Irrelevant, Variance.Irrelevant
  | Variance.Covariant, Variance.Covariant
  | Variance.Invariant, Variance.Invariant => true
  | _, _ => false
  end.

#[global] Instance reflect_Variance : ReflectEq Variance.t.
Proof.
  refine {| eqb := eqb_Variance |}.
  intros [] []; constructor; congruence.
Defined.
