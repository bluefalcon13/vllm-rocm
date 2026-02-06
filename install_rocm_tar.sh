#!/bin/bash
# install_rocm_tarball.sh
#
# Downloads and installs ROCm from a tarball.
# Supports nightlies, prereleases, devreleases, and stable releases.
#
# Usage:
#   ./install_rocm_tarball.sh <VERSION> <AMDGPU_FAMILY> [RELEASE_TYPE]
#
# Arguments:
#   VERSION          - Full version string (e.g., 7.11.0a20251211, 7.10.0)
#   AMDGPU_FAMILY    - AMD GPU family (e.g., gfx110X-all, gfx94X-dcgpu)
#   RELEASE_TYPE     - Release type: nightlies (default), prereleases, devreleases, stable
#
# Examples:
#   ./install_rocm_tarball.sh 7.11.0a20251211 gfx110X-all
#   ./install_rocm_tarball.sh 7.11.0a20251211 gfx94X-dcgpu nightlies
#   ./install_rocm_tarball.sh 7.10.0rc2 gfx110X-all prereleases
#   ./install_rocm_tarball.sh 7.10.0 gfx94X-dcgpu stable

set -eu

# Parse arguments
VERSION="${1:?Error: VERSION is required}"
AMDGPU_FAMILY="${2:?Error: AMDGPU_FAMILY is required}"

# Build tarball URL based on release type
# - stable releases use: https://repo.amd.com/rocm/tarball/
# - other releases use: https://rocm.{RELEASE_TYPE}.amd.com/tarball/

echo "=============================================="
echo "ROCm Tarball Installation"
echo "=============================================="
echo "Version:         ${VERSION}"
echo "AMDGPU Family:   ${AMDGPU_FAMILY}"
echo "=============================================="

# Download tarball
TARBALL_FILE="/tmp/rocm-tarball.tar.gz"

# Verify download
if [ ! -f "$TARBALL_FILE" ] || [ ! -s "$TARBALL_FILE" ]; then
    echo "Error: Downloaded file is empty or does not exist"
    exit 1
fi

# Install directory is fixed to /opt/rocm-{VERSION}
ROCM_INSTALL_DIR="/opt/rocm-${VERSION}"

# Extract tarball to versioned directory
echo "Extracting tarball to ${ROCM_INSTALL_DIR}..."
mkdir -p "$ROCM_INSTALL_DIR"
tar -xzf "$TARBALL_FILE" -C "$ROCM_INSTALL_DIR"

# Clean up downloaded file
rm -f "$TARBALL_FILE"
echo "Tarball extracted and cleaned up"

# Create symlink /opt/rocm -> /opt/rocm-{VERSION} for compatibility
ln -sfn "$ROCM_INSTALL_DIR" /opt/rocm
echo "Created symlink: /opt/rocm -> $ROCM_INSTALL_DIR"

# Verify bin and lib folder exists after extraction
echo "Verifying installation..."
for dir in bin clients include lib libexec share; do
    if [ ! -d "$ROCM_INSTALL_DIR/$dir" ]; then
        echo "Error: ROCm $dir directory not found"
        exit 1
    fi
    echo "ROCm $dir found in $ROCM_INSTALL_DIR/$dir"
done