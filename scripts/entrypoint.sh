#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_CONFIG="/opt/klein-trainer/config/maya_flux2_klein9b_runware_1000step.yaml"
readonly VOLUME_CONFIG="/workspace/configs/maya_flux2_klein9b_runware_1000step.yaml"

mkdir -p \
  /workspace/configs \
  /workspace/datasets \
  /workspace/hf-cache \
  /workspace/logs \
  /workspace/output

if [[ ! -e "${VOLUME_CONFIG}" ]]; then
  install -m 0644 "${DEFAULT_CONFIG}" "${VOLUME_CONFIG}"
  echo "Installed default training config: ${VOLUME_CONFIG}"
fi

if [[ -n "${PUBLIC_KEY:-}" ]]; then
  install -d -m 0700 /root/.ssh
  printf '%s\n' "${PUBLIC_KEY}" > /root/.ssh/authorized_keys
  chmod 0600 /root/.ssh/authorized_keys
  ssh-keygen -A
  /usr/sbin/sshd
  echo "SSH enabled with PUBLIC_KEY."
fi

verify-klein

case "${1:-jupyter}" in
  jupyter)
    exec jupyter lab \
      --allow-root \
      --ip=0.0.0.0 \
      --port=8888 \
      --no-browser \
      --ServerApp.root_dir=/workspace \
      --ServerApp.allow_remote_access=True \
      --ServerApp.token="${JUPYTER_TOKEN:-}" \
      --ServerApp.password=''
    ;;
  train)
    shift
    exec train-klein "$@"
    ;;
  verify)
    shift
    exec verify-klein "$@"
    ;;
  shell)
    shift
    exec /bin/bash "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
