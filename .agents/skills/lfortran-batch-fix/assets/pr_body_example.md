# The PR description: an example

This is the body written for lfortran/lfortran#14720. Write yours the same way, with the same headings. The rules are in your `machine.md`, under "The PR description".

````markdown
Fixes #14720

## The issue

A user-defined `+` that takes an `integer(8)` was used with an `integer(4)`:

```fortran
interface operator(+)
    module procedure p      ! p(x, y): x is type(t), y is integer(8)
end interface
...
x = x + 1                   ! 1 is integer(4), not integer(8)
```

`p` does not fit, so the code is wrong and GFortran gives an error. LFortran crashed:

```
LCOMPILERS_ASSERT failed ... check_equal_type(i32, i64)
```

## Why it happened

`use_overloaded` looks for a user-defined operator that fits the operands. It checked only the type ("is it an integer?") and not the kind (4 or 8 bytes). So it called `p` with the wrong kind, and a later check stopped the compiler.

## The fix

`use_overloaded` in `src/libasr/asr_utils.cpp` now compares the full type, including the kind, with `check_equal_type`.

| Code | Before | After |
|---|---|---|
| `x + 1`, only an `integer(8)` version exists | crash | error: operator `+` undefined |
| `x + 1`, `integer(4)` and `integer(8)` versions exist | the first one listed is called | the `integer(4)` one is called |

## Tests

- `operator_overloading_45`: the right version is called for each kind. It fails on `main` and passes here.
- `continue_compilation_3.f90`: the wrong-kind case gives an error and not a crash.
- Local LLVM 11 suites pass: unit 18/18, reference, integration 4750/4750.
````
