#!/usr/bin/env python3
import os
import sys
from safetensors import safe_open


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} FILE.safetensors", file=sys.stderr)
        return 2

    path = os.path.abspath(sys.argv[1])
    if not os.path.isfile(path):
        print(f"File not found: {path}", file=sys.stderr)
        return 2

    try:
        handle = safe_open(path, framework="pt")
        keys = list(handle.keys())
        metadata = handle.metadata() or {}
    except Exception as exc:
        print(f"HEADER_INVALID: {exc}", file=sys.stderr)
        return 1

    peft_a = sum(".lora_A.weight" in key for key in keys)
    peft_b = sum(".lora_B.weight" in key for key in keys)
    kohya_down = sum(".lora_down.weight" in key for key in keys)
    kohya_up = sum(".lora_up.weight" in key for key in keys)
    alpha = sum(key.endswith(".alpha") for key in keys)

    compatible = (
        peft_a > 0
        and peft_a == peft_b
        and kohya_down == 0
        and kohya_up == 0
        and alpha == 0
    )

    print("HEADER_OK")
    print(f"FILE={path}")
    print(f"FILE_BYTES={os.path.getsize(path)}")
    print(f"TOTAL_KEYS={len(keys)}")
    print(f"PEFT_LORA_A={peft_a}")
    print(f"PEFT_LORA_B={peft_b}")
    print(f"KOHYA_DOWN={kohya_down}")
    print(f"KOHYA_UP={kohya_up}")
    print(f"ALPHA_KEYS={alpha}")
    print(f"METADATA={metadata}")
    print(
        "STATIC_RUNWARE_COMPATIBILITY=PASS"
        if compatible
        else "STATIC_RUNWARE_COMPATIBILITY=FAIL"
    )
    return 0 if compatible else 1


if __name__ == "__main__":
    raise SystemExit(main())
