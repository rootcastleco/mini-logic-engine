;;;; mini-logic.lisp
;;;;
;;;; A tiny Prolog-like logic programming engine in Common Lisp.
;;;; Features:
;;;;   - Logic variables (symbols starting with '?')
;;;;   - Facts and rules
;;;;   - Unification with occurs-check
;;;;   - Backtracking proof search
;;;;   - Simple query interface
;;;;
;;;; Usage:
;;;;   (load "src/mini-logic.lisp")
;;;;   (demo)

;;;; ------------------------------------------------------------
;;;; Variable detection
;;;; Variables are symbols whose printed name starts with '?'
;;;; Example: ?x, ?y, ?who
;;;; ------------------------------------------------------------

(defun var-p (x)
  "Return T if X is a logic variable (a symbol starting with '?')."
  (and (symbolp x)
       (> (length (symbol-name x)) 0)
       (char= (char (symbol-name x) 0) #\?)))

;;;; ------------------------------------------------------------
;;;; Substitution representation
;;;; A substitution is an association list: ((var . value) ...)
;;;; walk / occurs-check / extend-subst
;;;; ------------------------------------------------------------

(defun walk (u subst)
  "Follow substitution chains for U in SUBST, returning its final value.
If U is unbound, return U itself."
  (let ((binding (assoc u subst)))
    (if binding
        (walk (cdr binding) subst)
        u)))

(defun occurs-in-term-p (var term subst)
  "Return T if VAR occurs in TERM under SUBST (occurs-check).
Prevents creating infinite terms such as ?x = (f ?x)."
  (setf term (walk term subst))
  (cond
    ((eql var term) t)
    ((consp term)
     (or (occurs-in-term-p var (car term) subst)
         (occurs-in-term-p var (cdr term) subst)))
    (t nil)))

(defun extend-subst (var val subst)
  "Extend SUBST with a safe binding VAR = VAL if it passes occurs-check.
Return the new substitution or NIL if it fails."
  (if (occurs-in-term-p var val subst)
      nil
      (acons var val subst)))

;;;; ------------------------------------------------------------
;;;; Unification
;;;; ------------------------------------------------------------

(defun unify (x y subst)
  "Attempt to unify terms X and Y under substitution SUBST.
On success, return an extended substitution.
On failure, return NIL."
  (let* ((x (walk x subst))
         (y (walk y subst)))
    (cond
      ;; Same object -> no change
      ((eql x y) subst)

      ;; X is a variable
      ((var-p x)
       (extend-subst x y subst))

      ;; Y is a variable
      ((var-p y)
       (extend-subst y x subst))

      ;; Both are cons cells -> unify car then cdr
      ((and (consp x) (consp y))
       (let ((s1 (unify (car x) (car y) subst)))
         (and s1 (unify (cdr x) (cdr y) s1))))

      ;; Otherwise, they do not unify
      (t nil))))

;;;; ------------------------------------------------------------
;;;; Logic database
;;;; Each clause is one of:
;;;;   - Fact:  (parent alice bob)
;;;;   - Rule:  (:- (ancestor ?x ?y) (parent ?x ?z) (ancestor ?z ?y))
;;;; ------------------------------------------------------------

(defparameter *db* nil
  "Logic database: a list of clauses (facts and rules).")

(defun add-clause (clause)
  "Add CLAUSE to the global logic database *db*.
Return the added clause."
  (push clause *db*)
  clause)

(defmacro <-
    (head &body body)
  "Define a fact or rule and add it to the global database *db*.

Facts:
  (<- (parent alice bob))

Rules:
  (<- (ancestor ?x ?y)
      (parent ?x ?y))

  (<- (ancestor ?x ?y)
      (parent ?x ?z)
      (ancestor ?z ?y))"
  (if body
      `(add-clause '(:- ,head ,@body))
      `(add-clause ',head)))

;;;; ------------------------------------------------------------
;;;; Variable renaming (standardizing apart)
;;;; Each time we use a clause, we rename its variables to fresh ones.
;;;; This avoids variable capture between different clause applications.
;;;; ------------------------------------------------------------

(defun rename-term (term env)
  "Rename all variables in TERM using ENV (an alist VAR -> FRESH-VAR).
If a variable is not yet in ENV, create a new gensym for it."
  (cond
    ((var-p term)
     (or (cdr (assoc term env))
         (let* ((base (symbol-name term))
                (fresh (gensym base)))
           (push (cons term fresh) env)
           fresh)))
    ((consp term)
     (cons (rename-term (car term) env)
           (rename-term (cdr term) env)))
    (t term)))

(defun rename-clause (clause)
  "Return a fresh copy of CLAUSE with all variables renamed to new symbols."
  (let ((env nil))
    (rename-term clause env)))

;;;; ------------------------------------------------------------
;;;; Clause utilities
;;;; ------------------------------------------------------------

(defun clause-head-and-body (clause)
  "Split CLAUSE into HEAD and BODY-LIST.
If CLAUSE is a fact, BODY-LIST is NIL.
If CLAUSE is a rule of the form (:- head body1 body2 ...),
then HEAD is HEAD and BODY-LIST is (body1 body2 ...)."
  (if (and (consp clause)
           (eq (car clause) ':-))
      (let ((head (cadr clause))
            (body (cddr clause)))
        (values head body))
      ;; Fact: only a head, no body
      (values clause nil)))

;;;; ------------------------------------------------------------
;;;; Proof search
;;;; ------------------------------------------------------------

(defun prove (goal subst)
  "Attempt to prove a single GOAL under substitution SUBST.
Return a list of resulting substitutions (solutions)."
  (let ((solutions '()))
    (dolist (clause *db* (nreverse solutions))
      (let* ((fresh-clause (rename-clause clause))
             (head nil)
             (body nil))
        (multiple-value-setq (head body)
          (clause-head-and-body fresh-clause))
        (let ((s1 (unify goal head subst)))
          (when s1
            (if (null body)
                ;; Fact: no body, s1 is a solution
                (push s1 solutions)
                ;; Rule: prove all goals in the body
                (dolist (s2 (prove-goals body s1))
                  (push s2 solutions))))))))

(defun prove-goals (goals subst)
  "Attempt to prove a list of GOALS under substitution SUBST.
Return a list of resulting substitutions (solutions)."
  (if (null goals)
      ;; No more goals: current substitution is a solution
      (list subst)
      ;; Prove first goal, then recursively prove the rest
      (mapcan (lambda (s1)
                (prove-goals (cdr goals) s1))
              (prove (car goals) subst))))

;;;; ------------------------------------------------------------
;;;; Query interface
;;;; ------------------------------------------------------------

(defun run-query (goals vars &optional max-solutions)
  "Run a query given by GOALS and return a list of substitutions
restricted to the variables in VARS.

Arguments:
  GOALS         A list of goals, e.g. '((ancestor alice ?who))
  VARS          A list of variables whose bindings you want to see,
                e.g. '(?who)
  MAX-SOLUTIONS Optional integer limit on the number of returned solutions.

Return value:
  A list of solutions. Each solution is an alist:
    ((?who . alice) (?x . bob) ...)"
  (let* ((all-solutions (prove-goals goals nil))
         (solutions (if (and max-solutions
                             (> (length all-solutions) max-solutions))
                        (subseq all-solutions 0 max-solutions)
                        all-solutions)))
    (mapcar (lambda (subst)
              (mapcar (lambda (v)
                        (cons v (walk v subst)))
                      vars))
            solutions)))

(defun pretty-solution (solution)
  "Print a single SOLUTION (an alist VAR . VALUE) in a human-readable way."
  (dolist (pair solution)
    (format t "~A = ~A~%" (car pair) (cdr pair)))
  (terpri))

(defun pretty-run (goals vars &optional max-solutions)
  "Run GOALS and print solutions for VARS in a nice format.
If MAX-SOLUTIONS is non-NIL, print at most that many solutions."
  (let ((solutions (run-query goals vars max-solutions)))
    (if (null solutions)
        (format t "No solutions.~%")
        (loop for i from 1
              for sol in solutions do
                (format t "Solution ~D:~%" i)
                (pretty-solution sol)))))

;;;; ------------------------------------------------------------
;;;; Demo: small family tree
;;;; Call (demo) after loading this file.
;;;; ------------------------------------------------------------

(defun demo ()
  "Populate *db* with a small family tree and run sample queries."
  (setf *db* nil)

  ;; Facts
  (<- (parent alice bob))
  (<- (parent bob   charlie))
  (<- (parent bob   diana))
  (<- (parent diana emma))

  ;; Rules
  (<- (ancestor ?x ?y)
      (parent ?x ?y))

  (<- (ancestor ?x ?y)
      (parent ?x ?z)
      (ancestor ?z ?y))

  (format t "Question: Who are Alice's descendants?~%")
  (pretty-run '((ancestor alice ?who)) '(?who))

  (format t "~%Question: Who are Bob's descendants?~%")
  (pretty-run '((ancestor bob ?who)) '(?who))

  (format t "~%Question: All ancestor-descendant pairs (first 5 solutions):~%")
  (pretty-run '((ancestor ?x ?y)) '(?x ?y) 5))
