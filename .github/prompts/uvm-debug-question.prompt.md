---
agent: "ask"
description: "Debug a UVM compile, build/connect/run phase, sequence-driver, monitor, scoreboard, or config_db issue."
---

Analyze this UVM/debug issue as a verification debug reviewer.

Issue, log, code, or file references:
${input:issue:Paste the error/log, describe the symptom, or reference relevant files/classes}

Please answer using this format:

1. **Failure Classification**
   - Classify as compile/elaboration, factory, config_db, build/connect, run phase, sequence-driver handshake, objection, TLM connection, monitor sampling, scoreboard mismatch, reset/clock sync, or transaction consistency.

2. **Likely Root Cause**
   - Explain the most likely mechanism.
   - Separate evidence from assumptions.

3. **Evidence Needed**
   - List the specific file paths, classes, methods, signals, log lines, or transaction fields to inspect.

4. **Code Paths to Inspect**
   - Identify likely components such as env, agent, sequencer, driver, monitor, scoreboard, sequence, interface, config object, or test.

5. **Minimal Debug Experiment**
   - Propose the smallest print, assertion, waveform check, phase check, or focused simulation to confirm the hypothesis.

6. **Likely Fix Strategy**
   - Describe the smallest likely correction.
   - Do not rewrite architecture unless the evidence proves an ownership problem.
