(* Distributed under the terms of the MIT license. *)
From Coq Require Import ssreflect ssrbool.
From MetaCoq.Template Require Import config utils.
From MetaCoq.Template Require Ast TypingWf WfAst TermEquality.
Set Warnings "-notation-overridden".
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICCumulativity
     PCUICLiftSubst PCUICEquality PCUICUnivSubst PCUICTyping TemplateToPCUIC
     PCUICWeakeningConv PCUICWeakeningTyp PCUICSubstitution PCUICGeneration
     PCUICClosed PCUICCSubst.
Set Warnings "+notation-overridden".

From Equations.Prop Require Import DepElim.
Implicit Types cf : checker_flags.

(* Source = Template, Target (unqualified) = Coq *)

Module SEq := Template.TermEquality.
Module ST := Template.Typing.
Module SL := Template.LiftSubst.

From MetaCoq.PCUIC Require Import TemplateToPCUIC TemplateToPCUICCorrectness.
From MetaCoq.Template Require Import TypingWf WcbvEval.
From MetaCoq.PCUIC Require Import PCUICCSubst PCUICCanonicity PCUICWcbvEval.


Tactic Notation "wf_inv" ident(H) simple_intropattern(p) :=
  (eapply WfAst.wf_inv in H; progress cbn in H; try destruct H as p) || 
  (apply WfAst.wf_mkApps_napp in H; [|easy]; try destruct H as p).

Lemma eval_mkApps_inv Σ f args v :
  eval Σ (mkApps f args) v ->
  ∑ f', eval Σ f f' ×  eval Σ (mkApps f' args) v.
Proof.
  revert f v; induction args using rev_ind; cbn; intros f v.
  - intros ev. exists v. split => //. eapply eval_to_value in ev.
    now eapply value_final.
  - rewrite mkApps_app. intros ev.
    depelim ev.
    + specialize (IHargs _ _ ev1) as [f' [evf' evars]].
      exists f'. split => //.
      rewrite mkApps_app.
      eapply eval_beta; tea.
    + specialize (IHargs _ _ ev1) as [f' [evf' ev]].
      exists f'; split => //.
      rewrite mkApps_app.
      eapply eval_fix; tea.
    + specialize (IHargs _ _ ev1) as [f' [evf' ev]].
      exists f'; split => //.
      rewrite mkApps_app.
      eapply eval_fix_value; tea.
    + specialize (IHargs _ _ ev1) as [f'' [evf' ev]].
      exists f''; split => //.
      rewrite mkApps_app.
      eapply eval_app_cong; tea.
    + cbn in i. discriminate.
Qed.

Lemma list_length_rev_ind {A} (P : list A -> Type) (p0 : P [])
  (pS : forall d Γ, (forall Γ', #|Γ'| <= #|Γ|  -> P Γ') -> P (Γ ++ [d])) 
  Γ : P Γ.
Proof.
  generalize (le_n #|Γ|).
  generalize #|Γ| at 2.
  induction n in Γ |- *.
  destruct Γ using rev_case; [|simpl; intros; elimtype False; try lia].
  cbn. intros; exact p0. len in H.
  intros.
  destruct Γ using rev_case; simpl in *. 
  apply p0. apply pS. intros. apply IHn. len in H.
Qed.

Lemma eval_eval {Σ t u v} : eval Σ t u -> eval Σ u v -> u = v.
Proof.
  intros ev ev'.
  pose proof (eval_to_value _ _ _ ev) as vf'.
  pose proof (value_final Σ _ vf').
  epose proof (eval_deterministic ev' X). now subst.
Qed.

Lemma eval_tApp {Σ f f' a v} :
  eval Σ f f' ->
  eval Σ (tApp f' a) v ->
  eval Σ (tApp f a) v.
Proof.
  intros evf eva.
  depelim eva.
  - pose proof (eval_eval evf eva1); subst.
    econstructor; tea.
  - pose proof (eval_eval evf eva1); subst.
    eapply eval_fix; tea.
  - pose proof (eval_eval evf eva1); subst.
    eapply eval_fix_value; tea.
  - pose proof (eval_eval evf eva1); subst.
    eapply eval_app_cong; tea.
  - now cbn in i.
Qed.

Lemma eval_mkApps Σ f f' args v :
  eval Σ f f' ->
  eval Σ (mkApps f' args) v ->
  eval Σ (mkApps f args) v.
Proof.
  induction args in f, f', v |- *; cbn.
  - intros. pose proof (eval_eval X X0); now subst.
  - intros evf evapp.
    eapply eval_mkApps_inv in evapp as [fn [evfn evv]].
    epose proof (eval_tApp evf evfn).
    now specialize (IHargs _ _ _ X evv).
Qed.

Lemma csubst_mkApps a k f l : 
  csubst a k (mkApps f l) = mkApps (csubst a k f) (map (csubst a k) l).
Proof.
  induction l in f |- *; cbn; auto.
  rewrite IHl.
  now cbn.
Qed.

Ltac dest_lookup := 
  destruct lookup_inductive as [[mdecl idecl]|].
  
Lemma trans_csubst {cf} Σ a k b :
  Typing.wf Σ ->
  let Σ' := trans_global_env Σ in
  wf Σ' ->
  WfAst.wf Σ a ->
  trans Σ' (WcbvEval.csubst a k b) = csubst (trans Σ' a) k (trans Σ' b).
Proof.
  intros wfΣ Σ' wfΣ' wfa.
  revert wfa k.
  induction b using Template.Induction.term_forall_list_ind; simpl; intros; try congruence; 
    try solve [repeat (f_equal; eauto)].

  - cbn. destruct (k ?= n); auto.
  - simpl. f_equal; solve_list.
  - rewrite trans_mkApps csubst_mkApps. f_equal; eauto.
    solve_list.

  - destruct X; red in X0.
    dest_lookup; cbn; f_equal; auto.
    unfold trans_predicate, map_predicate_k; cbn.
    f_equal; auto. solve_list.
    + rewrite map2_bias_left_length. 
      now rewrite e.
    + rewrite map_map2 !PCUICUnivSubstitutionConv.map2_map_r.
      clear -wfa X0. cbn.
      generalize (ind_ctors idecl).
      induction X0; simpl; auto. destruct l; reflexivity.
      intros l0; destruct l0; try reflexivity.
      cbn. rewrite IHX0. f_equal.
      rewrite /trans_branch /= p // /map_branch /map_branch_k /= /id. f_equal.
      now rewrite map2_bias_left_length.
    + unfold subst_predicate, id => /=.
      f_equal; auto; solve_all.
  - f_equal; auto; solve_list.
  - f_equal; auto; solve_list.
Qed.

Lemma trans_substl {cf} Σ a b :
  Typing.wf Σ ->
  let Σ' := trans_global_env Σ in
  wf Σ' ->
  All (WfAst.wf Σ) a ->
  trans Σ' (WcbvEval.substl a b) = substl (map (trans Σ') a) (trans Σ' b).
Proof.
  intros wfΣ Σ' wfΣ'.
  induction 1 in b |- *; cbn; auto.
  rewrite IHX. rewrite trans_csubst //.
Qed.

Lemma eval_to_stuck_fix_inv {Σ mfix idx narg fn t args} :
  cunfold_fix mfix idx = Some (narg, fn) ->
  eval Σ t (mkApps (tFix mfix idx) args) ->
  #|args| <= narg.
Proof.
  intros uf ev.
  apply eval_to_value in ev.
  apply value_mkApps_inv in ev as [[(-> & ?)|]|]; try (cbn; easy).
  unfold isStuckFix in *.
  rewrite uf in p.
  destruct p. now eapply Nat.leb_le in i.
Qed.

Lemma eval_stuck_fix {Σ mfix idx narg fn args args'} :
  All2 (eval Σ) args args' ->
  cunfold_fix mfix idx = Some (narg, fn) ->
  #|args| <= narg ->
  eval Σ (mkApps (tFix mfix idx) args) (mkApps (tFix mfix idx) args').
Proof.
  revert args' narg; induction args using rev_ind; intros args' narg ha.
  - depelim ha.
    intros cunf _.
    eapply eval_atom => //.
  - eapply All2_app_inv_l in ha as [argsv [xv [? []]]].
    depelim a0. depelim a0. subst args'. len.
    intros cunf lt.
    specialize (IHargs _ _ a cunf ltac:(lia)).
    rewrite !mkApps_app /=. eapply eval_tApp. exact IHargs.
    eapply eval_fix_value; tea.
    eapply value_final. now eapply eval_to_value in IHargs.
    rewrite -(All2_length a). lia.
Qed.
 
Lemma eval_value_cong Σ f x y res : 
  value f -> 
  eval Σ x y ->
  eval Σ (tApp f y) res ->
  eval Σ (tApp f x) res.
Proof.
  intros.
  depelim X1.
  - pose proof (eval_eval X0 X1_2). subst a'.
    eapply eval_beta; tea.
  - pose proof (eval_eval X0 X1_2). subst av.
    eapply eval_fix; tea.
  - pose proof (eval_eval X0 X1_2). subst av.
    eapply eval_fix_value; tea.
  - pose proof (eval_eval X0 X1_2). subst a'.
    eapply eval_app_cong; tea.
  - now cbn in i.
Qed.

Lemma eval_mkApps_value_cong Σ f x y res : 
  value f -> 
  All2 (eval Σ) x y ->
  eval Σ (mkApps f y) res ->
  eval Σ (mkApps f x) res.
Proof.
  intros vf a. revert y a res.
  induction x using rev_ind; cbn; intros y a res.
  - depelim a; auto.
  - eapply All2_app_inv_l in a as [r1 [r2 [? []]]]. subst y.
    depelim a0. depelim a0.
    intros ev.
    specialize (IHx _ a).
    rewrite mkApps_app in ev.
    eapply eval_mkApps_inv in ev as [f' [evf' evargs]].
    specialize (IHx _ evf').
    rewrite mkApps_app.
    eapply eval_mkApps; tea.
    eapply eval_value_cong; tea.
    now eapply eval_to_value in IHx.
Qed.

Lemma eval_mkApps_fix {Σ : global_env} {f mfix idx argsv args' argsv' fn res narg} :
  eval Σ f (mkApps (tFix mfix idx) argsv) ->
  All2 (eval Σ) args' argsv' ->
  cunfold_fix mfix idx = Some (narg, fn) ->
  narg < #|argsv| + #|args'| ->
  eval Σ (mkApps (mkApps fn argsv) argsv') res -> 
  eval Σ (mkApps f args') res.
Proof.
  revert argsv argsv' res. induction args' using rev_ind; cbn; intros argsv argsv' res.
  - intros. depelim X0. cbn in *.
    eapply eval_to_stuck_fix_inv in X; tea.
    lia.
  - intros.
    rewrite mkApps_app /=.
    len in H0.
    destruct (eq_nat_dec narg (#|argsv| + #|args'|)).
    * subst.
      eapply All2_app_inv_l in X0 as [r1 [r2 [? []]]].
      depelim a0. depelim a0. subst argsv'.
      eapply (eval_fix _ _ _ _ (argsv ++ r1)); tea.
      2:{ erewrite H. rewrite (All2_length a). rewrite -app_length. reflexivity. }
      eapply eval_mkApps; tea.
      rewrite -mkApps_app.
      eapply eval_stuck_fix. eapply All2_app; tea.
      { eapply eval_to_value in X.
        eapply value_mkApps_inv in X as  [[(-> & ?)|]|]; auto.
        destruct p. eapply All_All2_refl, All_impl; tea; cbv beta.
        intros. now eapply value_final.
        destruct p. eapply All_All2_refl, All_impl; tea; cbv beta.
        intros. now eapply value_final. }
      tea. len.
      rewrite -mkApps_app in X1.
      rewrite -[tApp _ _](mkApps_app _ _ [y]) -app_assoc //.
    * eapply All2_app_inv_l in X0 as [r1 [r2 [? []]]].
      depelim a0. depelim a0. subst argsv'.
      rewrite mkApps_app in X1.
      eapply eval_mkApps_inv in X1 as [f' [evf' evapp]].
      specialize (IHargs' _ _ _ X a H ltac:(lia) evf').
      eapply eval_tApp; tea.
      eapply eval_value_cong; tea. now eapply eval_to_value in IHargs'.
Qed.

Lemma wf_csubst Σ t k u : WfAst.wf Σ t -> WfAst.wf Σ u -> WfAst.wf Σ (WcbvEval.csubst t k u).
Proof.
  intros wfts wfu.
  induction wfu in k using WfAst.term_wf_forall_list_ind; simpl; intros; 
  try solve[econstructor; cbn in *; eauto; solve_all].

  - destruct Nat.compare => //; constructor.
  - apply WfAst.wf_mkApps; auto. solve_all.
  - econstructor; cbn; tea. len. red in X0.
    solve_all. red in X0. solve_all. eauto.
    solve_all.
Qed.

Lemma wf_substl Σ ts u : All (WfAst.wf Σ) ts -> WfAst.wf Σ u -> WfAst.wf Σ (WcbvEval.substl ts u).
Proof.
  induction ts in u |- *; cbn; auto.
  intros al wfu; depelim al.
  eapply IHts => //.
  now eapply wf_csubst.
Qed.

Lemma wf_fix_subst Σ mfix :
  All (fun def : def Ast.term => Swf_fix Σ def) mfix ->
  All (WfAst.wf Σ) (Typing.fix_subst mfix).
Proof.
  unfold Typing.fix_subst.
  intros a.
  generalize #|mfix| => n.
  induction n; cbn; auto;
  constructor; auto. constructor; auto.
Qed.

Lemma wf_cofix_subst Σ mfix :
  All (fun def : def Ast.term => Swf_fix Σ def) mfix ->
  All (WfAst.wf Σ) (Typing.cofix_subst mfix).
Proof.
  unfold Typing.cofix_subst.
  intros a.
  generalize #|mfix| => n.
  induction n; cbn; auto;
  constructor; auto. constructor; auto.
Qed.

Lemma trans_fix_subst Σ mfix :
  fix_subst (map (map_def (trans (trans_global_env Σ)) (trans (trans_global_env Σ))) mfix) = 
  map (trans (trans_global_env Σ)) (Typing.fix_subst mfix).
Proof.
  unfold Typing.fix_subst, fix_subst.
  len. generalize #|mfix|; induction n; simpl; auto.
  f_equal; eauto.
Qed.

Lemma trans_cofix_subst Σ mfix :
  cofix_subst (map (map_def (trans (trans_global_env Σ)) (trans (trans_global_env Σ))) mfix) = 
  map (trans (trans_global_env Σ)) (Typing.cofix_subst mfix).
Proof.
  unfold Typing.cofix_subst, cofix_subst.
  len. generalize #|mfix|; induction n; simpl; auto.
  f_equal; eauto.
Qed.

Lemma wf_cunfold_fix {cf} {Σ mfix idx narg fn} :
  Typing.wf Σ -> 
  All (fun def : def Ast.term => Swf_fix Σ def) mfix ->
  WcbvEval.cunfold_fix mfix idx = Some (narg, fn) ->
  WfAst.wf Σ fn.
Proof.
  intros wf a.
  unfold WcbvEval.cunfold_fix.
  destruct nth_error eqn:hnth => //.
  intros [= <- <-].
  eapply wf_substl. now eapply wf_fix_subst.
  eapply nth_error_all in a; tea. cbn in a. 
  now destruct a.
Qed.

Lemma wf_cunfold_cofix {cf} {Σ mfix idx narg fn} :
  Typing.wf Σ -> 
  All (fun def : def Ast.term => Swf_fix Σ def) mfix ->
  WcbvEval.cunfold_cofix mfix idx = Some (narg, fn) ->
  WfAst.wf Σ fn.
Proof.
  intros wf a.
  unfold WcbvEval.cunfold_cofix.
  destruct nth_error eqn:hnth => //.
  intros [= <- <-].
  eapply wf_substl. now eapply wf_cofix_subst.
  eapply nth_error_all in a; tea. cbn in a. 
  now destruct a.
Qed.

Lemma trans_cunfold_fix {cf} {Σ mfix idx narg fn} :
  Typing.wf Σ -> 
  wf (trans_global_env Σ) ->
  All (fun def : def Ast.term => Swf_fix Σ def) mfix ->
  WcbvEval.cunfold_fix mfix idx = Some (narg, fn) ->
  cunfold_fix
    (map
    (map_def (trans (trans_global_env Σ)) (trans (trans_global_env Σ)))
      mfix) idx = Some (narg, trans (trans_global_env Σ) fn).
Proof.
  intros wfΣ wfΣ'.
  unfold WcbvEval.cunfold_fix, cunfold_fix.
  intros a; rewrite nth_error_map.
  destruct nth_error => /= //.
  intros [= <- <-]. f_equal. f_equal.
  rewrite (trans_substl Σ (Typing.fix_subst mfix) (dbody d)).
  now eapply wf_fix_subst. f_equal.
  now rewrite trans_fix_subst.
Qed.

Lemma trans_cunfold_cofix {cf} {Σ mfix idx narg fn} :
  Typing.wf Σ -> 
  wf (trans_global_env Σ) ->
  All (fun def : def Ast.term => Swf_fix Σ def) mfix ->
  WcbvEval.cunfold_cofix mfix idx = Some (narg, fn) ->
  cunfold_cofix
    (map
    (map_def (trans (trans_global_env Σ)) (trans (trans_global_env Σ)))
      mfix) idx = Some (narg, trans (trans_global_env Σ) fn).
Proof.
  intros wfΣ wfΣ'.
  unfold WcbvEval.cunfold_cofix, cunfold_cofix.
  intros a; rewrite nth_error_map.
  destruct nth_error => /= //.
  intros [= <- <-]. f_equal. f_equal.
  rewrite (trans_substl Σ (Typing.cofix_subst mfix) (dbody d)).
  now eapply wf_cofix_subst. f_equal.
  now rewrite trans_cofix_subst.
Qed.

Lemma Sfst_decompose_app_rec f l : fst (AstUtils.decompose_app (Ast.mkApps f l)) = fst (AstUtils.decompose_app f).
Proof.
  destruct f; cbn; induction l; cbn; auto.
Qed.

Lemma SisFixApp_mkApps f l : WcbvEval.isFixApp (Ast.mkApps f l) = WcbvEval.isFixApp f.
Proof.
  unfold WcbvEval.isFixApp.
  now rewrite Sfst_decompose_app_rec.
Qed.

Lemma isFixApp_mkApps f l : isFixApp (mkApps f l) = isFixApp f.
Proof.
  unfold isFixApp.
  erewrite <- (fst_decompose_app_rec _ []).
  rewrite /decompose_app decompose_app_rec_mkApps.
  now rewrite fst_decompose_app_rec.
Qed.

Lemma eval_mkApps_cong Σ f args : 
  value f -> All value args ->
  ~~ (isLambda f || isFixApp f || isArityHead f) ->
  eval Σ (mkApps f args) (mkApps f args).
Proof.
  intros vf a. move: a.
  induction args using rev_ind; intros a.
  - intros _. now eapply value_final.
  - intros hf. eapply All_app in a as [].
    depelim a0. depelim a0.
    rewrite !mkApps_app /=. eapply eval_app_cong; eauto.
    2:now eapply value_final.
    move/negP: hf => hf. apply/negP => hf'.
    apply hf.
    destruct args using rev_case; cbn in hf' => //.
    rewrite !mkApps_app /= orb_false_r in hf'.
    rewrite -[tApp _ _](mkApps_app _ _ [x0]) in hf'.
    rewrite isFixApp_mkApps in hf'. rewrite hf'.
    now rewrite orb_true_r orb_true_l.
Qed.

Lemma isLambda_mkApps {f args} : args <> [] -> ~~ isLambda (mkApps f args).
Proof.
  destruct args using rev_case; cbn; try congruence.
  rewrite mkApps_app /= //.
Qed.

Lemma isArityHead_mkApps {f args} : args <> [] -> ~~ isArityHead (mkApps f args).
Proof.
  destruct args using rev_case; cbn; try congruence.
  rewrite mkApps_app /= //.
Qed.

Lemma isFixApp_trans Σ f : ~~ Ast.isApp f -> isFixApp (trans Σ f) -> WcbvEval.isFixApp f.
Proof.
  rewrite /isFixApp /WcbvEval.isFixApp.
  destruct f => //.
  cbn. destruct lookup_inductive as [[]|]=> //.
Qed.

Lemma eval_wf {cf} {Σ} {wfΣ : ST.wf Σ} {T U} :
  WfAst.wf Σ T ->
  WcbvEval.eval Σ T U ->
  WfAst.wf Σ U.
Proof.
  intros wf ev.
  revert wf.
  induction ev using eval_evals_ind; cbn; intros wf.
  - wf_inv wf [[[napp argl] f'] hal].
    eapply IHev3. depelim hal.
    eapply WfAst.wf_mkApps => //.
    eapply wf_csubst; eauto.
    specialize (IHev1 f'). now wf_inv IHev1 [].
  - wf_inv wf [[hb0 ht] hb1]. eapply IHev2.
    eapply wf_csubst; eauto. 
  - wf_inv wf a. eapply IHev.
    eapply WfAst.wf_subst_instance.
    eapply declared_constant_wf in H.
    now rewrite H0 in H.
    apply typing_wf_sigma in wfΣ.
    now eapply on_global_wf_Forall_decls.

  - eapply IHev2.
    wf_inv wf [mdecl' [idecl' []]].
    destruct (declared_inductive_inj d (proj1 H0)). subst mdecl' idecl'.
    rewrite /Typing.iota_red. 
    eapply All2_nth_error in a1; tea.
    2:{ apply H0. }
    eapply WfAst.wf_subst. 
    * eapply All_rev, All_skipn.
      specialize (IHev1 w0).
      now wf_inv IHev1 [].
    * eapply wf_expand_lets => //.
      rewrite /bctx.
      eapply (wf_case_branch_context_gen (ind:=(ci.(ci_ind), c))); tea.
      now eapply typing_wf_sigma.
      eapply declared_inductive_wf_ctors.
      now eapply on_global_wf_Forall_decls, typing_wf_sigma.
      apply H0. apply a1.

  - apply IHev2.
    wf_inv wf H. specialize (IHev1 wf).
    wf_inv IHev1 [hc hargs].
    eapply nth_error_all in H; tea.

  - eapply IHev2.
    wf_inv wf [Hf Hargs].
    specialize (IHev1 Hf).
    wf_inv IHev1 [Hfix hargs].
    eapply WfAst.wf_mkApps.
    eapply wf_cunfold_fix; tea. now depelim Hfix.
    eapply All_app_inv => //.
    eapply All2_All_mix_left in X0; tea.
    eapply All2_All_right; tea; cbv beta; intuition auto.
    
  - wf_inv wf [Hf Hargs].
    specialize (IHev Hf).
    wf_inv IHev [Hfix hargs].
    eapply WfAst.wf_mkApps => //.
    eapply All_app_inv => //.
    eapply All2_All_mix_left in X0; tea.
    eapply All2_All_right; tea; cbv beta; intuition auto.

  - wf_inv wf [mdecl' [idecl' []]].
    eapply IHev.
    econstructor; tea.
    wf_inv w0 [hfix hargs].
    eapply WfAst.wf_mkApps => //.
    eapply wf_cunfold_cofix; tea. now depelim hfix.

  - wf_inv wf wf'.
    wf_inv wf [hcofix hargs]. depelim hcofix.
    eapply IHev.
    econstructor; tea.
    eapply WfAst.wf_mkApps => //.
    eapply wf_cunfold_cofix; tea.
    
  - wf_inv wf [[[hf ?]] ha].
    eapply WfAst.wf_mkApps; eauto.
    eapply All2_All_mix_left in X0; tea.
    eapply All2_All_right; tea; cbv beta; intuition auto.

  - auto.
Qed.

Lemma trans_wcbvEval {cf} {Σ} {wfΣ : ST.wf Σ} T U :
  let Σ' := trans_global_env Σ in
  wf Σ' ->
  WfAst.wf Σ T ->
  WcbvEval.eval Σ T U ->
  PCUICWcbvEval.eval Σ' (trans Σ' T) (trans Σ' U).
Proof.
  intros Σ' wfΣ' wf ev.
  move: wf.
  induction ev using eval_evals_ind; intros wf; cbn -[Σ'].
   
  - wf_inv wf [[[napp argl] wff] wfa].
    dependent elimination wfa as [All_cons (l:=l) wfx wfl].
    cbn [trans].
    rewrite trans_mkApps in IHev3.
    cbn -[Σ']. 
    (* cbn in cl; move: cl.
    rewrite closedn_mkApps => /andP[] /= /andP[] clf clx cll. *)
    specialize (IHev1 wff). specialize (IHev2 wfx).
    cbn -[Σ'] in IHev1.
    pose proof (eval_wf wfx ev2).
    pose proof (eval_wf wff ev1).
    wf_inv X0 [wft wfb].
    forward IHev3. { eapply WfAst.wf_mkApps => //. eapply wf_csubst; eauto. }
    eapply eval_mkApps_inv in IHev3 as [f' [evf' ev]].
    rewrite trans_csubst // in evf'.
    pose proof (eval_beta _ _ _ _ _ _ _ _ IHev1 IHev2 evf').
    eapply eval_mkApps; tea.
      
  - wf_inv wf [[hb0 ht] hb1].
    forward IHev1 by auto.
    pose proof (eval_wf hb0 ev1).
    forward IHev2. { eapply wf_csubst; eauto. }
    rewrite trans_csubst in IHev2; tea.
    econstructor; tea.
  
  - econstructor.
    eapply forall_decls_declared_constant; tea.
    rewrite /trans_constant_body H0 /=. reflexivity.
    rewrite -trans_subst_instance.
    eapply IHev. apply WfAst.wf_subst_instance.
    eapply declared_constant_wf in H.
    now rewrite H0 in H.
    apply typing_wf_sigma in wfΣ.
    now eapply on_global_wf_Forall_decls.

  - wf_inv wf [mdecl' [idecl' [decli ?]]].
    pose proof (declared_inductive_inj decli (proj1 H0)) as []. subst mdecl' idecl'.
    eapply forall_decls_declared_inductive in decli; tea.
    rewrite (declared_inductive_lookup _ decli).
    eapply All2_nth_error in a1; tea. 2:eapply H0.
    epose proof (forall_decls_declared_constructor _ _ _ _ _ _ _ H0) as decl'; tea.
    destruct a1.
    econstructor; tea.
    rewrite trans_mkApps in IHev1. eapply IHev1 => //.
    erewrite (nth_error_map2 _ _ _ _ _ _ (proj2 decl')).
    reflexivity.
    rewrite nth_error_map H /=. reflexivity.
    len. rewrite H1.
    { eapply All2_length in a1. len in a1.
      rewrite /bctx case_branch_context_assumptions //.
      rewrite /trans_branch /=.
      rewrite map2_map2_bias_left. len.
      rewrite PCUICCases.map2_set_binder_name_context_assumptions. len.
      len. now rewrite context_assumptions_map. }
    forward IHev2.
    { rewrite /Typing.iota_red. 
      eapply WfAst.wf_subst. 
      * eapply All_rev, All_skipn.
        eapply eval_wf in ev1; tea.
        now wf_inv ev1 [].
      * eapply wf_expand_lets => //.
        rewrite /bctx.
        eapply (wf_case_branch_context_gen (ind:=(ci.(ci_ind), c))); tea.
        now eapply typing_wf_sigma.
        eapply declared_inductive_wf_ctors.
        now eapply on_global_wf_Forall_decls, typing_wf_sigma.
        apply H0. }
    rewrite (trans_iota_red Σ ci.(ci_ind) mdecl idecl) in IHev2.
    { eapply All2_length in a1. len in a1. }
    apply IHev2.

  - wf_inv wf hdiscr.
    destruct indnpararg as ((?&?)&?).
    cbn in *; eapply eval_proj; tea.
    rewrite trans_mkApps in IHev1. 
    now eapply IHev1.
    rewrite nth_error_map H //.
    eapply IHev2.
    eapply eval_wf in ev1; tea.
    eapply WfAst.wf_mkApps_inv in ev1.
    eapply nth_error_all in ev1; tea.

  - rewrite trans_mkApps.
    eapply WfAst.wf_mkApps_napp in wf as []; tea.
    specialize (IHev1 w).
    rewrite trans_mkApps /= in IHev1.
    eapply eval_wf in ev1; tea.    
    eapply WfAst.wf_mkApps_napp in ev1 as [] => //.
    wf_inv w0 H.
    have wffn : WfAst.wf Σ fn.
    { now apply (wf_cunfold_fix (Σ := Σ)) in H0. }
    eapply trans_cunfold_fix in H0; tea.
    eapply eval_mkApps_fix; tea.
    eapply All2_All_mix_left in X0; tea.
    eapply All2_map, All2_impl; tea; cbv beta.
    intuition eauto. len.
    rewrite -mkApps_app -map_app.
    forward IHev2.
    eapply WfAst.wf_mkApps => //.
    eapply All_app_inv => //.
    eapply All2_All_mix_left in X; tea.
    clear X0; eapply All2_All_right; tea; cbv beta.
    intros ? ? []; now eapply eval_wf.
    now rewrite trans_mkApps in IHev2.

  - rewrite !trans_mkApps.
    eapply WfAst.wf_mkApps_napp in wf as []; tea.
    specialize (IHev w).
    eapply eval_mkApps; tea.
    rewrite trans_mkApps -mkApps_app map_app.
    rewrite !mkApps_app.
    rewrite trans_mkApps in IHev.
    eapply eval_to_value in IHev.
    pose proof (eval_wf w ev).
    eapply WfAst.wf_mkApps_napp in X1 as [] => //.
    eapply eval_mkApps_value_cong => //.
    eapply All2_map. eapply All2_All_mix_left in X0; tea.
    eapply All2_impl; tea; cbv beta. intuition eauto.
    eapply eval_mkApps. now eapply value_final.
    eapply value_final.
    rewrite -mkApps_app.
    eapply value_stuck_fix.
    eapply All_app_inv.
    { apply value_mkApps_inv in IHev as [[(-> & ?)|]|]; try (cbn; easy). }
    eapply All2_All_mix_left in X0; tea.
    eapply All_map, All2_All_right; tea; cbv beta.
    { intuition auto. eapply eval_to_value; tea. }
    unfold isStuckFix; cbn.
    eapply trans_cunfold_fix in H0; tea. rewrite H0. len.
    eapply Nat.leb_le. len in H1.
    now wf_inv w0 x.
  
  - wf_inv wf [mdecl' [idecl' [decli ?]]].
    pose proof (forall_decls_declared_inductive _ _ _ _ _ _ decli) as decli';  tea.
    rewrite (declared_inductive_lookup _ decli').
    eapply WfAst.wf_mkApps_napp in w0 as []; [|easy].
    wf_inv w0 x.
    rewrite trans_mkApps /=.  
    eapply red_cofix_case.
    eapply trans_cunfold_cofix; tea.
    rewrite /= (declared_inductive_lookup _ decli') trans_mkApps in IHev.
    apply IHev.
    econstructor; tea.
    eapply WfAst.wf_mkApps; tea.
    eapply wf_cunfold_cofix; tea.

  - wf_inv wf [hfix hargs].
    wf_inv wf [hfix ha].
    depelim hfix.
    forward IHev.
    { constructor. eapply WfAst.wf_mkApps => //.
      eapply wf_cunfold_cofix; tea. }
    rewrite trans_mkApps /=.
    eapply red_cofix_proj.
    eapply trans_cunfold_cofix; tea.
    cbn in IHev. now rewrite trans_mkApps in IHev.

  - wf_inv wf [[[] ?] ?].
    eapply All2_All_mix_left in X; tea.
    rewrite trans_mkApps.
    specialize (IHev w).
    eapply eval_mkApps; tea.
    eapply All2_All_mix_left in X0. 2:exact a0.
    eapply eval_mkApps_value_cong. eapply eval_to_value; tea.
    eapply All2_map.
    eapply All2_impl; tea; cbv beta.
    intuition eauto.
    eapply eval_mkApps_cong.
    { eapply eval_to_value; tea. }
    { eapply All_map, All2_All_right; tea; cbv beta; intuition auto. now eapply eval_to_value. }
    eapply eval_wf in ev; tea.
    clear -Σ' ev H1.
    destruct f' => //. cbn. cbn in H1.
    rewrite orb_false_r in H1. inv ev.
    apply/negP => hp.
    assert (map (trans Σ') args <> []).
    { intros ha; apply H0. destruct args; cbn in *; congruence. }
    move/negPf: (isLambda_mkApps (f:=trans Σ' f') H2) => hf. rewrite hf in hp.
    move/negPf: (isArityHead_mkApps (f:=trans Σ' f') H2) => hf'. rewrite hf' in hp.
    rewrite orb_false_r /= in hp.
    rewrite isFixApp_mkApps in hp.
    move/negP: H1 => H1. apply H1.
    rewrite AstUtils.mkApps_tApp //.
    rewrite H //. unfold AstUtils.is_empty. destruct args; try congruence => //.
    auto. rewrite SisFixApp_mkApps.
    eapply isFixApp_trans in hp => //.
    rewrite H //.
    cbn. destruct lookup_inductive as [[mdecl idecl]|]=> //.
    
  - eapply eval_atom.
    destruct t => //.
Qed.
