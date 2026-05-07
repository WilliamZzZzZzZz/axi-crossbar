---
applyTo: "**/*.sv,**/*.svh,**/*.v,**/*.vh,**/*.sva,**/*.f,**/*.flist"
---

# SystemVerilog and UVM Instructions

- Follow local naming, indentation, macro, package, and filelist conventions.
- Preserve existing RTL/testbench architecture unless a redesign is explicitly requested.
- In RTL, check reset behavior, clocking, width/sign handling, combinational defaults, latch risks, blocking/nonblocking usage, FSM completeness, and CDC assumptions.
- In UVM, keep responsibilities separate: sequences generate intent, drivers drive pins, monitors observe pins, scoreboards check independently, coverage samples meaningful behavior.
- Use UVM phases correctly: construct hierarchy in build, connect TLM in connect, consume time in run, summarize in check/report.
- Check `uvm_component_utils`/`uvm_object_utils`, factory overrides, config_db set/get paths, virtual interface propagation, analysis port connections, objections, and sequence-driver item flow.
- For reset and clocks, avoid sampling unstable signals; align monitor sampling with interface clocking blocks or protocol-valid points.
- Assertions should state protocol/design intent and should not mask bugs with over-broad assumptions.
- Coverage should reflect verification goals; avoid coverpoints that only prove stimulus was generated without checking observed DUT behavior.
- Do not weaken scoreboard comparisons, monitor sampling, or constraints just to make a test pass.
- Distinguish protocol legality, DUT behavior, VIP behavior, and testbench implementation choices.
