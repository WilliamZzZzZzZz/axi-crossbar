---
agent: "ask"
description: "Analyze an AXI protocol, RTL, VIP, monitor, or scoreboard question with beat/cycle reasoning."
---

Analyze this AXI question as a digital verification reviewer.

Scenario or code:
${input:scenario:Describe the AXI scenario, paste code, or reference files/signals}

Please answer using this format:

1. **Relevant AXI Rule**
   - State the exact rule or principle involved.
   - Distinguish AXI requirement from implementation choice.

2. **Scenario Analysis**
   - Analyze AW, W, B, AR, and R channels separately when relevant.
   - Cover VALID/READY timing, backpressure, outstanding transactions, and response ordering.

3. **Beat/Cycle Reasoning**
   - Provide beat-by-beat or cycle-by-cycle reasoning when applicable.
   - Include burst type, address progression, alignment, WSTRB byte lanes, and last-beat behavior when relevant.

4. **RTL vs VIP/Testbench**
   - Distinguish DUT behavior, master/slave VIP behavior, monitor observation, and scoreboard checking.

5. **Verification Recommendation**
   - State what to check in assertions, monitor, scoreboard, coverage, or debug logs.
   - Suggest the minimal next experiment or review target.
