**English** | [简体中文](README.zh-CN.md)

# AXI Crossbar RTL and UVM Verification

This repository is a module-level RTL and UVM verification project for an AXI4 crossbar. The current verification target is a **2-upstream-master × 2-downstream-slave** instance, with emphasis on address decoding, five-channel routing, ID expansion and return routing, bursts, DECERR handling, outstanding transactions, ordering, and Round-Robin arbitration.

The project includes a parameterized crossbar RTL, a custom AXI UVM VIP, a channel-level predictor, reference memory, scoreboard, functional coverage, directed testcases, and Makefile/Python regression infrastructure.

> **Project status: active development.** The predictor is integrated into the source and compile boundary, but generated VCS logs, waveforms, and coverage databases are not committed. Run the compile and regression flow in a configured EDA environment before treating the project as passing.

## Current DUT Configuration

| Item | Current 2×2 testbench configuration |
| --- | --- |
| AXI data width | 32 bits |
| AXI address width | 32 bits |
| Upstream ID width | 8 bits |
| Downstream ID width | 9 bits, `{source_master, original_id}` |
| Upstream interfaces | `s00_axi`, `s01_axi` |
| Downstream interfaces | `m00_axi`, `m01_axi` |
| Slave 0 address space | `0x0000_0000`–`0x0000_FFFF` |
| Slave 1 address space | `0x0001_0000`–`0x0001_FFFF` |
| Unmapped address | Crossbar-generated `DECERR` |
| Bursts | FIXED, INCR, WRAP; 8-bit AxLEN |
| Unique ID threads per upstream port | 2 |
| Accepted transactions per upstream port | 16 |
| Issue depth per downstream port | 4 |
| Arbitration | Blocking Round-Robin |
| QoS | `AWQOS/ARQOS` are propagated but do not affect arbitration priority |
| USER signals | Disabled in the current testbench |

The generic `axi_crossbar` RTL supports parameterized port counts and address regions. The current UVM environment and predictor target the 2×2 configuration above.

## RTL Architecture

```text
Upstream AXI Masters                     Downstream AXI Slaves

  s00_axi ──┐                         ┌── m00_axi  [0x0000_0000 / 64 KiB]
            ├── decode + arbitration ─┤
  s01_axi ──┘                         └── m01_axi  [0x0001_0000 / 64 KiB]

             AW/W/B and AR/R are implemented as independent paths
```

Main RTL files:

- `dut/axi_crossbar_wrap_2x2.v`: scalar-port wrapper for the 2×2 instance.
- `dut/axi_crossbar.v`: parameterized crossbar top with separate read and write paths.
- `dut/axi_crossbar_addr.v`: address decode, connect/secure filtering, thread tracking, and acceptance control.
- `dut/axi_crossbar_wr.v`: AW/W/B routing, write-request arbitration, B-response arbitration, and write DECERR handling.
- `dut/axi_crossbar_rd.v`: AR/R routing, read-request arbitration, R-response arbitration, and read DECERR handling.
- `dut/axi_register_wr.v`, `dut/axi_register_rd.v`: bypass, simple, and skid channel registers.
- `dut/arbiter.v`, `dut/priority_encoder.v`: Round-Robin/fixed-priority building blocks; the current crossbar instances select Round-Robin.

The AXI4 W channel has no transaction ID. After an AW request wins arbitration, the crossbar locks the corresponding W source until that burst completes with `WLAST`. R-response arbitration is similarly held until `RLAST`.

## UVM Verification Architecture

```text
                         ┌──────────────────────────┐
 virtual sequence ──────▶│ master sequencer/driver  │
                         └────────────┬─────────────┘
                                      │ upstream AW/W/AR
                                      ▼
                                ┌──────────┐
                                │   DUT    │
                                └────┬─────┘
                                     │ downstream AW/W/AR
                                     ▼
                         ┌──────────────────────────┐
                         │ slave responder + memory │
                         └──────────────────────────┘

upstream complete-transaction monitors ────────────────▶ functional coverage

upstream/downstream channel handshake events ──▶ predictor ──▶ expected
                    │                                      │
                    └──────────── actual ──────────────────┴──▶ scoreboard
```

The environment contains:

- Two active AXI master agents.
- Two AXI slave responders backed by sparse memories.
- One virtual sequencer.
- One channel-event predictor.
- One expected/actual scoreboard.
- One upstream functional coverage collector.

### Predictor

`uvm/env/axicb_predictor.sv` builds expected results from AXI handshakes observed by the monitors:

- Decodes the target slave from the request address.
- Expands upstream IDs for the downstream interfaces and restores them on B/R return paths.
- Predicts transparent propagation of AW, W, and AR payloads.
- Predicts transparent routing of downstream B/R responses to the correct upstream port.
- Suppresses downstream AW/W expectations for illegal writes and predicts an upstream B/DECERR after WLAST.
- Suppresses downstream AR expectations for illegal reads and predicts `ARLEN+1` zero-data R/DECERR beats.
- Uses transaction keys, per-ID FIFO ordering, and a reset epoch to track outstanding traffic.
- Maintains a reference memory using burst address progression and WSTRB byte updates.

The predictor deliberately **does not copy** DUT READY timing, pipeline registers, or the Round-Robin state machine. Exact contention, fairness, and arbitration behavior remain the responsibility of dedicated checkers and testcases.

### Scoreboard

`uvm/env/axicb_scoreboard.sv` compares predictor-generated expected events against actual DUT-output events observed by the monitors:

- Checks downstream AW/AR destination ports, expanded IDs, and attributes.
- Uses the transaction key of a matched AW to check WDATA, WSTRB, WLAST, and burst ownership.
- Checks upstream BID/RID, BRESP/RRESP, RDATA, and RLAST.
- Detects leakage of illegal requests to downstream interfaces.
- Verifies in report phase that expected events and outstanding write ownership are fully drained.

## Repository Layout

```text
.
├── dut/                    # AXI crossbar RTL
├── uvm/
│   ├── vip/                # AXI transactions, interface, agents, drivers, monitors, responders
│   ├── env/                # predictor, scoreboard, coverage, virtual sequencer, environment
│   ├── seq_lib/            # active virtual and element sequences
│   ├── test/               # active UVM tests
│   ├── testbench/          # 2×2 DUT top, clock/reset, config_db VIF bindings
│   └── sim/                # Makefile, VCS environment wrapper, DVE scripts
├── regress/                # smoke and daily regression JSON configurations
├── tools/                  # Python regression runner and log triage
└── reports/                # generated Markdown/CSV regression reports
```

`uvm/seq_lib/ram_virt_seq/` and `uvm/test/ram_test/` are not included by the active package chain and are not part of the active testcase set.

## Testcases

| Make target | UVM test | Main verification intent |
| --- | --- | --- |
| `smoke` | `axicb_smoke_test` | All four master-to-slave routes, address boundaries, single-beat write/readback |
| `decode_full_range` | `axicb_decode_full_range_test` | Base/mid/end addresses, adjacent boundaries, routing, ID expansion |
| `decerr_single` | `axicb_decerr_single_test` | Single-beat illegal reads/writes and downstream isolation |
| `decerr_burst` | `axicb_decerr_burst_test` | Multi-beat DECERR, WLAST/RLAST, post-error recovery |
| `decerr_id` | `axicb_decerr_id_test` | DECERR ID preservation across burst lengths |
| `decerr_dual_mst` | `axicb_decerr_dual_mst_test` | Concurrent legal/illegal traffic from two masters and mixed read/write traffic |
| `burst_type` | `axicb_burst_type_test` | 1/2/4-byte transfers; FIXED/INCR 1–16 beats, WRAP 2/4/8/16 beats, long INCR bursts 32–256 beats |
| `conc_arb` | `axicb_conc_arb_test` | Same-target contention, burst integrity, Round-Robin fairness |
| `order_resp` | `axicb_order_resp_test` | Thread/issue depth, same-ID ordering, B/R response contention |

List the tests and virtual sequences currently registered by the Makefile:

```bash
make -C uvm/sim show test
make -C uvm/sim show vseq
```

## Requirements

- Linux x86-64 EDA environment.
- Synopsys VCS with UVM 1.2 support.
- Valid Synopsys license configuration.
- GNU Make and Bash.
- Python 3.10 or later for the regression runner.
- DVE, Verdi, and URG are optional tools for GUI, waveform, and coverage inspection.

`uvm/sim/with_vcs_env.sh` provides the default VCS/Verdi environment variables used by this project. Installation paths and license variables can be overridden by the caller's environment.

## Quick Start

Run these commands from the repository root:

```bash
# Show all supported commands
uvm/sim/with_vcs_env.sh make -C uvm/sim help

# Basic datapath and predictor flow
uvm/sim/with_vcs_env.sh make -C uvm/sim smoke SEED=1

# DECERR bursts and downstream isolation
uvm/sim/with_vcs_env.sh make -C uvm/sim decerr_burst SEED=1

# Outstanding transactions, ordering, and response arbitration
uvm/sim/with_vcs_env.sh make -C uvm/sim order_resp SEED=1
```

An exact UVM test class can also be selected:

```bash
uvm/sim/with_vcs_env.sh make -C uvm/sim run \
  TESTNAME=axicb_conc_arb_test SEED=7 VERB=UVM_MEDIUM
```

Generated files are written to `uvm/sim/out/` by default. Use a dedicated OUT directory to isolate one run:

```bash
uvm/sim/with_vcs_env.sh make -C uvm/sim smoke \
  SEED=1 OUT=out/predictor_smoke
```

## Regression

The regression runner still uses `uvm/sim/Makefile` and assigns a separate output directory to each test×seed case.

```bash
# Expand commands without running simulation
python3 tools/regress.py --config regress/smoke.json --dry-run

# 3 tests × 3 seeds
uvm/sim/with_vcs_env.sh python3 tools/regress.py \
  --config regress/smoke.json

# 9 tests × 5 seeds
uvm/sim/with_vcs_env.sh python3 tools/regress.py \
  --config regress/daily.json
```

Generated reports:

- `reports/regress_summary_<timestamp>.md`
- `reports/regress_results_<timestamp>.csv`

PASS classification considers the make return code, timeout status, `UVM_ERROR`, `UVM_FATAL`, and testcase PASS/FAIL markers.

Each case has an isolated `OUT` directory, but the current VCS analysis database is still shared through the `uvm/sim` working directory. Use `--jobs 1` if the EDA environment does not support concurrent compilation.

## Logs, Waveforms, and Coverage

```bash
cd uvm/sim

# Inspect errors or messages from a specific component
make check error
make check fatal
make checkinfo axicb_scoreboard

# GUI
make smoke GUI=1

# Run all Makefile-registered tests and merge coverage
make all_cov
make dvecov
make verdicov
```

Start by checking `out/log/run.log` for:

```text
UVM_ERROR : 0
UVM_FATAL : 0
Scoreboard PASS: channel_checks=... decerr_transactions=...
```

The following messages should not be present:

```text
reference memory mismatch
no predicted DUT output
downstream W has no matched AW
undrained predictor state
unmatched expected output
```

## Current Boundaries

- QoS is propagated as a sideband but does not provide QoS-aware priority arbitration.
- USER signals are disabled in the current 2×2 testbench.
- Legal slave responses are currently fixed to OKAY; SLVERR/EXOKAY response injection is not implemented.
- The predictor targets the current two 64 KiB address regions and current ID-expansion rule.
- Predictor reset flushing is implemented, but the active nine-test set does not contain a dedicated mid-transaction reset test.
- Exact READY latency, pipeline timing, and Round-Robin grant order are not modeled by the predictor.
- Simulator artifacts, waveforms, coverage databases, and regression reports are ignored by Git by default.
- The repository does not currently include logs proving that the latest source has passed a VCS regression; use local EDA results as the source of truth.

Use `make -C uvm/sim help` as the authoritative list of simulation commands.
