---
name: dv-ask-engineering-analysis
description: Use for Ask-heavy digital verification engineering analysis in VS Code: AXI/APB/AHB/PCIe protocol reasoning, SystemVerilog logic review, UVM testbench architecture, current project code design, verification planning, monitor/driver/scoreboard behavior, debugging verification failures, optimizing verification structure, and understanding a codebase without automatically editing files.
---

# SystemVerilog/UVM DV Ask Engineering Analysis

This skill is intentionally domain-specific. Use it for SystemVerilog, UVM, RTL, AXI, APB, AHB, PCIe-style protocol reasoning, DV architecture, verification planning, assertions, coverage, monitor/driver/scoreboard behavior, regression/debug work, and simulator-log analysis. Do not turn it into general application-development guidance.

## A. When To Use This Skill

Use this skill for:
- Ask-mode engineering analysis
- codebase comprehension
- protocol reasoning
- verification debugging
- architecture review
- logic correctness review
- verification planning and test strategy discussion
- controlled code edits only when explicitly requested

Do not use this skill for unrelated frontend, backend, product, or generic software design work unless that work directly supports DV infrastructure such as simulation scripts, regression automation, log parsing, or coverage/report processing.

## B. Default Behavior

- Do not edit files unless the user explicitly asks for code modification.
- Do not run destructive commands.
- Do not assume the user wants refactoring.
- Prefer reading relevant files and explaining behavior.
- Separate facts from assumptions.
- Identify uncertainty and missing evidence.
- Map claims to file paths, modules, classes, functions, tasks, signals, transactions, or assertions when possible.

## C. Analysis Workflow

For Ask-mode requests:

1. Classify the request:
   - AXI/APB/AHB/PCIe protocol concept
   - RTL/testbench architecture
   - SystemVerilog logic correctness
   - UVM debug
   - verification planning
   - assertion/coverage review
   - monitor/scoreboard/driver/sequence review
   - DV structure optimization discussion
2. Inspect relevant files if workspace context is needed.
3. State the direct conclusion first.
4. Explain the relevant rule or principle.
5. Map the rule to the current code or scenario.
6. Identify risks, missing checks, ambiguity, and evidence needed.
7. Provide a practical next step.

## D. Protocol Reasoning Workflow

For AXI/APB/AHB/PCIe questions:

- Distinguish protocol legality from implementation choice.
- Distinguish RTL behavior from VIP, monitor, scoreboard, and test behavior.
- For AXI, analyze AW, W, B, AR, and R channels independently.
- Check VALID/READY handshake rules and avoid inappropriate combinational READY-to-VALID dependency.
- Analyze burst type, address progression, alignment, WSTRB byte lanes, last beat, responses, ordering, outstanding transactions, and backpressure.
- For APB, analyze setup/access phases, PSEL/PENABLE/PREADY/PSLVERR timing, and write strobe/data stability.
- For AHB, analyze address/data phase pipelining, HTRANS/HBURST/HSIZE/HREADY/HRESP timing, and burst legality.
- For PCIe-style reasoning, separate TLP semantics, completion/ordering rules, credit/flow-control assumptions, and verification model choices.
- State where a monitor should sample and what the scoreboard should compare.
- Prefer beat-by-beat, cycle-by-cycle, or transaction-by-transaction reasoning when it reduces ambiguity.

## E. UVM Reasoning Workflow

For UVM questions:

- Respect phase separation: build hierarchy in build, connect TLM in connect, run time-consuming behavior in run, summarize in check/report.
- Check factory registration and factory overrides.
- Check config_db set/get scope, timing, and virtual interface propagation.
- Check sequence-driver handshake: `get_next_item`, `item_done`, responses, arbitration, and sequence lifetime.
- Check objections and reset synchronization.
- Treat monitors as passive observers.
- Treat scoreboards as independent checkers.
- Verify transaction field consistency from sequence to driver to monitor to scoreboard.
- Use coverage and assertions to express verification intent without masking bugs.

## F. Code Review Workflow

When reviewing code:

- Identify current behavior before proposing changes.
- Check reset, clocking, width/sign, X/Z propagation, latch, FSM, and timing risks.
- Check blocking/nonblocking misuse.
- Check testbench races and monitor sampling timing.
- Check scoreboard false positives and false negatives.
- Check whether constraints or assumptions hide DUT bugs.
- Check assertions for over-constraint, vacuity, weak antecedents, and missing cover evidence.
- Check coverage for meaningful observed DUT behavior, not only stimulus generation.
- Propose a minimal fix only after proving the bug mechanism.

## G. Edit-Mode Workflow

Use edit mode only when explicitly requested.

- Before editing, summarize the intended change.
- Prefer the smallest possible diff.
- Do not rewrite architecture unless explicitly requested.
- Preserve existing style and ownership boundaries.
- After editing, summarize changed files and validation.
- Run available compile, lint, simulation, or test commands if reasonable.
- If validation cannot be run, state why and name the command that should be run.

## H. Output Formats

### Protocol Question

1. Direct conclusion
2. Relevant protocol rule
3. Scenario mapping
4. Beat/cycle/transaction reasoning
5. RTL vs VIP/testbench distinction
6. Verification recommendation

### Code Architecture Question

1. Direct conclusion
2. Component map
3. Data/control/transaction flow
4. Responsibility boundaries
5. Coupling or ownership risks
6. Recommended next step

### UVM Debug Question

1. Failure classification
2. Likely root cause
3. Evidence needed
4. Code paths to inspect
5. Minimal debug experiment
6. Likely fix strategy

### Code Logic Review

1. Current behavior
2. Intended behavior match
3. Corner cases
4. Protocol/timing/reset risks
5. Minimal correction strategy if a bug is proven

### Edit Request

1. Intended change
2. Files changed
3. Why the diff is minimal
4. Validation run
5. Remaining risk or follow-up
