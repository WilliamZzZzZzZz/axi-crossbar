# UVM Simulation Workflow

This directory uses a self-documenting `Makefile`. Run `make help` for the authoritative target list and the latest short descriptions.

## Quick Start

From the repository root:

```bash
cd uvm/sim
./with_vcs_env.sh make help
./with_vcs_env.sh make smoke
./with_vcs_env.sh make run T=decerr GUI=1
```

If your shell already has the Synopsys/VCS environment configured, `make ...` also works directly.

## Recommended Daily Flow

1. Check the available commands.

```bash
make help
```

2. Run a single directed test.

```bash
make smoke
make decerr
make run T=smoke SEED=7 VERB=UVM_MEDIUM
```

3. Enable GUI or skip the default Tcl batch file when needed.

```bash
make smoke GUI=1
make run T=decerr DOTCL=0
```

4. Run a small regression.

```bash
make regress
make regress TESTS="smoke decerr"
make regress_cov TESTS="smoke decerr"
```

5. Inspect logs or coverage results.

```bash
make check error
make checkinfo axicb_smoke_virtual_sequence
make mergecov
make dvecov
make verdicov
make htmlcov
```

## Common Variables

Use `VAR=value` on the `make` command line to override behavior:

- `T=<name>` expands `TESTNAME` to `axicb_<name>_test` for `make run`.
- `TESTNAME=<id>` selects the exact UVM test class.
- `SEED=<n>` overrides `+ntb_random_seed`.
- `GUI=1` launches the simulation in DVE GUI mode.
- `COV=1` enables coverage during elaboration and run.
- `DOTCL=0` skips `-ucli -do axicb_sim_run.do`.
- `VERB=<level>` overrides `+UVM_VERBOSITY`.
- `OUT=<dir>` redirects generated logs, work, sim, and obj outputs.
- `RUN_LOG=<path>` points `check` or `checkinfo` at a different run log.
- `TESTS="..."` controls which shortcut targets the regression loops execute.
- `CM_DIR=<dir>` and `CM_NAME=<name>` override the coverage database location and label.

## Command Groups

The `Makefile` is organized into the following public groups:

- `Setup`: directory preparation.
- `Simulation`: compile, elaborate, and run.
- `Tests`: named shortcuts such as `smoke` and `decerr`.
- `Regression`: loop over `TESTS`, optionally with coverage.
- `Coverage`: merge and view coverage databases.
- `Utility`: grep logs, kill GUI sessions, and clean generated outputs.

## Notes

- Generated artifacts default to `uvm/sim/out/`.
- `clean` keeps the `Makefile`, `.do` files, and `with_vcs_env.sh`, then removes the rest of the generated content in this directory.
- `htmlcov` currently uses `open urgReport/dashboard.html`, so it expects a desktop opener to be available in the current environment.
- Keep target descriptions next to the targets in `Makefile`; update `README.md` only for workflow changes or richer examples.
