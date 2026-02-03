FROM rocm/pytorch:rocm7.2_ubuntu24.04_py3.12_pytorch_release_2.9.1

WORKDIR /build

ENV PYTORCH_ROCM_ARCH="gfx1201"

# install flash attention
RUN git clone https://github.com/Dao-AILab/flash-attention.git && \
    cd flash-attention && \
    FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE" GPU_ARCHS="gfx1201" python setup.py install

# install aiter
RUN git clone --recursive https://github.com/ROCm/aiter.git && \
    cd aiter && \
    git checkout v0.1.9 && \
    git submodule sync && git submodule update --init --recursive && \
    pip install -e . && \
    pip install -r requirements-triton-comms.txt

# install mori deps
RUN apt update && apt install -y --no-install-recommends \
    cython3 \
    ibverbs-utils \
    openmpi-bin \
    libopenmpi-dev \
    libpci-dev \
    cmake \
    libdw1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# # install mori
ARG MORI_BRANCH="2d02c6a9"
RUN git clone https://github.com/ROCm/mori.git && \
    cd mori && \
    git checkout ${MORI_BRANCH} && \
    git submodule sync; git submodule update --init --recursive && \
    pip install -r requirements-build.txt && \
    MORI_GPU_ARCHS="gfx942;gfx950" pip install -e . --no-build-isolation

# install vllm
RUN git clone https://github.com/vllm-project/vllm.git && \
    cd vllm && \
    git checkout v0.15.0 && \
    pip install --upgrade pip && \
    pip install /opt/rocm/share/amd_smi && \
    pip install --upgrade numba \
    scipy \
    huggingface-hub[cli,hf_transfer] \
    setuptools_scm && \
    pip install -r requirements/rocm.txt && \
    python3 setup.py develop

ENV VLLM_ROCM_USE_AITER=0
ENV VLLM_USE_TRITON_FLASH_ATTN=1
ENV VLLM_TARGET_DEVICE=rocm
ENV SAFETENSORS_FAST_GPU=1
ENV HIP_FORCE_DEV_KERNARG=1

ENV COMMON_WORKDIR=/workspace
# Workaround for ROCm profiler limits
RUN echo "ROCTRACER_MAX_EVENTS=10000000" > ${COMMON_WORKDIR}/libkineto.conf
ENV KINETO_CONFIG="${COMMON_WORKDIR}/libkineto.conf"
RUN echo "VLLM_BASE_IMAGE=${BASE_IMAGE}" >> ${COMMON_WORKDIR}/versions.txt