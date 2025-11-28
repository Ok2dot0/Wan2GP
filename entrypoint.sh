#!/usr/bin/env bash
export HOME=/home/user
export PYTHONUNBUFFERED=1
export HF_HOME=/home/user/.cache/huggingface

export OMP_NUM_THREADS=$(nproc)
export MKL_NUM_THREADS=$(nproc)
export OPENBLAS_NUM_THREADS=$(nproc)
export NUMEXPR_NUM_THREADS=$(nproc)

export TORCH_ALLOW_TF32_CUBLAS=1
export TORCH_ALLOW_TF32_CUDNN=1

# Disable audio warnings in Docker
export SDL_AUDIODRIVER=dummy
export PULSE_RUNTIME_PATH=/tmp/pulse-runtime

# ======================= CUDA DEBUG CHECKS ===========================

echo "[DEBUG] CUDA Environment Debug Information:"
echo "==========================================================================="

# Check CUDA driver on host (if accessible)
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "[OK] nvidia-smi available"
    echo "[INFO] GPU Information:"
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv,noheader,nounits 2>/dev/null || echo "[ERROR] nvidia-smi failed to query GPU"
    echo "[INFO] Running Processes:"
    nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv,noheader,nounits 2>/dev/null || echo "[INFO] No running CUDA processes"
else
    echo "[ERROR] nvidia-smi not available in container"
fi

# Check CUDA runtime libraries
echo ""
echo "[CHECK] CUDA Runtime Check:"
if ls /usr/local/cuda*/lib*/libcudart.so* >/dev/null 2>&1; then
    echo "[OK] CUDA runtime libraries found:"
    ls /usr/local/cuda*/lib*/libcudart.so* 2>/dev/null
else
    echo "[ERROR] CUDA runtime libraries not found"
fi

# Check CUDA devices
echo ""
echo "[CHECK] CUDA Device Files:"
if ls /dev/nvidia* >/dev/null 2>&1; then
    echo "[OK] NVIDIA device files found:"
    ls -la /dev/nvidia* 2>/dev/null
else
    echo "[ERROR] No NVIDIA device files found - Docker may not have GPU access"
fi

# Check CUDA environment variables
echo ""
echo "[CHECK] CUDA Environment Variables:"
echo "   CUDA_HOME: ${CUDA_HOME:-not set}"
echo "   CUDA_ROOT: ${CUDA_ROOT:-not set}"
echo "   CUDA_PATH: ${CUDA_PATH:-not set}"
echo "   LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-not set}"
echo "   TORCH_CUDA_ARCH_LIST: ${TORCH_CUDA_ARCH_LIST:-not set}"
echo "   CUDA_VISIBLE_DEVICES: ${CUDA_VISIBLE_DEVICES:-not set}"

# Check PyTorch CUDA availability
echo ""
echo "[CHECK] PyTorch CUDA Check:"
python3 -c "
import sys
try:
    import torch
    print('[OK] PyTorch imported successfully')
    print(f'   Version: {torch.__version__}')
    print(f'   CUDA available: {torch.cuda.is_available()}')
    if torch.cuda.is_available():
        print(f'   CUDA version: {torch.version.cuda}')
        print(f'   cuDNN version: {torch.backends.cudnn.version()}')
        print(f'   Device count: {torch.cuda.device_count()}')
        for i in range(torch.cuda.device_count()):
            props = torch.cuda.get_device_properties(i)
            print(f'   Device {i}: {props.name} (SM {props.major}.{props.minor}, {props.total_memory//1024//1024}MB)')
    else:
        print('[ERROR] CUDA not available to PyTorch')
        print('   This could mean:')
        print('   - CUDA runtime not properly installed')
        print('   - GPU not accessible to container')
        print('   - Driver/runtime version mismatch')
except ImportError as e:
    print(f'[ERROR] Failed to import PyTorch: {e}')
except Exception as e:
    print(f'[ERROR] PyTorch CUDA check failed: {e}')
" 2>&1

# Check for common CUDA issues
echo ""
echo "[DIAGNOSTICS] Common Issue Diagnostics:"

# First check if PyTorch can actually use CUDA - this is the authoritative test
PYTORCH_CUDA_WORKS=$(python3 -c "import torch; print('yes' if torch.cuda.is_available() and torch.cuda.device_count() > 0 else 'no')" 2>/dev/null)

if [ "$PYTORCH_CUDA_WORKS" = "yes" ]; then
    echo "[OK] GPU access confirmed - PyTorch can use CUDA"
else
    # Only show detailed diagnostics if PyTorch can't use CUDA
    # Check if running with proper Docker flags
    if [ ! -e /dev/nvidia0 ] && [ ! -e /dev/nvidiactl ]; then
        echo "[ERROR] No NVIDIA device nodes - container likely missing --gpus all or --runtime=nvidia"
        echo "   Note: On Docker Desktop for Windows (WSL2), device files may not be visible"
        echo "   but GPU access can still work through WSL2 GPU paravirtualization."
    fi

    # Check CUDA library paths
    if [ -z "$LD_LIBRARY_PATH" ] || ! echo "$LD_LIBRARY_PATH" | grep -q cuda; then
        echo "[WARN] LD_LIBRARY_PATH may not include CUDA libraries"
    fi

    # Check permissions on device files
    if ls /dev/nvidia* >/dev/null 2>&1; then
        if ! ls -la /dev/nvidia* | grep -q "rw-rw-rw-\|rw-r--r--"; then
            echo "[WARN] NVIDIA device files may have restrictive permissions"
        fi
    fi
fi

echo "==========================================================================="
echo "[START] Starting application..."
echo ""

exec su -p user -c "python3 wgp.py --listen $*"
