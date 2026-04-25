# CLAUDE.md — Python data / ML addendum

<!--
  Merged into CLAUDE.md when STACK=python-data.
  Assumed stack: Python 3.11+ + numpy / pandas 2.x / polars / pyarrow / scikit-learn / jupyter + uv + dvc / mlflow + ruff + mypy + hypothesis
-->

Supplements core CLAUDE.md with data/ML/scripting best practices.

## Commands

```bash
# Environment (pin Python explicitly)
uv venv --python 3.11 && source .venv/bin/activate
uv pip install -e ".[dev]"
uv lock                                  # commit uv.lock

# Notebooks
jupyter lab
jupytext --sync notebooks/*.ipynb        # pair .ipynb with .py for diffable review

# Tests / lint / types / format
pytest -x
pytest --hypothesis-show-statistics
ruff check . && ruff format .
mypy src

# Data + experiments
dvc repro
mlflow ui --port 5000
```

## Idiomatic patterns (DO)

- **Vectorize with numpy / pandas / polars — never loop over rows** — `df["x"] * 2 + df["y"]` beats `for` by 100–1000x. For complex logic use `np.where` / `pl.when().then()` or `apply` as last resort.
- **Prefer `polars` or `pyarrow` for >1GB data** — pandas pulls everything into RAM with object overhead. Polars is lazy, multi-threaded, Arrow-native.
- **Explicit `dtype` on read and after transforms** — `pd.read_csv(..., dtype={...})` catches schema drift. Assert dtypes in tests.
- **Notebooks as prototype only — promote to modules** — once a cell is reused, move it to `src/<package>/`. Notebooks call functions; functions are tested.
- **Pair notebooks with `.py` via jupytext** — diffable in PRs, no JSON noise, no embedded outputs in git.
- **Track experiments with MLflow / W&B / DVC** — params, metrics, artifacts, seed. Git holds code; tracker holds runs.
- **Set and log every random seed** — `numpy.random.default_rng(seed)`, `torch.manual_seed`, `random.seed`, sklearn `random_state=`. Log alongside metrics.
- **Property-based tests on numerical contracts** — `hypothesis` for invariants like sum/shape preserved, monotonic. Catches edge cases unit tests miss.

## Anti-patterns (AVOID — call out and fix when seen)

- **`for idx, row in df.iterrows()`** — slowest possible API, O(n) Python overhead per row. Vectorize, or `df.itertuples()` if you must iterate.
- **Chained pandas operations triggering `SettingWithCopyWarning`** — `df[df.x > 0]["y"] = 1` silently fails. Use `.loc[df.x > 0, "y"] = 1` or `df.assign(...)`.
- **Training in notebooks then losing seed / params / data version** — irreproducible. Wrap training in a script, log via MLflow.
- **Committing CSV / parquet / model weights to git** — bloats the repo. Use DVC, S3, or HF Hub; commit the pointer.
- **`df.apply(lambda row: ..., axis=1)` for arithmetic** — nearly as slow as iterrows. Vectorize with column operations.
- **Ignoring `dtype` mismatches between train and inference** — `int64` vs `int32`, `category` vs `object` silently break models. Assert schema both sides.
- **`pd.merge` without specifying `how=` and `validate=`** — silent many-to-many joins explode row counts. Always pass `validate="one_to_many"` etc.
- **Mutating shared DataFrames across cells** — out-of-order execution corrupts state. Treat DataFrames as immutable; reassign or `.copy()`.
- **Bare `np.float32` / `float` in financial code** — precision loss compounds. Use `Decimal` or fixed-point integer cents.
- **`pickle` for model artifacts shipped to prod** — version-fragile, security risk. Use `joblib` for sklearn, ONNX / safetensors for portable.

## Test layer hierarchy

Pick the **lightest layer** where the rule reads naturally:

1. **Pure unit tests on transformations** — small DataFrame in, DataFrame out. Fast, deterministic, the bulk of tests.
2. **Property-based tests via `hypothesis`** — for numerical invariants (sum preserved, idempotent, commutative).
3. **Schema / contract tests via `pandera` or `pydantic`** — column types, ranges, nullability on pipeline boundaries.
4. **Integration tests on the full pipeline with fixture data** — end-to-end on a 100-row sample. Catches wiring bugs.
5. **Regression tests on golden outputs** — **LAST RESORT.** Snapshot a metric (R², AUC) within tolerance; flaky if seed leaks.

## Tactical testing rules

- Tests use tiny in-memory DataFrames (literal dicts), not fixtures from disk — fast and self-documenting.
- Compare DataFrames with `pd.testing.assert_frame_equal(..., check_dtype=True)` — not `==`.
- Floating-point comparisons via `np.isclose` / `pytest.approx`; never `==` on floats.
- Inject the random seed and the clock — never call `np.random.rand()` or `datetime.now()` in domain code.
- Schema check at every pipeline boundary; treat schema drift as a test failure, not a warning.

## Stack-specific gotchas

- **`pd.read_csv` infers dtypes per chunk** — chunked reads can produce different dtypes than full reads. Always pass `dtype=`.
- **`category` dtype with unseen values raises silently in some ops** — pin via `pd.CategoricalDtype(categories=..., ordered=...)`.
- **`groupby(...).apply` returns inconsistent shapes across pandas 1.x and 2.x** — prefer `agg` / `transform` with explicit functions.
- **Polars `LazyFrame` is not eager — `.collect()` to materialize** — easy to think a query ran when it didn't.
- **Numpy `float32` + pandas `float64` mix triggers upcasts on join** — pin dtypes early or pay memory later.
- **Jupyter cell out-of-order execution** — restart-and-run-all in CI before promoting any notebook result.
- **`scikit-learn` `Pipeline` with `ColumnTransformer` reorders columns** — use `set_output(transform="pandas")` (sklearn 1.2+) to keep names.
- **`mlflow.log_artifact` on a 5GB model file blocks for minutes** — log the path, store in object storage.
- **GPU non-determinism** — `torch.use_deterministic_algorithms(True)` + `CUBLAS_WORKSPACE_CONFIG=:4096:8` for reproducible CUDA.
