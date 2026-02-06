ARG AMDGPU_FAMILY=gfx120X-all
ARG GPU_ARCH=gfx1201
ARG VERSION_ENCODED=7.10.0

FROM ubuntu:24.04 AS base
ENV PYTHONUNBUFFERED=1
ARG AMDGPU_FAMILY
ARG VERSION_ENCODED
ARG GPU_ARCH

# install rocm dependencies via apt
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    file \
    kmod \
    git \
    libdw1t64 \
    libelf1 \
    libncurses6 \
    libnuma1 \
    libssl3 \
    libunwind8 \
    perl \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv && \
    rm -rf /var/lib/apt/lists/* && \
    cd /opt && python3 -m venv ./venv
ENV PATH="/opt/venv/bin:${PATH}"

# # install rocm from tarball
# ADD https://repo.amd.com/rocm/tarball/therock-dist-linux-${AMDGPU_FAMILY}-${VERSION_ENCODED}.tar.gz /tmp/rocm-tarball.tar.gz
# ADD ./install_rocm_tar.sh /tmp/install_rocm_tar.sh
# RUN chmod +x /tmp/install_rocm_tar.sh && \
#     /tmp/install_rocm_tar.sh ${VERSION_ENCODED} ${AMDGPU_FAMILY} && \
#     rm -rf /tmp/rocm-tarball.tar.gz install_rocm_tar.sh
# ENV ROCM_PATH="/opt/rocm"
# ENV PATH="${ROCM_PATH}/bin:${PATH}"
    
# install pytorch
RUN pip install --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/ rocm[base,devel,libraries-gfx120x-all] torch torchaudio torchvision
RUN pip install packaging setuptools ninja cmake
RUN rocm-sdk init

ENV ROCM_PATH="/opt/venv"

# install flash attention
# NOTE: this flash attention enables gfx12 support
WORKDIR /workspace
# RUN git clone https://github.com/ROCm/flash-attention.git && \
RUN git clone https://github.com/hyoon1/flash-attention.git && \
    cd flash-attention && \
    git checkout enable-ck-gfx12 && \
    # git checkout 0e60e394 && \
    FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE" python setup.py install

# install aiter
RUN git clone https://github.com/EmbeddedLLM/aiter.git && \
    cd aiter && \
    git checkout support_gfx1201 && \
    git submodule sync && git submodule update --init --recursive && \
    pip install -e ./ && \
    pip install -r requirements-triton-comms.txt

# install vllm
RUN pip install --upgrade pip && \
    # Build & install AMD SMI
    pip install /opt/rocm/share/amd_smi && \
    # Install dependencies
    pip install --upgrade numba \
        scipy \
        huggingface-hub[cli,hf_transfer] \
        setuptools_scm

RUN git clone https://github.com/vllm-project/vllm.git && \
    cd ./vllm && \
    git checkout v0.15.1 && \
    pip install -r requirements/rocm.txt && \
    PYTORCH_ROCM_ARCH="${GPU_ARCH}" \
    GPU_TARGETS="${GPU_ARCH}" \
    python3 setup.py install