When writing Rust code, follow the following conventions:
  1. Error handling:
    - anyhow + .context() at app level, custom error types in domain code
    - bail!() for early error returns
    - No unwrap() in production code
  2. Option/Result style:
    - Prefer ? with .context(), .ok_or(), if let, and match — avoid unwrap()
    - Chain with .map(), .filter(), .and_then() over nested if let
  3. Iterators:
    - Prefer iterator chains and functional composition over imperative loops
    - Return impl Iterator to avoid unnecessary allocations
    - Use .find(), .find_map() over manual searching
  4. Documentation:
    - Do not explain program logic, unless its not self evident. Focus comments on developer intent and why decisions are made.
    - Document public APIs well for crate consumers
