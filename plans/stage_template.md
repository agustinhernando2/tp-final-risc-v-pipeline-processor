# Stage N — `<Title>`

**Status:** DONE | IN PROGRESS | PENDING

---

## Files created / modified

| File | Action |
|------|--------|
| `src/...` | Created / Updated / Rewritten |

---

## Design notes

<Key decisions, encoding tables, port lists, or truth tables relevant to this stage.>

---

## Test results

<Simulation output pasted verbatim.>

---

## Running the tests

```bash
mkdir -p sim_out && cd sim_out

# 1. Compile
xvlog --sv <source files> <testbench>

# 2. Elaborate
xelab -debug typical <top_module> -s <snapshot_name>

# 3. Simulate
xsim <snapshot_name> --runall
```

Expected output ends with `ALL TESTS PASSED`.

---

## Next: Stage N+1 — `<Title>`

<One-paragraph handoff describing what the next stage needs from this one.>
