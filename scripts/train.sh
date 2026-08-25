#!/usr/bin/env bash
set -Eeuo pipefail

readonly CONFIG_PATH="${1:-/workspace/configs/maya_flux2_klein9b_runware_1000step.yaml}"
readonly DATASET_PATH="${DATASET_PATH:-/workspace/datasets/maya}"
readonly LOCK_PATH="/workspace/logs/klein-training.lock"

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "Training config not found: ${CONFIG_PATH}" >&2
  exit 2
fi

if [[ ! -d "${DATASET_PATH}" ]]; then
  echo "Dataset folder not found: ${DATASET_PATH}" >&2
  exit 2
fi

image_count="$(find "${DATASET_PATH}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '.' | wc -c)"
caption_count="$(find "${DATASET_PATH}" -maxdepth 1 -type f -iname '*.txt' -printf '.' | wc -c)"

if [[ "${image_count}" -eq 0 ]]; then
  echo "No training images found in ${DATASET_PATH}." >&2
  exit 2
fi

if [[ "${image_count}" -ne "${caption_count}" ]]; then
  echo "Dataset mismatch: ${image_count} images but ${caption_count} caption files." >&2
  exit 2
fi

verify-klein --require-gpu

exec 9>"${LOCK_PATH}"
if ! flock -n 9; then
  echo "Another training process is already using this volume." >&2
  exit 3
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
log_path="/workspace/logs/train-${timestamp}.log"

echo "Config: ${CONFIG_PATH}"
echo "Dataset: ${DATASET_PATH} (${image_count} image/caption pairs)"
echo "Log: ${log_path}"

set +e
python /opt/ai-toolkit/run.py "${CONFIG_PATH}" 2>&1 | tee "${log_path}"
train_rc="${PIPESTATUS[0]}"
set -e

if [[ "${train_rc}" -ne 0 ]]; then
  echo "Training failed with exit code ${train_rc}. See ${log_path}." >&2
  exit "${train_rc}"
fi

validation_rc=0
lora_count=0
while IFS= read -r -d '' lora_path; do
  lora_count=$((lora_count + 1))
  if ! validate-runware-lora "${lora_path}"; then
    validation_rc=1
  fi
done < <(find /workspace/output -type f -name '*.safetensors' -print0)

if [[ "${lora_count}" -eq 0 ]]; then
  echo "Training returned success but no .safetensors LoRA was found." >&2
  exit 4
fi

if [[ "${validation_rc}" -ne 0 ]]; then
  echo "Training completed, but at least one LoRA failed static Runware validation." >&2
  exit 4
fi

echo "Training and static Runware validation completed."
