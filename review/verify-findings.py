#!/usr/bin/env python3
"""Reproduce review findings against the unmodified collector using fake probes.

Does not run the full collector or change machine state. These assertions
document existing defects; invert them when implementing the corresponding fixes.
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "review/baseline/doctor-checks.sh").read_text().split("\ncheck_failed_services\n")[0]
cases = [
    ("Temperature critical limit mistaken for current temperature",
     "sensors() { printf 'Package id 0: +48.0°C (high = +85.0°C, crit = +100.0°C)\\n'; }; check_temperature",
     "bad\tTemperature\tHighest reported temperature is 100.0°C."),
    ("Failed systemctl reported healthy",
     "systemctl() { return 1; }; check_failed_services",
     "ok\tServices\tNo failed systemd units."),
    ("Failed journal query reported healthy",
     "journalctl() { return 1; }; check_journal",
     "ok\tJournal\tNo priority 3 or higher errors found this boot."),
    ("Failed package query reported intact",
     "pacman() { return 1; }; check_packages",
     "ok\tPackages\tPackage files look intact; 0 orphan package(s) found."),
    ("Failed coredump query reported healthy",
     "coredumpctl() { return 1; }; check_crashes",
     "ok\tCrashes\tNo core dumps recorded since midnight."),
    ("Benign QML message counted as warning",
     "journalctl() { printf 'quickshell: loaded Main.qml successfully\\n'; }; check_shell",
     "warn\tOmarchy shell\t1 recent Omarchy or Quickshell warning/error line(s)"),
    ("NVIDIA unavailable measurements reported healthy",
     "lspci() { printf 'NVIDIA\\n'; }; nvidia-smi() { printf 'N/A, N/A, N/A, N/A, 580.0\\n'; }; check_nvidia",
     "ok\tNVIDIA\tGPU N/A°C, N/A% load, N/A/N/A MiB VRAM"),
]
observations = []
for title, fixture, expected in cases:
    result = subprocess.run(["bash", "-c", source + "\n" + fixture],
                            capture_output=True, text=True, timeout=5)
    assert result.returncode == 0, (title, result.stderr)
    assert expected in result.stdout, (title, result.stdout)
    observations.append({"finding": title, "observed": result.stdout.strip()})
print(json.dumps(observations, indent=2))
