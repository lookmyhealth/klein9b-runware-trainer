# FLUX.2 Klein 9B Runware-compatible LoRA trainer

This image preserves the environment that produced the verified Runware-compatible LoRA checkpoints. The environment and AI Toolkit source are immutable inside the image; the RunPod network volume contains only persistent data.

## Proven stack

- Ubuntu 24.04, pinned NVIDIA CUDA 12.8.1 base plus PyTorch CUDA 12.8 runtime wheels
- Python 3.12
- PyTorch 2.8.0 + CUDA 12.8
- AI Toolkit commit `8436c407f655d22c7ef3a4007524a0ce5e46277e`
- Diffusers commit `c943837899b16cbae2f619b8dd4f7bb6f07dd81a`
- `transformers==5.5.3`, `peft==0.18.1`, `torchao==0.10.0`
- `save_format: diffusers`, BF16 output, PEFT `lora_A`/`lora_B` tensors

The image does **not** contain Hugging Face tokens, model weights, training images, captions, or LoRA files.

## Persistent volume layout

Attach network volume `8js0x3ituv` (`flux2-klein9b-lora_volume`) at `/workspace`.

```text
/workspace/
  configs/     editable YAML configurations
  datasets/    training image/caption pairs
  hf-cache/    downloaded BFL, Qwen, and VAE weights
  logs/        training logs and the concurrency lock
  output/      checkpoints and final LoRAs
```

The older `/workspace/ai-toolkit` directory may remain on the existing volume, but this image never runs code from it. It always runs the pinned copy at `/opt/ai-toolkit`, eliminating environment corruption from the persistent volume.

## Build and publish with GitHub

1. Create a GitHub repository and copy this project into it.
2. Open **Actions → Build pinned RunPod trainer image → Run workflow**. The workflow publishes `ghcr.io/lookmyhealth/klein9b-runware-trainer:v1`.
3. Make the GHCR package public, or add private registry credentials in RunPod.
4. For a frozen release, create tag `v1.0.0` and use that tag in RunPod.

The recommended choice is a public GHCR package because this image contains no private data and RunPod needs no registry password to pull it.

## RunPod template

Use these settings:

- Container image: `ghcr.io/lookmyhealth/klein9b-runware-trainer:v1.0.0`
- Container disk: 50 GB
- HTTP port: `8888`
- TCP port: `22`
- Volume mount path: `/workspace`
- Entrypoint/start command: leave empty so the Docker image defaults are used
- GPU: one 48 GB-class GPU, preferably RTX A6000 or L40S
- Network volume: `8js0x3ituv`

Store `HF_TOKEN` as a RunPod secret/environment variable only when the gated model must be downloaded. Never add it to the image or repository.

## Training

The container copies the proven 1000-step config to the volume only when that file is absent. It does not overwrite edits.

```bash
train-klein
```

The default settings are 1000 steps, learning rate `0.00008`, rank 16, and checkpoints every 200 steps. The dataset is expected at `/workspace/datasets/maya` with one `.txt` caption beside every image. Outputs go to `/workspace/output`.

To use another config:

```bash
train-klein /workspace/configs/another.yaml
```

Every generated `.safetensors` file is checked after training for a readable header and the PEFT key format accepted by Runware.

## Verification

```bash
verify-klein --require-gpu
validate-runware-lora /workspace/output/path/to/file.safetensors
```

The full 243-package snapshot from the successful pod is stored in `reference/pip-freeze-known-good.txt` for auditing. It is a reference snapshot, not an install file, because the original virtual environment exposed several Ubuntu system packages.

## Important operating rule

Pin the RunPod template to `v1.0.0` (or, for maximum immutability, the GHCR digest shown after the build). Do not use `latest`. A tag or digest prevents future dependency updates from silently changing the trainer.
