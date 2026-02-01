# STAGE 1: TheRock Builder
FROM ubuntu:24.04  AS builder

# Set target for 9070XT
ENV AMDGPU_TARGETS=gfx1201
WORKDIR /build

# Install TheRock build dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    automake \
    bison \
    cmake \
    flex \
    g++ \
    gfortran \
    git \
    libegl1-mesa-dev \
    libtool \
    ninja-build \
    patchelf \
    pkg-config \
    python3-dev \
    python3-venv \
    texinfo \
    xxd && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup venv and add to path
RUN python3 -m venv ./.venv
ENV PATH="/build/.venv/bin:$PATH"

# pull TheRock build system
RUN git clone https://github.com/ROCm/TheRock.git ./therock

WORKDIR /build/therock

# install venv python dependencies
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# download submoduiles and apply patches
RUN python3 ./build_tools/fetch_sources.py

# RUN python3 -m venv .venv && source .venv/bin/activate && \
#     pip install --upgrade pip && \
#     pip install -r requirements.txt

# # 2. Build AITER with CF files enabled
# # AITER is often built as a separate wheel or as part of the vLLM setup
# RUN cd vllm/model_executor/layers/quantization/aiter && \
#     python3 setup.py bdist_wheel

# # 3. Build vLLM
# RUN python3 setup.py bdist_wheel

# FROM ubuntu:24.04 AS runtime
# ENV PYTHONUNBUFFERED=1

# # Initialize the runtime image
# # Modify to pre-install dev tools and ROCm packages
# ARG ROCM_VERSION=7.2
# ARG AMDGPU_VERSION=30.30

# # Get amd gpg keys and add to apt keyrings
# RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
#     ca-certificates curl gnupg && \
#     curl -fsSL https://repo.radeon.com/rocm/rocm.gpg.key | \
#     gpg --dearmor -o /usr/share/keyrings/rocm-stack-release.gpg && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

# # Update your sources to use the new unified keyring
# RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm-stack-release.gpg] http://repo.radeon.com/rocm/apt/7.2 noble main" \
#     > /etc/apt/sources.list.d/rocm.list && \
#     echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rocm-stack-release.gpg] https://repo.radeon.com/amdgpu/30.30/ubuntu noble main" \
#     > /etc/apt/sources.list.d/amdgpu.list

# RUN <<EOF cat > /etc/apt/preferences.d/rocm-pin-600
# Package: *
# Pin: release o=repo.radeon.com
# Pin-Priority: 600
# EOF
