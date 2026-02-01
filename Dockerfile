# syntax=docker/dockerfile:1-labs
ARG AMDGPU_FAMILY=gfx120X-all
ARG GPU_ARCH=gfx1201
ARG ROCM_VERSION=7.12.0a20260205

FROM ubuntu:24.04 AS base
ENV PYTHONUNBUFFERED=1
ARG AMDGPU_FAMILY
ARG GPU_ARCH
ARG ROCM_VERSION

SHELL ["/bin/bash", "-l", "-c"]
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    libatomic1 \
    libgomp1 \
    libnuma-dev \
    wget && \
    rm -rf /var/lib/apt/lists/*

# setup venv and make the env active for all shell sessions,
# including run commands
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH=/root/.local/bin:$PATH
ENV PATH="/root/.local/bin:${PATH}"
RUN cd /app && uv venv --python 3.12 && \
    source .venv/bin/activate && \
    echo "source /app/.venv/bin/activate" > /root/.bash_profile



# install ROCm python packages
RUN uv pip install \
    --index-url https://rocm.nightlies.amd.com/v2/${AMDGPU_FAMILY}/ \
    "rocm[libraries, devel]" && \
    uv pip install \
    --index-url https://rocm.nightlies.amd.com/v2/${AMDGPU_FAMILY}/ \
    torch torchvision torchaudio

# install tarball of rocm
RUN mkdir -p /opt/rocm-$ROCM_VERSION && \
    wget https://rocm.nightlies.amd.com/tarball/therock-dist-linux-$AMDGPU_FAMILY-$ROCM_VERSION.tar.gz && \
    tar xzf ./therock-dist-linux-$AMDGPU_FAMILY-$ROCM_VERSION.tar.gz -C /opt/rocm-$ROCM_VERSION && \
    rm therock-dist-linux-$AMDGPU_FAMILY-$ROCM_VERSION.tar.gz && \
    ln -s /opt/rocm-$ROCM_VERSION /opt/rocm

ENV ROCM_PATH=/opt/rocm
ENV LD_LIBRARY_PATH=$ROCM_PATH/lib
# ENV CMAKE_PREFIX_PATH="/app/.venv/lib/python3.12/site-packages/torch/share/cmake/Torch"
ENV DEVICE_LIB_PATH=$ROCM_PATH/llvm/amdgcn/bitcode  
ENV HIP_DEVICE_LIB_PATH=$ROCM_PATH/llvm/amdgcn/bitcode
ENV FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE"
ENV PYTORCH_ROCM_ARCH=${GPU_ARCH}
ENV PATH=${ROCM_PATH}/bin:${ROCM_PATH}/llvm/bin:${PATH}
ENV CC=$ROCM_PATH/llvm/bin/clang
ENV CXX=$ROCM_PATH/llvm/bin/clang++
ENV HIPCC=$ROCM_PATH/bin/hipcc
ENV VLLM_TARGET_DEVICE="rocm"
ENV GPU_TARGETS="${GPU_ARCH}"
ENV Torch_DIR="/app/.venv/lib/python3.12/site-packages/torch/share/cmake/Torch"

# copy .bash_profile to .bashrc
RUN cp /root/.bash_profile /root/.bashrc



# clone vllm
RUN --security=insecure git clone https://github.com/vllm-project/vllm.git && \
    cd vllm && git checkout -b v0.16.0rc0 && \
    python use_existing_torch.py && \
    uv pip install --upgrade numba \
        scipy \
        cmake \
        setuptools_scm && \
    uv pip install "numpy<2" && \
    # uv pip install -r requirements/rocm.txt
    uv pip install -r requirements/rocm.txt && \
    python setup.py develop && \
    uv pip install /opt/rocm/share/amd_smi

RUN git clone https://github.com/hyoon1/flash-attention.git && \    
# RUN git clone https://github.com/ROCm/flash-attention.git && \
    cd flash-attention && \
    git checkout enable-ck-gfx12 && \
    FLASH_ATTENTION_TRITON_AMD_ENABLE="TRUE" python setup.py install

ENTRYPOINT [ "/app/.venv/bin/vllm","serve"]