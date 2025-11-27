# Windows Docker Installation Guide

This guide covers running WanGP in Docker on Windows systems.

## Prerequisites

### Required Software

1. **Windows 10/11 with WSL2**
   - Windows 10 version 2004 or higher (Build 19041 or higher)
   - Windows 11 (any version)

2. **Docker Desktop for Windows**
   - Download from: https://www.docker.com/products/docker-desktop/
   - During installation, ensure "Use WSL 2 instead of Hyper-V" is selected

3. **NVIDIA Drivers**
   - Download from: https://www.nvidia.com/Download/index.aspx
   - Minimum driver version: 520+ for CUDA 12.4 support

4. **NVIDIA Container Toolkit** (usually included with Docker Desktop)
   - This is typically auto-configured when you install Docker Desktop with GPU support

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| VRAM | 6 GB | 12+ GB |
| RAM | 16 GB | 32+ GB |
| Storage | 50 GB free | 100+ GB free |
| GPU | NVIDIA GTX 10XX+ | RTX 30XX/40XX |

## Installation Steps

### Step 1: Enable WSL2

Open PowerShell as Administrator and run:

```powershell
wsl --install
```

Restart your computer when prompted.

### Step 2: Install Docker Desktop

1. Download Docker Desktop from https://www.docker.com/products/docker-desktop/
2. Run the installer
3. During installation:
   - ✅ Enable "Use WSL 2 instead of Hyper-V"
   - ✅ Enable "Add shortcut to desktop"
4. Restart when prompted

### Step 3: Configure Docker for GPU

1. Open Docker Desktop
2. Go to Settings (⚙️) → Resources → WSL Integration
3. Enable integration with your default WSL distro
4. Go to Settings → Docker Engine
5. Ensure the configuration includes GPU support (usually automatic)

### Step 4: Verify GPU Access

Open PowerShell and run:

```powershell
docker run --rm --gpus all nvidia/cuda:12.4-runtime-ubuntu22.04 nvidia-smi
```

You should see your GPU information. If not, see [Troubleshooting](#troubleshooting).

### Step 5: Clone WanGP Repository

```powershell
git clone https://github.com/deepbeepmeep/Wan2GP.git
cd Wan2GP
```

## Running WanGP in Docker

### Option 1: Using the Windows Batch Script (Simplest)

Double-click `run-docker-cuda-win.bat` or run in Command Prompt:

```cmd
run-docker-cuda-win.bat
```

### Option 2: Using PowerShell Script (More Options)

```powershell
.\run-docker-cuda-win.ps1
```

With custom options:

```powershell
# Specify memory profile (1-5)
.\run-docker-cuda-win.ps1 -Profile 3

# Use different attention mode
.\run-docker-cuda-win.ps1 -Attention flash

# Custom port
.\run-docker-cuda-win.ps1 -Port 8080

# Skip rebuild (use existing image)
.\run-docker-cuda-win.ps1 -NoBuild

# Enable compilation (for RTX 50XX)
.\run-docker-cuda-win.ps1 -Compile
```

### Option 3: Using Docker Compose (Recommended for Advanced Users)

```powershell
# Set your CUDA architecture (optional, auto-detected)
$env:CUDA_ARCH = "8.9"  # For RTX 40XX

# Build and run
docker-compose up --build

# Or just run (after initial build)
docker-compose up

# Run in background
docker-compose up -d

# Stop
docker-compose down
```

### Option 4: Manual Docker Commands

```powershell
# Build the image
docker build --build-arg CUDA_ARCHITECTURES="8.9" -t wan2gp .

# Run the container
docker run --rm -it `
    --gpus all `
    -p 7860:7860 `
    -v ${PWD}:/workspace `
    -v $env:USERPROFILE\.cache\huggingface:/home/user/.cache/huggingface `
    wan2gp `
    --profile 4 `
    --attention sage
```

## Accessing WanGP

Once the container is running, open your browser and navigate to:

```
http://localhost:7860
```

## Memory Profiles

Choose based on your GPU VRAM:

| Profile | Description | VRAM | RAM |
|---------|-------------|------|-----|
| 1 | HighRAM_HighVRAM | 24+ GB | 48+ GB |
| 2 | HighRAM_LowVRAM | 12+ GB | 48+ GB |
| 3 | LowRAM_HighVRAM | 24+ GB | 32+ GB |
| 4 | LowRAM_LowVRAM (Default) | 12+ GB | 32+ GB |
| 5 | VerylowRAM_LowVRAM | 8+ GB | 16+ GB |

## CUDA Architecture Reference

The scripts auto-detect your GPU, but you can override:

| GPU Series | CUDA Architecture |
|------------|-------------------|
| RTX 50XX (Blackwell) | 12.0 |
| H100/H800 (Hopper) | 9.0 |
| RTX 40XX (Ada) | 8.9 |
| RTX 30XX (Ampere) | 8.6 |
| A100/A40 | 8.0 |
| RTX 20XX (Turing) | 7.5 |
| GTX 16XX | 7.5 |
| Tesla V100 | 7.0 |
| GTX 10XX (Pascal) | 6.1 |

## Model Storage

Models are cached in:
- `%USERPROFILE%\.cache\huggingface` - HuggingFace models
- `%USERPROFILE%\.cache\torch` - PyTorch hub models

Output videos are saved in:
- `.\outputs\` (in the WanGP directory)

## Troubleshooting

### Docker Desktop won't start

1. Ensure WSL2 is properly installed:
   ```powershell
   wsl --status
   ```
2. Update WSL:
   ```powershell
   wsl --update
   ```
3. Restart Docker Desktop

### "GPU not detected" error

1. Verify NVIDIA drivers:
   ```powershell
   nvidia-smi
   ```
2. Update NVIDIA drivers to the latest version
3. Restart Docker Desktop after driver update
4. Try running Docker test:
   ```powershell
   docker run --rm --gpus all nvidia/cuda:12.4-runtime-ubuntu22.04 nvidia-smi
   ```

### "CUDA out of memory" error

1. Close other GPU-intensive applications
2. Use a lower memory profile (Profile 5)
3. Reduce video length/resolution
4. Use smaller models (1.3B instead of 14B)

### Container fails to build

1. Ensure you have enough disk space (50+ GB free)
2. Try cleaning Docker cache:
   ```powershell
   docker system prune -a
   ```
3. Rebuild with verbose output:
   ```powershell
   docker build --progress=plain -t wan2gp .
   ```

### Permission denied errors

Ensure Docker Desktop has access to your drives:
1. Docker Desktop → Settings → Resources → File Sharing
2. Add the drive where WanGP is installed

### Slow performance

1. Ensure WSL2 is using hardware virtualization
2. Allocate more memory to WSL2:
   Create/edit `%USERPROFILE%\.wslconfig`:
   ```ini
   [wsl2]
   memory=16GB
   processors=8
   ```
3. Restart WSL:
   ```powershell
   wsl --shutdown
   ```

### Audio not working (expected)

Audio is disabled in Docker containers by default. This is normal behavior.
The notification sounds will fallback to terminal beeps.

## Advanced Configuration

### Custom WSL2 Settings

Create `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=32GB           # Limit VM memory
processors=16         # Number of processors
swap=8GB             # Swap file size
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
```

### Environment Variables

Set these before running Docker:

```powershell
# Override CUDA architecture
$env:CUDA_ARCH = "8.9"

# Set memory profile
$env:WGP_PROFILE = "3"

# Change attention mode
$env:WGP_ATTENTION = "flash"

# Change port
$env:WGP_PORT = "8080"
```

### Building for Multiple Architectures

```powershell
docker build --build-arg CUDA_ARCHITECTURES="8.0;8.6;8.9" -t wan2gp-multi .
```

## Updating WanGP

```powershell
cd Wan2GP
git pull

# Rebuild the Docker image
docker-compose build
# Or
.\run-docker-cuda-win.ps1
```

## Uninstalling

1. Remove Docker containers and images:
   ```powershell
   docker-compose down
   docker rmi deepbeepmeep/wan2gp
   ```

2. Remove cached models (optional):
   ```powershell
   Remove-Item -Recurse -Force "$env:USERPROFILE\.cache\huggingface"
   ```

3. Remove WanGP directory:
   ```powershell
   Remove-Item -Recurse -Force .\Wan2GP
   ```

## Support

- **Discord**: https://discord.gg/g7efUW9jGV
- **GitHub Issues**: https://github.com/deepbeepmeep/Wan2GP/issues
- **Twitter/X**: https://x.com/deepbeepmeep

For Windows-specific Docker issues, also check:
- Docker Desktop documentation: https://docs.docker.com/desktop/windows/
- NVIDIA Container Toolkit: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/
