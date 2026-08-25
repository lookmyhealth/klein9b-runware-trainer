# syntax=docker/dockerfile:1.7

# Pinned linux/amd64 manifest for nvidia/cuda:12.8.1-base-ubuntu24.04.
# PyTorch cu128 wheels below provide the exact cuDNN/CUDA runtime libraries.
FROM --platform=linux/amd64 nvidia/cuda:12.8.1-base-ubuntu24.04@sha256:e711c99333fdfe8ae1e677b4972be6c5021f0128a1d31f775c7e58d88921b6a9

ARG AI_TOOLKIT_COMMIT=8436c407f655d22c7ef3a4007524a0ce5e46277e
ARG DIFFUSERS_COMMIT=c943837899b16cbae2f619b8dd4f7bb6f07dd81a

LABEL org.opencontainers.image.title="FLUX.2 Klein 9B Runware LoRA trainer" \
      org.opencontainers.image.description="Pinned AI Toolkit environment for Runware-compatible FLUX.2 Klein 9B LoRAs" \
      org.opencontainers.image.source="https://github.com/lookmyhealth/klein9b-runware-trainer" \
      io.lookmyhealth.ai-toolkit-commit="${AI_TOOLKIT_COMMIT}" \
      io.lookmyhealth.diffusers-commit="${DIFFUSERS_COMMIT}"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HF_HOME=/workspace/hf-cache \
    HUGGINGFACE_HUB_CACHE=/workspace/hf-cache/hub \
    TRANSFORMERS_CACHE=/workspace/hf-cache/transformers \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    AI_TOOLKIT_ROOT=/opt/ai-toolkit \
    TRAINER_ROOT=/opt/klein-trainer \
    WORKSPACE_ROOT=/workspace

RUN apt-get update && apt-get install --no-install-recommends -y \
        bash \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        git-lfs \
        htop \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        openssh-server \
        python3.12 \
        python3.12-dev \
        python3.12-venv \
        rsync \
        tini \
        tmux \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install --system \
    && python3.12 -m venv "${VIRTUAL_ENV}"

RUN python -m pip install --no-cache-dir \
        pip==25.3 \
        setuptools==84.0.0 \
        wheel==0.48.0 \
    && python -m pip install --no-cache-dir \
        torch==2.8.0 \
        torchvision==0.23.0 \
        torchaudio==2.8.0 \
        --index-url https://download.pytorch.org/whl/cu128

COPY requirements.txt /opt/klein-trainer/requirements.txt
COPY reference/pip-freeze-known-good.txt /opt/klein-trainer/reference/pip-freeze-known-good.txt
RUN python -m pip install --no-cache-dir \
        --constraint /opt/klein-trainer/reference/pip-freeze-known-good.txt \
        --requirement /opt/klein-trainer/requirements.txt

RUN git clone --filter=blob:none https://github.com/ostris/ai-toolkit.git /opt/ai-toolkit \
    && git -C /opt/ai-toolkit checkout --detach "${AI_TOOLKIT_COMMIT}" \
    && test "$(git -C /opt/ai-toolkit rev-parse HEAD)" = "${AI_TOOLKIT_COMMIT}" \
    && rm -rf /opt/ai-toolkit/.git/hooks /opt/ai-toolkit/.git/logs

COPY config/ /opt/klein-trainer/config/
COPY scripts/ /opt/klein-trainer/scripts/

RUN chmod 0755 /opt/klein-trainer/scripts/*.sh /opt/klein-trainer/scripts/*.py \
    && ln -s /opt/klein-trainer/scripts/train.sh /usr/local/bin/train-klein \
    && ln -s /opt/klein-trainer/scripts/verify_environment.py /usr/local/bin/verify-klein \
    && ln -s /opt/klein-trainer/scripts/validate_runware_lora.py /usr/local/bin/validate-runware-lora \
    && mkdir -p /run/sshd \
    && printf '%s\n' \
        'PermitRootLogin prohibit-password' \
        'PasswordAuthentication no' \
        'PubkeyAuthentication yes' \
        > /etc/ssh/sshd_config.d/99-runpod.conf \
    && verify-klein

WORKDIR /workspace
EXPOSE 8888 22

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/klein-trainer/scripts/entrypoint.sh"]
CMD ["jupyter"]
