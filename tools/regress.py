#!/usr/bin/env python3
"""Python regression runner for the AXI crossbar UVM Makefile flow."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Optional

from triage_log import LogTriage, triage_log


DEFAULT_OUT_ROOT = "uvm/sim/out/regress"
DEFAULT_REPORT_DIR = "reports"
DEFAULT_TIMEOUT_SECONDS = 600


@dataclass(frozen=True)
class RunSpec:
    index: int
    test: str
    seed: int
    cov: bool
    out_dir_abs: Path
    out_dir_report: str
    out_arg: str
    log_path_abs: Path
    log_path_report: str
    make_log_abs: Path
    make_log_report: str
    command: list[str]
    reproduce_command: str


@dataclass
class RunResult:
    index: int
    test: str
    seed: int
    result: str
    return_code: Optional[int]
    runtime_seconds: float
    out_dir: str
    log_path: str
    make_log_path: str
    reproduce_command: str
    uvm_error_count: int
    uvm_fatal_count: int
    uvm_warning_count: int
    pass_marker_found: bool
    fail_marker_found: bool
    first_error_line: str
    first_fatal_line: str
    reason: str


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _resolve_repo_output_path(path_text: str, repo_root: Path) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        return path.resolve()
    return (repo_root / path).resolve()


def _resolve_existing_input_path(path_text: str, repo_root: Path) -> Path:
    path = Path(path_text)
    if path.is_absolute():
        return path
    cwd_candidate = (Path.cwd() / path).resolve()
    if cwd_candidate.exists():
        return cwd_candidate
    return (repo_root / path).resolve()


def _report_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root).as_posix()
    except ValueError:
        return str(path)


def _case_dir_name(test: str, seed: int) -> str:
    safe_test = re.sub(r"[^A-Za-z0-9_.-]+", "_", test).strip("_")
    return f"{safe_test}_seed_{seed}"


def _load_config(config_path: Optional[str], repo_root: Path) -> dict:
    if not config_path:
        return {}
    path = _resolve_existing_input_path(config_path, repo_root)
    with path.open("r", encoding="utf-8") as config_file:
        config = json.load(config_file)
    if not isinstance(config, dict):
        raise ValueError(f"Config must be a JSON object: {path}")
    config["_path"] = str(path)
    return config


def _as_str_list(value: object, name: str) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{name} must be a list of strings")
    return value


def _as_int_list(value: object, name: str) -> list[int]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError(f"{name} must be a list of integers")
    try:
        return [int(item) for item in value]
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} must be a list of integers") from exc


def _positive_int(value: object, name: str) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} must be an integer") from exc
    if parsed <= 0:
        raise ValueError(f"{name} must be > 0")
    return parsed


def _build_specs(
    tests: list[str],
    seeds: list[int],
    cov: bool,
    out_root_abs: Path,
    repo_root: Path,
    sim_dir: Path,
) -> list[RunSpec]:
    specs: list[RunSpec] = []
    for test in tests:
        for seed in seeds:
            out_dir_abs = out_root_abs / _case_dir_name(test, seed)
            out_arg = os.path.relpath(out_dir_abs, sim_dir)
            log_path_abs = out_dir_abs / "log" / "run.log"
            make_log_abs = out_dir_abs / "log" / "make.log"
            command = [
                "make",
                "-C",
                "uvm/sim",
                test,
                f"SEED={seed}",
                f"COV={1 if cov else 0}",
                f"OUT={out_arg}",
            ]
            specs.append(
                RunSpec(
                    index=len(specs),
                    test=test,
                    seed=seed,
                    cov=cov,
                    out_dir_abs=out_dir_abs,
                    out_dir_report=_report_path(out_dir_abs, repo_root),
                    out_arg=out_arg,
                    log_path_abs=log_path_abs,
                    log_path_report=_report_path(log_path_abs, repo_root),
                    make_log_abs=make_log_abs,
                    make_log_report=_report_path(make_log_abs, repo_root),
                    command=command,
                    reproduce_command=shlex.join(command),
                )
            )
    return specs


def _terminate_process_group(proc: subprocess.Popen) -> None:
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    except OSError:
        proc.terminate()

    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            return
        except OSError:
            proc.kill()
        proc.wait()


def _run_one(spec: RunSpec, repo_root: Path, timeout: int) -> RunResult:
    spec.make_log_abs.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    return_code: Optional[int] = None
    timed_out = False

    with spec.make_log_abs.open("w", encoding="utf-8", errors="replace") as make_log:
        make_log.write(f"$ {spec.reproduce_command}\n")
        make_log.flush()
        proc = subprocess.Popen(
            spec.command,
            cwd=repo_root,
            stdout=make_log,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True,
        )
        try:
            return_code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            _terminate_process_group(proc)
            return_code = proc.returncode

    runtime = time.monotonic() - start
    triage = triage_log(spec.log_path_abs, return_code=return_code, timed_out=timed_out)
    return _result_from_triage(spec, triage, runtime)


def _result_from_triage(spec: RunSpec, triage: LogTriage, runtime_seconds: float) -> RunResult:
    return RunResult(
        index=spec.index,
        test=spec.test,
        seed=spec.seed,
        result=triage.result,
        return_code=triage.return_code,
        runtime_seconds=runtime_seconds,
        out_dir=spec.out_dir_report,
        log_path=spec.log_path_report,
        make_log_path=spec.make_log_report,
        reproduce_command=spec.reproduce_command,
        uvm_error_count=triage.uvm_error_count,
        uvm_fatal_count=triage.uvm_fatal_count,
        uvm_warning_count=triage.uvm_warning_count,
        pass_marker_found=triage.pass_marker_found,
        fail_marker_found=triage.fail_marker_found,
        first_error_line=triage.first_error_line,
        first_fatal_line=triage.first_fatal_line,
        reason=triage.reason,
    )


def _csv_row(result: RunResult) -> dict:
    return {
        "test": result.test,
        "seed": result.seed,
        "result": result.result,
        "return_code": "" if result.return_code is None else result.return_code,
        "runtime_seconds": f"{result.runtime_seconds:.2f}",
        "out_dir": result.out_dir,
        "log_path": result.log_path,
        "make_log_path": result.make_log_path,
        "reproduce_command": result.reproduce_command,
        "uvm_error_count": result.uvm_error_count,
        "uvm_fatal_count": result.uvm_fatal_count,
        "uvm_warning_count": result.uvm_warning_count,
        "pass_marker_found": result.pass_marker_found,
        "fail_marker_found": result.fail_marker_found,
        "first_error_line": result.first_error_line,
        "first_fatal_line": result.first_fatal_line,
        "reason": result.reason,
    }


def _md_cell(value: object) -> str:
    text = str(value)
    return text.replace("|", "\\|").replace("\n", " ")


def _count_results(results: list[RunResult]) -> dict[str, int]:
    return {
        "PASS": sum(1 for result in results if result.result == "PASS"),
        "FAIL": sum(1 for result in results if result.result == "FAIL"),
        "TIMEOUT": sum(1 for result in results if result.result == "TIMEOUT"),
        "UNKNOWN": sum(1 for result in results if result.result in {"UNKNOWN", "NO_LOG"}),
    }


def _write_reports(
    results: list[RunResult],
    report_dir: Path,
    timestamp: str,
    config_name: str,
    cov: bool,
    jobs: int,
    timeout: int,
) -> tuple[Path, Path]:
    report_dir.mkdir(parents=True, exist_ok=True)
    counts = _count_results(results)
    summary_path = report_dir / f"regress_summary_{timestamp}.md"
    csv_path = report_dir / f"regress_results_{timestamp}.csv"

    fieldnames = list(_csv_row(results[0]).keys()) if results else [
        "test",
        "seed",
        "result",
        "return_code",
        "runtime_seconds",
        "out_dir",
        "log_path",
        "make_log_path",
        "reproduce_command",
        "uvm_error_count",
        "uvm_fatal_count",
        "uvm_warning_count",
        "pass_marker_found",
        "fail_marker_found",
        "first_error_line",
        "first_fatal_line",
        "reason",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for result in results:
            writer.writerow(_csv_row(result))

    with summary_path.open("w", encoding="utf-8") as md_file:
        md_file.write(f"# Regression Summary {timestamp}\n\n")
        md_file.write(f"- Name: {config_name or 'ad_hoc'}\n")
        md_file.write(f"- Total cases: {len(results)}\n")
        md_file.write(f"- PASS: {counts['PASS']}\n")
        md_file.write(f"- FAIL: {counts['FAIL']}\n")
        md_file.write(f"- TIMEOUT: {counts['TIMEOUT']}\n")
        md_file.write(f"- UNKNOWN: {counts['UNKNOWN']} (includes NO_LOG)\n")
        md_file.write(f"- Coverage: {1 if cov else 0}\n")
        md_file.write(f"- Jobs: {jobs}\n")
        md_file.write(f"- Timeout seconds: {timeout}\n\n")
        md_file.write("`UNKNOWN` means make returned zero but no `TEST PASSED` or `TEST FAILED` marker was found. ")
        md_file.write("`NO_LOG` means `<OUT>/log/run.log` was missing without a non-zero make return code.\n\n")

        md_file.write("## Results\n\n")
        md_file.write(
            "| test | seed | result | return_code | runtime_seconds | out_dir | log_path | reproduce_command | UVM_ERROR | UVM_FATAL |\n"
        )
        md_file.write(
            "| --- | ---: | --- | ---: | ---: | --- | --- | --- | ---: | ---: |\n"
        )
        for result in results:
            md_file.write(
                "| "
                + " | ".join(
                    [
                        _md_cell(result.test),
                        _md_cell(result.seed),
                        _md_cell(result.result),
                        _md_cell("" if result.return_code is None else result.return_code),
                        _md_cell(f"{result.runtime_seconds:.2f}"),
                        _md_cell(result.out_dir),
                        _md_cell(result.log_path),
                        _md_cell(f"`{result.reproduce_command}`"),
                        _md_cell(result.uvm_error_count),
                        _md_cell(result.uvm_fatal_count),
                    ]
                )
                + " |\n"
            )

        non_pass = [result for result in results if result.result != "PASS"]
        if non_pass:
            md_file.write("\n## Non-Passing Cases\n\n")
            for result in non_pass:
                md_file.write(f"### {result.test} seed {result.seed}\n\n")
                md_file.write(f"- Result: {result.result}\n")
                md_file.write(f"- Reason: {result.reason}\n")
                md_file.write(f"- Reproduce: `{result.reproduce_command}`\n")
                md_file.write(f"- Log: `{result.log_path}`\n")
                md_file.write(f"- Make log: `{result.make_log_path}`\n")
                if result.first_error_line:
                    md_file.write(f"- First UVM_ERROR: `{result.first_error_line}`\n")
                if result.first_fatal_line:
                    md_file.write(f"- First UVM_FATAL: `{result.first_fatal_line}`\n")
                md_file.write("\n")

    return summary_path, csv_path


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run AXI crossbar UVM regressions through uvm/sim/Makefile.")
    parser.add_argument("--tests", nargs="+", default=None, help="Makefile test targets to run")
    parser.add_argument("--seeds", nargs="+", type=int, default=None, help="Random seeds to run")
    parser.add_argument("--config", default=None, help="JSON regression config")
    parser.add_argument("--jobs", type=int, default=None, help="Maximum parallel runs")
    parser.add_argument("--timeout", type=int, default=None, help="Per-case timeout in seconds")
    parser.add_argument("--cov", action="store_true", default=None, help="Enable coverage")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without running make")
    parser.add_argument("--out-root", default=None, help="Output root, relative to repo root unless absolute")
    parser.add_argument("--report-dir", default=None, help="Report directory, relative to repo root unless absolute")
    return parser


def main(argv: Optional[list[str]] = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    repo_root = _repo_root()
    sim_dir = repo_root / "uvm" / "sim"

    try:
        config = _load_config(args.config, repo_root)
        tests = args.tests if args.tests is not None else _as_str_list(config.get("tests"), "tests")
        seeds = args.seeds if args.seeds is not None else _as_int_list(config.get("seeds"), "seeds")
        if not tests:
            parser.error("no tests specified; use --tests or a config with tests")
        if not seeds:
            parser.error("no seeds specified; use --seeds or a config with seeds")

        jobs = _positive_int(args.jobs if args.jobs is not None else config.get("jobs", 1), "jobs")
        timeout = _positive_int(
            args.timeout if args.timeout is not None else config.get("timeout", DEFAULT_TIMEOUT_SECONDS),
            "timeout",
        )
        cov = bool(args.cov if args.cov is not None else config.get("cov", False))
        out_root_text = args.out_root if args.out_root is not None else config.get("out_root", DEFAULT_OUT_ROOT)
        report_dir_text = args.report_dir if args.report_dir is not None else config.get("report_dir", DEFAULT_REPORT_DIR)
        out_root_abs = _resolve_repo_output_path(str(out_root_text), repo_root)
        report_dir_abs = _resolve_repo_output_path(str(report_dir_text), repo_root)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    specs = _build_specs(tests, seeds, cov, out_root_abs, repo_root, sim_dir)
    config_name = str(config.get("name", "")) if config else ""

    if args.dry_run:
        print(f"Dry run: {len(specs)} case(s)")
        for spec in specs:
            print(spec.reproduce_command)
        return 0

    print(f"Running {len(specs)} case(s) with jobs={jobs}, timeout={timeout}s, cov={1 if cov else 0}")
    results: list[RunResult] = []
    completed = 0
    with ThreadPoolExecutor(max_workers=jobs) as executor:
        future_to_spec = {executor.submit(_run_one, spec, repo_root, timeout): spec for spec in specs}
        for future in as_completed(future_to_spec):
            spec = future_to_spec[future]
            completed += 1
            try:
                result = future.result()
            except Exception as exc:  # Keep the regression reportable if one worker fails unexpectedly.
                runtime = 0.0
                triage = LogTriage(
                    result="FAIL",
                    log_path=spec.log_path_report,
                    log_exists=spec.log_path_abs.is_file(),
                    return_code=None,
                    timed_out=False,
                    reason=f"regression worker exception: {exc}",
                )
                result = _result_from_triage(spec, triage, runtime)
            results.append(result)
            print(
                f"[{completed}/{len(specs)}] {result.test} seed {result.seed}: "
                f"{result.result} ({result.runtime_seconds:.2f}s)"
            )

    results.sort(key=lambda item: item.index)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    summary_path, csv_path = _write_reports(results, report_dir_abs, timestamp, config_name, cov, jobs, timeout)
    counts = _count_results(results)
    print(
        "Summary: "
        f"PASS={counts['PASS']} FAIL={counts['FAIL']} "
        f"TIMEOUT={counts['TIMEOUT']} UNKNOWN={counts['UNKNOWN']}"
    )
    print(f"Markdown report: {_report_path(summary_path, repo_root)}")
    print(f"CSV report: {_report_path(csv_path, repo_root)}")

    return 0 if all(result.result == "PASS" for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
