---
description: Refactor a function into a well-structured, modular form (helpers, validation, error handling, docs).
argument-hint: <function_name>
---

Modularize the function `$ARGUMENTS` in this codebase.

1. Locate the function (search the codebase; if there are several matches, pick the most likely or ask which one). Read it and its callers and tests first.
2. Refactor it so that:
   - Distinct responsibilities are extracted into small, well-named helper functions.
   - Input validation is added at the boundary, and errors are handled explicitly with clear messages (follow the project's existing error-handling style).
   - The function and each helper have clear documentation (docstring or JSDoc/equivalent in the project's style).
   - It follows modularity best practices and the conventions of the surrounding code (naming, formatting, file layout).
3. Preserve observable behavior and the public signature unless a change is required for correctness; if one is, call it out explicitly.
4. Update call sites and existing tests if needed, and run the project's tests or type checks if available.
5. Finish with a short summary: what was extracted, what validation/error handling was added, and anything that changed behavior.

If no function name was given, ask which function to modularize.
