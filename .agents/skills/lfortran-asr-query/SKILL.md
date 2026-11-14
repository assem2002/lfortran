---
name: lfortran-asr-query
description: Read and query LFortran's ASR (and find which compiler phase or ASR pass goes wrong) without dumping the whole tree into context. Provides `asrq`, a script over `lfortran --show-asr --json` that prints scopes, one symbol, every node of a kind (casts, calls...), what one source line lowered to, ExternalSymbol resolution, what each ASR pass changed, and outline diffs between passes or compiler builds. Use it whenever you need to look at the ASR or AST of a Fortran file while diagnosing or fixing an LFortran bug, reviewing what semantics or a pass produced, deciding whether a bug is in parsing, semantics, an ASR pass or codegen, or comparing ASR before and after a fix, even if the user only says "show the ASR", "--show-asr", "which pass", "look at the tree" or "debug this MRE".
---

# Querying LFortran's ASR

Raw `--show-asr` output is large: a 61-line program gives about 3k tokens in the
default format, 7k with `--clojure` and 12k as JSON. Don't read it whole. Ask
the question you have with `asrq`, and read whole trees only for small pieces.

```bash
ASRQ=<skill>/scripts/asrq      # <skill> is this skill's folder
$ASRQ -h
```

## Which compiler it runs
`$LFORTRAN` if set, else `./src/bin/lfortran` (an in-tree `./build1.sh` build), else
`./build/src/bin/lfortran`, else `lfortran` on PATH. It prints the choice on stderr.
Never change PATH to steer it. Either run it from the worktree root or set
`LFORTRAN=/path/to/src/bin/lfortran` for that one command. Extra compiler flags go
after `--`, e.g. `$ASRQ find Cast x.f90 -- --with-intrinsic-mods`. Inside the
batch-fix build slot, `build_slot.sh <src> -- $ASRQ passes /abs/repro.f90` uses the
slot's fresh build, because the slot runs commands from its root.

## Pick the command for the question

| Question | Command |
|---|---|
| Is the AST already wrong (parser bug)? | `lfortran --show-ast --no-color x.f90` (asrq is ASR only) |
| What scopes and symbols exist? | `asrq scopes x.f90` |
| What did semantics make of procedure / variable / type `f`? | `asrq sym f x.f90` or `asrq sym m::f x.f90` |
| What did line N turn into? | `asrq line N x.f90` |
| Every cast / call / node of some kind | `asrq find Cast x.f90`, `asrq find '.*Call' x.f90` |
| Same, with each match's subtree | `asrq tree ArrayConstant x.f90` |
| Which symbol does a reference really reach? | `asrq resolve f@p x.f90` |
| Which pass changes or breaks it? | `asrq passes x.f90` |
| What does the ASR look like after pass P? | `asrq -p array_op line N x.f90` (any command takes `-p`) |
| What exactly did one pass change? | `asrq -p 24 dump x.f90 > a.json; asrq -p 25 dump x.f90 > b.json; asrq diff a.json b.json` |
| What did my fix change in the ASR? | dump with each compiler (`LFORTRAN=.../main/src/bin/lfortran asrq dump x.f90 > main.json`), then `asrq diff main.json fix.json` |
| Is the ASR fine and the bug in codegen? | `lfortran --show-llvm x.f90` |

## Reading the output
```
$ asrq line 27 m.f90
L27: r = f(w%x(1:2), w%n)
== p
Assignment  @27:1
  target: Var v=r@p  @27:1
  value: Cast kind=RealToReal : real(8)  @27:1
    arg: FunctionCall name=f@p : real(4)  @27:5  => m::f (Function)
      args: ArrayPhysicalCast old=DescriptorArray new=DescriptorArray : real(4)[:]  @27:7
      ...
```
- `field: Node` lines are children; `k=v` are scalar fields; `: type` is the node's type.
- `name@scope` is a symbol reference (`a@m::f` = `a` in function `f` of module `m`; `tu` is the top level).
- `=> m::f (Function)` is where a call goes after following ExternalSymbols.
- Types are compact: `allocatable real(4)[:]`, `real(4)[1:3] FixedSizeArray`, `type(t@m)`, `procedure(real(4)[:], integer(4)) -> real(4)`.
- `@L:C` is the source location.
- By default, false, empty and default-valued fields (`access=Public`, `storage=Default`, ...) and `dependencies` are hidden. Add `-a` to show every field, e.g. when a dependency list or default value is the suspect.

`asrq passes` prints one line per pass that changed the tree, as node-count deltas, then lists the unchanged passes:
```
08 implied_do_loops             +10 Var, +6 Assignment, ..., -1 ArrayConstant
25 array_op                     +11 Var, +10 Integer, ..., +1 DoLoop
unchanged: 01 global_stmts, 02 init_expr, ...
```
If a pass crashes or fails ASR verification (Debug builds verify after every pass), it
prints the end of the compiler output. The last pass listed is the last one that finished.
`-k DIR` keeps the per-pass JSON files for more queries. Some passes run twice
(`array_op` is 25 and 32). `-p NAME` takes the first run; `-p NN` picks one exactly.

## Plain compiler flags (checked against this tree)
- `--show-asr --no-color`. Without `--no-color` the output contains escape codes that break grep.
- `--show-asr --clojure`: the same tree with field names (`:intent :Local`), about half the size of JSON.
- `--show-fortran`, `--dump-all-passes-fortran`: the ASR printed back as Fortran, the easiest overview.
- `--pass=NAME` does NOT imply `--show-asr`, despite `--help`. Without `--show-asr`, it compiles with only that pass and usually crashes in codegen. Write `--show-asr --pass=NAME`; add `--cumulative` for every pass up to and including NAME.
- `--dump-all-passes [--json] [--show-asr]` writes `pass_NN_<pass>.clj`, plus `pass_json_NN_<pass>.json` with `--json`, into the current directory. Without `--show-asr` it then also compiles. Run it in a scratch directory.
- `--verify-all-passes` stops at the first pass that produces invalid ASR.
- `--with-intrinsic-mods` includes the intrinsic modules, which are hidden by default.

## Gaps in the JSON form (and so in asrq)
- `ArrayConstant` data is missing (the JSON writer prints `Unimplementedvoid`; asrq shows `data=(not in JSON)`). Use `--show-asr --no-color` or `--show-fortran` to see the values.
- Intrinsic ids are bare numbers. asrq names them (`arr_intrinsic_id=14(Sum)`) by reading the enums in the compiler's own source tree. If that tree has changed since the last build, the names can be off.
- `Var` nodes carry no type; look the symbol up (`asrq sym`).
- An absent optional field and an empty list both print as `[]`.

## One-off jq queries
For questions asrq doesn't cover, query the JSON directly. The `jq` here is the
snap package, version 1.5:
- It can't open files under `/tmp` or hidden directories, so pipe input in: `jq ... < file.json`.
- It has no `IN`, `walk` or other 1.6 functions.

```bash
lfortran --show-asr --json x.f90 > asr.json        # keep locations; jq output stays small
jq -c '.. | objects | select(.node=="Variable" and .fields.name=="r") | .fields.type' < asr.json
jq -r 'paths(objects and .node=="ArrayPhysicalCast") | map(tostring) | join(".")' < asr.json
jq -r '.. | objects | select(.loc.first_line? == 27) | .node' < asr.json | sort -u
```
In the raw JSON, a reference is the string `"name (SymbolTableN)"`, and a scope's table
is the object with `"node": "SymbolTableN"`. `asrq scopes` shows which N is which.
