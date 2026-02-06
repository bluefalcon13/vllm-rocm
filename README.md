# 🚀 RDNA 4 (gfx1201) Hardware Enablement
This project implements a custom vLLM build environment optimized specifically for AMD RDNA 4 (gfx1201) architectures.
Standard vLLM builds often lack native support for gfx12, leading to de-quantization fallbacks or architecture-mismatch errors.
I was averaging approximately 32 Tokens per second on release builds of ROCm and vLLM.

## 🤝 Special Thanks & Credits

A huge thank you to the developers and researchers working on the bleeding edge of ROCm support. This build is only possible thanks to:

* **The AMD ROCm Team:** For providing the `TheRock` nightly builds that finally stabilized the `gfx120X` toolchain.
* **hyoon1 & Contributors:** For the `enable-ck-gfx12` branch of Flash Attention, which unlocked high-performance kernels for RDNA 4.
* **The vLLM Community:** For the ongoing work to make open-source inference accessible on consumer hardware.

---

## Key Implementation Details:
TheRock Nightly Stack: Utilizes the therock-dist-linux-gfx120X nightly toolchain from AMD.
This provides the modular CMake environment required to compile for gfx1201 without the dependency fragility of standard amdgpu-install paths.

Native FP8 Execution: By forcing the architecture ID (GPU_ARCH=gfx1201) across the entire build stack, we successfully trigger the PerTensorTorchFP8ScaledMMLinearKernel.
This ensures the 9070 XT's AI accelerators are used directly for FP8 math, avoiding the 3-4x performance penalty of FP32 de-quantization.

Flash Attention (CK-Branch): We build a specialized Composable Kernel (CK) branch of Flash Attention (hyoon1/flash-attention:enable-ck-gfx12).
This provides high-performance attention kernels tuned for the RDNA 4 instruction set, bypassing the standard Triton architecture checks.

### Baseline Performance (9070 XT - 16GB):
- Model: Llama-3.1-8B-Instruct-FP8

- Engine Throughput: ~250 tokens/s (Aggregate)

- Latency (TPOT): ~22.9ms (Single-stream efficiency)

- Bottleneck: VRAM capacity (16GB).
High request rates (>10 RPS) lead to KV-cache saturation and queue contention, highlighting the need for Unified Memory (Framework Desktop) in multi-user scenarios.

### 📊 Performance Reference (16GB Baseline)
The following results were captured using a Radeon 9070 XT (16GB VRAM).
This data serves as a reference for the performance ceiling and memory-induced latency bottlenecks of discrete consumer hardware when running high-concurrency LLM workloads.

| Metric | Result | Note |
| :--- | :--- | :--- |
| **Model** | `Meta-Llama-3.1-8B-Instruct-FP8` | Quantized via CompressedTensors |
| **Output Throughput** | **248.12 tokens/s** | Sustained GPU generation speed |
| **Peak Throughput** | **325.00 tokens/s** | Maximum observed engine burst |
| **Mean TPOT** | **22.94 ms** | Time Per Output Token (per user efficiency) |
| **Mean TTFT** | **187,872.60 ms** | **~3.1 minutes** (Queue-induced latency) |
| **Max Concurrency** | **~5-6 Active Requests** | Limited by 16GB VRAM KV-Cache |

## The "16GB Wall"
While the RDNA 4 architecture provides excellent raw generation speeds (~23ms per token), the 16GB VRAM capacity creates a significant processing bottleneck. At a request rate of 10 RPS, the engine quickly saturates the available GPU memory.

- High Contention: With over 190 requests waiting in the queue, the Time To First Token (TTFT) scales into several minutes.

- System RAM Underutilization: Host memory usage remains low (~13.1 GB) because the discrete GPU cannot effectively offload the active KV-Cache to system RAM.

---

### 🛠️ Build Configuration & Security Notes

This build requires **Docker Buildx** with entitlement for insecure security specifications to allow the `git clone` operations within the custom build stages.

#### **1. Initialize the Unsecure Builder**
Before building, you must create a builder instance that permits the `--security=insecure` flag used in the Dockerfile:

```bash
docker buildx create --name unsecure_builder --buildkitd-flags '--allow-insecure-entitlement security.insecure' --use
docker buildx inspect --bootstrap
```

#### **2. Execute the Build**
Use the following command to build the image for the `gfx1201` architecture. This command enables the necessary entitlements to bypass the restricted network/security sandbox for the specialized kernel compilation steps:

```bash
docker buildx build --allow security.insecure -t vllm-rocm-gfx1201:latest . --load
```

#### Note on Security
The `--security=insecure` flag in the Dockerfile is utilized specifically to facilitate the identification of the hardware. 
Ensure you are building in a trusted environment and audit the Dockerfile stages if deploying to production.
Additionally, even though it is built in a docker, it does need to be able to see the hardware enough that vLLM will make some intelligent build decisions. 
vLLM is complicated, and tries to simplify the build process as much as possible.
Open to pull requests from folks who have more vLLM build experience or the time to sort through it all!