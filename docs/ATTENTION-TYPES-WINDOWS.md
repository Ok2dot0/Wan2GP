# Attention Types Installation Guide for Windows (Native venv)

This guide describes how to install each attention type on Windows using a native Python virtual environment (venv) installation.

## Overview

WanGP supports several attention implementations, each with different performance characteristics and GPU compatibility:

| Attention Type | Speed Boost | Quality | GPU Compatibility | Install Difficulty |
|---------------|-------------|---------|-------------------|-------------------|
| **SDPA** | Baseline | Best | All GPUs | None (built-in) |
| **Sage** | ~30% faster | Small cost | RTX 20XX+ | Easy |
| **Sage2** | ~40% faster | Minimal cost | RTX 30XX+ | Easy |
| **Flash** | ~30% faster | High | RTX 30XX+ | Medium |
| **xformers** | ~25% faster | Good, less VRAM | RTX 20XX+ | Medium |
| **Sage3** | >50% faster | May have trade-offs | RTX 30XX+ | Medium |

## Prerequisites

Before installing any attention type, ensure you have:

1. Completed the [Windows Native Installation](../README.md#-windows-native-installation-venv)
2. Activated your virtual environment:
   ```cmd
   cd Wan2GP
   venv\Scripts\activate
   ```
3. CUDA Toolkit installed (12.6+ recommended, 12.8 for RTX 40XX/50XX)
4. Build Tools for Visual Studio 2022 with C++ extensions

---

## SDPA (Scaled Dot-Product Attention)

**Status:** Built-in - No installation required

SDPA is the default attention mechanism included with PyTorch. It works on all GPUs without any additional installation.

### Usage
```bash
python wgp.py --attention sdpa
```

### GPU Compatibility
- ✅ GTX 10XX (Pascal)
- ✅ GTX 16XX (Turing)
- ✅ RTX 20XX (Turing)
- ✅ RTX Quadro
- ✅ RTX 30XX (Ampere)
- ✅ RTX 40XX (Ada Lovelace)
- ✅ RTX 50XX (Blackwell)

---

## Sage Attention (Version 1)

**Speed:** ~30% faster than SDPA  
**Quality:** Small quality cost  
**Best for:** RTX 20XX and RTX Quadro GPUs

### Installation for RTX 20XX / Quadro

First, install Triton:
```cmd
pip install -U "triton-windows<3.3"
```

Then install SageAttention 1.x:
```cmd
pip install sageattention==1.0.6
```

### Usage
```bash
python wgp.py --attention sage
```

### GPU Compatibility
- ❌ GTX 10XX
- ❌ GTX 16XX
- ✅ RTX 20XX
- ✅ RTX Quadro
- ✅ RTX 30XX (use Sage2 instead for better performance)
- ✅ RTX 40XX (use Sage2 instead for better performance)
- ✅ RTX 50XX (use Sage2 instead for better performance)

---

## Sage2 Attention (Version 2)

**Speed:** ~40% faster than SDPA  
**Quality:** Minimal quality cost  
**Best for:** RTX 30XX, 40XX, and 50XX GPUs

### Installation for RTX 30XX

First, install Triton:
```cmd
pip install -U "triton-windows<3.3"
```

Then install SageAttention 2.x (pre-compiled wheel):
```cmd
pip install https://github.com/woct0rdho/SageAttention/releases/download/v2.1.1-windows/sageattention-2.1.1+cu126torch2.6.0-cp310-cp310-win_amd64.whl
```

### Installation for RTX 40XX / 50XX

First, install Triton:
```cmd
pip install -U "triton-windows<3.4"
```

Then install SageAttention 2.x (pre-compiled wheel for CUDA 12.8):
```cmd
pip install https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu128torch2.7.1-cp310-cp310-win_amd64.whl
```

### Usage
```bash
python wgp.py --attention sage2
```

### GPU Compatibility
- ❌ GTX 10XX
- ❌ GTX 16XX
- ❌ RTX 20XX (use Sage instead)
- ✅ RTX 30XX
- ✅ RTX 40XX
- ✅ RTX 50XX

---

## Flash Attention

**Speed:** ~30% faster than SDPA  
**Quality:** High quality  
**Notes:** Can be complex to install on Windows

### Installation

Install from pre-compiled wheel:
```cmd
pip install https://github.com/Redtash1/Flash_Attention_2_Windows/releases/download/v2.7.0-v2.7.4/flash_attn-2.7.4.post1+cu128torch2.7.0cxx11abiFALSE-cp310-cp310-win_amd64.whl
```

> **Note:** This wheel is compiled for CUDA 12.8 and PyTorch 2.7.x. If you're using a different PyTorch version, you may need to find a compatible wheel or compile from source.

### Alternative: Build from Source

If the pre-compiled wheel doesn't work for your setup:

1. Ensure you have Visual Studio Build Tools 2022 with C++ extensions
2. Set up CUDA environment variables
3. Clone and build:
   ```cmd
   git clone https://github.com/Dao-AILab/flash-attention.git
   cd flash-attention
   pip install .
   ```

### Usage
```bash
python wgp.py --attention flash
```

### GPU Compatibility
- ❌ GTX 10XX
- ❌ GTX 16XX
- ❌ RTX 20XX
- ✅ RTX 30XX
- ✅ RTX 40XX
- ✅ RTX 50XX

---

## xformers

**Speed:** ~25% faster than SDPA  
**Quality:** Good quality, uses less VRAM  
**Notes:** Memory efficient attention implementation

### Installation

Install from PyPI:
```cmd
pip install xformers
```

For specific CUDA versions, you may need to install a compatible wheel. Check the [xformers releases](https://github.com/facebookresearch/xformers/releases) for pre-compiled Windows wheels.

### For RTX 30XX with CUDA 12.6:
```cmd
pip install xformers==0.0.28.post2 --index-url https://download.pytorch.org/whl/cu126
```

### For RTX 40XX/50XX with CUDA 12.8:
```cmd
pip install xformers==0.0.29 --index-url https://download.pytorch.org/whl/cu128
```

### Usage
```bash
python wgp.py --attention xformers
```

### GPU Compatibility
- ❌ GTX 10XX
- ❌ GTX 16XX
- ✅ RTX 20XX
- ✅ RTX 30XX
- ✅ RTX 40XX
- ✅ RTX 50XX

---

## Sage3 Attention (Experimental)

**Speed:** >50% faster than SDPA  
**Quality:** May have quality trade-offs  
**Notes:** Experimental, use with caution

### Installation

Sage3 is included with newer versions of SageAttention. Follow the Sage2 installation instructions for your GPU, ensuring you have the latest version:

For RTX 40XX / 50XX:
```cmd
pip install -U "triton-windows<3.4"
pip install https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu128torch2.7.1-cp310-cp310-win_amd64.whl
```

### Usage
```bash
python wgp.py --attention sage3
```

### GPU Compatibility
- ❌ GTX 10XX
- ❌ GTX 16XX
- ❌ RTX 20XX
- ✅ RTX 30XX
- ✅ RTX 40XX
- ✅ RTX 50XX

---

## Quick Reference by GPU

### GTX 10XX / 16XX (Pascal/Turing without RT cores)
```cmd
# No additional installation needed - only SDPA is supported
python wgp.py --attention sdpa
```

### RTX 20XX / Quadro (Turing)
```cmd
# Install Sage
pip install -U "triton-windows<3.3"
pip install sageattention==1.0.6

# Run with Sage
python wgp.py --attention sage
```

### RTX 30XX (Ampere)
```cmd
# Install Sage2 (recommended)
pip install -U "triton-windows<3.3"
pip install https://github.com/woct0rdho/SageAttention/releases/download/v2.1.1-windows/sageattention-2.1.1+cu126torch2.6.0-cp310-cp310-win_amd64.whl

# Run with Sage2
python wgp.py --attention sage2
```

### RTX 40XX / 50XX (Ada Lovelace/Blackwell)
```cmd
# Install Sage2 (recommended)
pip install -U "triton-windows<3.4"
pip install https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu128torch2.7.1-cp310-cp310-win_amd64.whl

# Run with Sage2
python wgp.py --attention sage2
```

---

## Troubleshooting

### Triton Installation Fails
- Ensure pip is up to date: `pip install --upgrade pip`
- Try a specific version: `pip install triton-windows==3.2.0`
- Fallback to SDPA: `python wgp.py --attention sdpa`

### SageAttention Not Working
1. Check if Triton is properly installed:
   ```python
   import triton
   print(triton.__version__)
   ```
2. Clear Triton cache:
   ```cmd
   rmdir /s %USERPROFILE%\.triton
   ```
3. Reinstall SageAttention
4. Fallback to SDPA: `python wgp.py --attention sdpa`

### Flash Attention Compilation Fails
- Flash attention often requires manual CUDA kernel compilation on Windows
- Ensure Visual Studio Build Tools are installed with C++ extensions
- Use pre-compiled wheels when available
- Fallback to Sage2 or SDPA

### xformers Import Errors
- Ensure the xformers version matches your PyTorch and CUDA versions
- Try reinstalling with the correct index URL for your CUDA version
- Check [xformers compatibility](https://github.com/facebookresearch/xformers#installing-xformers)

### General Issues
If all else fails, use the default SDPA attention which is always available:
```bash
python wgp.py --attention sdpa --profile 4
```

---

## Performance Recommendations

| GPU Generation | Recommended Attention | Alternative |
|---------------|----------------------|-------------|
| GTX 10XX | SDPA | - |
| GTX 16XX | SDPA | - |
| RTX 20XX | Sage | SDPA |
| RTX Quadro | Sage | SDPA |
| RTX 30XX | Sage2 | Flash, xformers |
| RTX 40XX | Sage2 | Flash, xformers |
| RTX 50XX | Sage2 | Flash, xformers |

---

## See Also

- [Installation Guide](INSTALLATION.md) - Complete setup instructions
- [CLI Reference](CLI.md) - All command line options
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
