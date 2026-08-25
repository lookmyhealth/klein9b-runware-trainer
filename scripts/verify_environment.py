#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib
import importlib.metadata
import subprocess
import sys
from pathlib import Path


EXPECTED = {
    "accelerate": "1.14.0",
    "diffusers": "0.39.0.dev0",
    "huggingface_hub": "1.23.0",
    "optimum-quanto": "0.2.4",
    "peft": "0.18.1",
    "safetensors": "0.8.0",
    "torch": "2.8.0+cu128",
    "torchao": "0.10.0",
    "transformers": "5.5.3",
}
AI_TOOLKIT_COMMIT = "8436c407f655d22c7ef3a4007524a0ce5e46277e"
AI_TOOLKIT_ROOT = Path("/opt/ai-toolkit")
IMPORTS = (
    "bitsandbytes",
    "diffusers",
    "optimum.quanto",
    "peft",
    "safetensors",
    "torch",
    "torchao",
    "transformers",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-gpu", action="store_true")
    args = parser.parse_args()

    failures: list[str] = []
    for module in IMPORTS:
        try:
            importlib.import_module(module)
        except Exception as exc:
            failures.append(f"{module}: import failed: {exc}")

    for package, expected in EXPECTED.items():
        try:
            actual = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            failures.append(f"{package}: missing (expected {expected})")
            continue
        print(f"{package}={actual}")
        if actual != expected:
            failures.append(f"{package}: {actual} (expected {expected})")

    try:
        actual_commit = subprocess.check_output(
            ["git", "-C", str(AI_TOOLKIT_ROOT), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except (OSError, subprocess.CalledProcessError) as exc:
        failures.append(f"AI Toolkit commit unreadable: {exc}")
    else:
        print(f"ai-toolkit={actual_commit}")
        if actual_commit != AI_TOOLKIT_COMMIT:
            failures.append(
                f"AI Toolkit: {actual_commit} (expected {AI_TOOLKIT_COMMIT})"
            )

    if args.require_gpu:
        import torch

        if not torch.cuda.is_available():
            failures.append("CUDA GPU is not available")
        else:
            print(f"gpu={torch.cuda.get_device_name(0)}")
            total_gib = torch.cuda.get_device_properties(0).total_memory / 2**30
            print(f"vram_gib={total_gib:.1f}")
            if total_gib < 45:
                failures.append(f"GPU has only {total_gib:.1f} GiB VRAM; 48 GB class required")

    if failures:
        print("ENVIRONMENT_CHECK=FAIL", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("ENVIRONMENT_CHECK=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
