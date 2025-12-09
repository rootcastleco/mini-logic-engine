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
- **Facts**: Define facts using the `<-` macro:
  ```lisp
  (<- (parent alice bob))
  ```

- **Rules**: Define rules with heads and bodies:
  ```lisp
  (<- (ancestor ?x ?y)
      (parent ?x ?y))

  (<- (ancestor ?x ?y)
      (parent ?x ?z)
      (ancestor ?z ?y))
  ```

- **Unification**: Full unification with occurs-check to prevent infinite terms.
- **Backtracking**: Automatic backtracking search through the clause database.
- **Querying**: Run queries with multiple goals and retrieve variable bindings.

---

## Installation

Simply load the file in your Common Lisp environment:

```lisp
(load "mini-logic.lisp")
```

---

## API Overview

- `*db*` - Global logic database (a list of clauses)
- `(<- head &body body)` - Macro to add facts and rules to the database
- `run-query` - Returns solutions as substitutions
- `pretty-run` - Runs a query and prints solutions in a readable format
- `demo` - Populates a toy family tree and runs sample queries

---

## Usage Example

After loading the file, you can define facts and rules:

```lisp
;; Define some facts
(<- (parent alice bob))
(<- (parent bob charlie))
(<- (parent bob diana))

;; Define rules
(<- (ancestor ?x ?y)
    (parent ?x ?y))

(<- (ancestor ?x ?y)
    (parent ?x ?z)
    (ancestor ?z ?y))

;; Query the database
(pretty-run '((ancestor alice ?who)) '(?who))
```

Or simply run the built-in demo:

```lisp
(demo)
```

---

## Query Interface

The engine provides two main query functions:

### `run-query`

```lisp
(run-query goals vars &optional max-solutions)
```

Returns a list of substitutions for the specified variables.

**Arguments:**
- `goals` - A list of goals to prove
- `vars` - A list of variables whose bindings you want to see
- `max-solutions` - Optional limit on the number of solutions

**Returns:** A list of solutions, where each solution is an association list of variable bindings.

### `pretty-run`

```lisp
(pretty-run goals vars &optional max-solutions)
```

Runs a query and prints the solutions in a human-readable format.

---

## Implementation Details

The engine implements:

- **Variable detection**: Symbols starting with `?` are treated as logic variables
- **Substitution**: Variables are bound using association lists
- **Occurs-check**: Prevents creation of infinite terms like `?x = (f ?x)`
- **Unification**: Robinson's unification algorithm with occurs-check
- **Clause renaming**: Variables are renamed (standardized apart) to avoid capture
- **Proof search**: Depth-first search with backtracking over all matching clauses

---

## Authors

This code was written by:
- Batuhan Ayribas
- rootcastle

---

## License

MIT License - See LICENSE file for details.
