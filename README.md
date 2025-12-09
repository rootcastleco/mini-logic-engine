# mini-logic-engine

A small Prolog-like logic programming engine written in Common Lisp.

It supports:

- Logic variables (e.g. `?x`, `?y`)
- Facts and rules
- Unification with occurs-check
- Backtracking search over a database of clauses
- Querying with multiple goals and returning substitutions

The engine is intentionally minimal but fully functional and easy to extend.

---

## Features

- **Logic variables**: Any symbol starting with `?` is treated as a variable.
- **Facts**:
  ```lisp
  (<- (parent alice bob))
  Rules:
  (<- (ancestor ?x ?y)
    (parent ?x ?y))

(<- (ancestor ?x ?y)
    (parent ?x ?z)
    (ancestor ?z ?y))
    API Overview
	•	*db* — Global logic database (a list of clauses)
	•	(<- head &body body) — Macro to add facts and rules
	•	run-query — Returns solutions as substitutions
	•	pretty-run — Runs a query and prints solutions
	•	demo — Populates a toy family tree and runs sample queries
