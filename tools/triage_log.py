#!/usr/bin/env python3
"""Triage a single UVM run log."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional


UVM_MSG_RE = {
    "UVM_ERROR": re.compile(r"^\s*UVM_ERROR\s+[^:]"),
    "UVM_FATAL": re.compile(r"^\s*UVM_FATAL\s+[^:]"),
    "UVM_WARNING": re.compile(r"^\s*UVM_WARNING\s+[^:]"),
}
UVM_SUMMARY_RE = re.compile(r"^\s*(UVM_ERROR|UVM_FATAL|UVM_WARNING)\s*:\s*(\d+)\b")


@dataclass
class LogTriage:
    result: str
    log_path: str
    log_exists: bool
    return_code: Optional[int]
    timed_out: bool
    uvm_error_count: int = 0
    uvm_fatal_count: int = 0
    uvm_warning_count: int = 0
    pass_marker_found: bool = False
    fail_marker_found: bool = False
    first_error_line: str = ""
    first_fatal_line: str = ""
    reason: str = ""

    def to_dict(self) -> dict:
        return asdict(self)


def _format_line(line_no: int, line: str) -> str:
    return f"{line_no}: {line.rstrip()}"


def triage_log(log_path: str | Path, return_code: Optional[int] = None, timed_out: bool = False) -> LogTriage:
    """Return PASS/FAIL/TIMEOUT/UNKNOWN/NO_LOG classification for a UVM run log."""

    path = Path(log_path)
    triage = LogTriage(
        result="UNKNOWN",
        log_path=str(path),
        log_exists=path.is_file(),
        return_code=return_code,
        timed_out=timed_out,
    )

    summary_counts = {
        "UVM_ERROR": 0,
        "UVM_FATAL": 0,
        "UVM_WARNING": 0,
    }
    first_summary_error = ""
    first_summary_fatal = ""

    if triage.log_exists:
        with path.open("r", encoding="utf-8", errors="replace") as log_file:
            for line_no, line in enumerate(log_file, start=1):
                stripped = line.rstrip("\n")

                if "TEST PASSED" in stripped:
                    triage.pass_marker_found = True
                if "TEST FAILED" in stripped:
                    triage.fail_marker_found = True

                summary_match = UVM_SUMMARY_RE.match(stripped)
                if summary_match:
                    severity = summary_match.group(1)
                    count = int(summary_match.group(2))
                    summary_counts[severity] = max(summary_counts[severity], count)
                    if severity == "UVM_ERROR" and count > 0 and not first_summary_error:
                        first_summary_error = _format_line(line_no, stripped)
                    if severity == "UVM_FATAL" and count > 0 and not first_summary_fatal:
                        first_summary_fatal = _format_line(line_no, stripped)
                    continue

                if UVM_MSG_RE["UVM_ERROR"].match(stripped):
                    triage.uvm_error_count += 1
                    if not triage.first_error_line:
                        triage.first_error_line = _format_line(line_no, stripped)
                if UVM_MSG_RE["UVM_FATAL"].match(stripped):
                    triage.uvm_fatal_count += 1
                    if not triage.first_fatal_line:
                        triage.first_fatal_line = _format_line(line_no, stripped)
                if UVM_MSG_RE["UVM_WARNING"].match(stripped):
                    triage.uvm_warning_count += 1

    triage.uvm_error_count = max(triage.uvm_error_count, summary_counts["UVM_ERROR"])
    triage.uvm_fatal_count = max(triage.uvm_fatal_count, summary_counts["UVM_FATAL"])
    triage.uvm_warning_count = max(triage.uvm_warning_count, summary_counts["UVM_WARNING"])
    if not triage.first_error_line:
        triage.first_error_line = first_summary_error
    if not triage.first_fatal_line:
        triage.first_fatal_line = first_summary_fatal

    if timed_out:
        triage.result = "TIMEOUT"
        triage.reason = "run exceeded timeout"
    elif return_code is not None and return_code != 0:
        triage.result = "FAIL"
        triage.reason = f"make returned non-zero status {return_code}"
    elif triage.uvm_fatal_count > 0:
        triage.result = "FAIL"
        triage.reason = "UVM_FATAL found in run log"
    elif triage.uvm_error_count > 0:
        triage.result = "FAIL"
        triage.reason = "UVM_ERROR found in run log"
    elif triage.fail_marker_found:
        triage.result = "FAIL"
        triage.reason = "TEST FAILED marker found"
    elif not triage.log_exists:
        triage.result = "NO_LOG"
        triage.reason = "run.log was not found"
    elif triage.pass_marker_found:
        triage.result = "PASS"
        triage.reason = "TEST PASSED marker found"
    else:
        triage.result = "UNKNOWN"
        triage.reason = "make returned zero but no pass/fail marker was found"

    return triage


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Triage a UVM run.log file.")
    parser.add_argument("log_path", help="Path to run.log")
    parser.add_argument("--return-code", type=int, default=None, help="make return code for the run")
    parser.add_argument("--timeout", action="store_true", help="classify the run as TIMEOUT")
    parser.add_argument("--json", action="store_true", help="print machine-readable JSON")
    return parser


def main(argv: Optional[list[str]] = None) -> int:
    args = _build_parser().parse_args(argv)
    triage = triage_log(args.log_path, return_code=args.return_code, timed_out=args.timeout)

    if args.json:
        print(json.dumps(triage.to_dict(), indent=2, sort_keys=True))
    else:
        print(f"result: {triage.result}")
        print(f"reason: {triage.reason}")
        print(f"log_path: {triage.log_path}")
        print(f"return_code: {triage.return_code}")
        print(f"uvm_error_count: {triage.uvm_error_count}")
        print(f"uvm_fatal_count: {triage.uvm_fatal_count}")
        print(f"uvm_warning_count: {triage.uvm_warning_count}")
        print(f"pass_marker_found: {triage.pass_marker_found}")
        print(f"fail_marker_found: {triage.fail_marker_found}")
        if triage.first_error_line:
            print(f"first_error_line: {triage.first_error_line}")
        if triage.first_fatal_line:
            print(f"first_fatal_line: {triage.first_fatal_line}")

    return 0 if triage.result == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
