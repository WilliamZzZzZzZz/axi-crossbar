---
agent: "ask"
description: "Review selected RTL, SystemVerilog class logic, UVM component logic, protocol handling, or scoreboard comparison logic."
---

Review this SystemVerilog, RTL, UVM, protocol, checker, monitor, driver, sequence, or scoreboard logic as a digital verification reviewer.

Code, intent, or file references:
${input:code_or_intent:Paste selected code, describe intended behavior, or reference files/signals/classes}

Please answer:

1. **Current Behavior**
   - Explain what the code currently does.

2. **Intended Behavior Match**
   - State whether it matches the intended behavior.
   - Identify any assumption needed to make that conclusion.

3. **Corner Cases**
   - Check reset, timing, burst/transaction boundaries, width/sign handling, empty/full conditions, ordering, backpressure, X/Z behavior, and invalid/rare protocol states.

4. **Protocol and Verification Risks**
   - Identify protocol risks, monitor sampling risks, scoreboard false positives/negatives, race conditions, and coverage/assertion gaps.

5. **Minimal Correction Strategy**
   - Only if a bug is proven, propose the smallest correction strategy.
   - Do not provide a broad rewrite unless explicitly requested.
