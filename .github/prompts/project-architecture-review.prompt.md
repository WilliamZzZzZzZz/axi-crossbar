---
agent: "ask"
description: "Review and explain the architecture of a digital verification or UVM project without rewriting it."
---

Review the current SystemVerilog/UVM digital verification project architecture as a DV architect.

Scope:
${input:scope:Describe the subsystem, UVM env, RTL block, or files to inspect}

Please:

1. Inspect relevant files first.
2. Summarize the RTL/testbench architecture component-by-component.
3. Identify signal flow, data flow, control flow, transaction flow, protocol flow, and UVM phase flow.
4. Explain why each component exists and what responsibility it owns.
5. Identify driver/monitor/scoreboard/coverage/sequence/env/interface/checker boundaries where applicable.
6. Identify coupling, unclear ownership, missing abstraction, duplicated responsibility, fragile protocol assumptions, and scoreboard/monitor blind spots.
7. Recommend next steps without rewriting the architecture unless explicitly requested.

Use file paths and symbols when mapping claims to code.
