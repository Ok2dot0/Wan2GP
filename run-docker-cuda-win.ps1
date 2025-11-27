#!/usr/bin/env pwsh
<#
.SYNOPSIS
    WanGP Docker Launcher for Windows (PowerShell)
.DESCRIPTION
    This script builds and runs WanGP in a Docker container on Windows.
    Requirements:
      - Docker Desktop with WSL2 backend
      - NVIDIA GPU with CUDA support
      - NVIDIA Container Toolkit (comes with Docker Desktop for Windows)
.EXAMPLE
    .\run-docker-cuda-win.ps1
    .\run-docker-cuda-win.ps1 -Profile 3 -Attention flash
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,5)]
    [int]$Profile = 0,  # 0 = auto-detect
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("sdpa", "sage", "flash")]
    [string]$Attention = "sage",
    
    [Parameter(Mandatory=$false)]
    [switch]$Compile,
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 7860,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoBuild
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " WanGP Docker Launcher for Windows (PowerShell)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is available
try {
    $null = docker --version
    Write-Host "[OK] Docker is available" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Docker is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Docker Desktop for Windows from:" -ForegroundColor Yellow
    Write-Host "  https://www.docker.com/products/docker-desktop/" -ForegroundColor White
    Write-Host ""
    Write-Host "Make sure to enable WSL2 backend during installation." -ForegroundColor Yellow
    exit 1
}

# Check if nvidia-smi is available
try {
    $null = nvidia-smi --version
    Write-Host "[OK] NVIDIA drivers are installed" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] NVIDIA drivers not found." -ForegroundColor Red
    Write-Host "Please install NVIDIA drivers from:" -ForegroundColor Yellow
    Write-Host "  https://www.nvidia.com/Download/index.aspx" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "Detecting GPU information..." -ForegroundColor Yellow

# Get GPU information
$gpuName = (nvidia-smi --query-gpu=name --format=csv,noheader,nounits | Select-Object -First 1).Trim()
$vramMB = [int](nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | Select-Object -First 1)
$vramGB = [math]::Floor($vramMB / 1024)

Write-Host "[INFO] Detected GPU: $gpuName" -ForegroundColor Cyan
Write-Host "[INFO] VRAM: ${vramGB} GB" -ForegroundColor Cyan

# Detect CUDA architecture based on GPU name
$cudaArch = "8.6"  # Default to Ampere

# Map GPU name to CUDA architecture
$archMap = @{
    "5090|5080|5070|RTX 50" = "12.0"  # Blackwell
    "H100|H800" = "9.0"               # Hopper
    "4090|4080|4070|4060|RTX 40" = "8.9"  # Ada Lovelace
    "3090|3080|3070|3060|RTX 30" = "8.6"  # Ampere consumer
    "A100|A800|A40" = "8.0"           # Ampere data center
    "2080|2070|2060|RTX 20|Titan RTX" = "7.5"  # Turing
    "1660|1650|GTX 16" = "7.5"        # Turing
    "V100" = "7.0"                    # Volta
    "1080|1070|1060|GTX 10" = "6.1"   # Pascal
}

foreach ($pattern in $archMap.Keys) {
    if ($gpuName -match $pattern) {
        $cudaArch = $archMap[$pattern]
        break
    }
}

Write-Host "[INFO] Using CUDA architecture: $cudaArch" -ForegroundColor Cyan

# Determine profile based on GPU and VRAM if not specified
if ($Profile -eq 0) {
    if ($vramGB -ge 24) {
        $Profile = 3  # LowRAM_HighVRAM
    } elseif ($vramGB -ge 12) {
        $Profile = 2  # HighRAM_LowVRAM
    } elseif ($vramGB -ge 8) {
        $Profile = 4  # LowRAM_LowVRAM
    } else {
        $Profile = 5  # VerylowRAM_LowVRAM
    }
}

Write-Host "[INFO] Selected memory profile: $Profile" -ForegroundColor Cyan
Write-Host ""

# Create cache directories if they don't exist
Write-Host "Creating cache directories..." -ForegroundColor Yellow
$cacheBase = "$env:USERPROFILE\.cache"
$cacheDirs = @("huggingface", "torch", "numba", "matplotlib")

foreach ($dir in $cacheDirs) {
    $fullPath = Join-Path $cacheBase $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "  Created: $fullPath" -ForegroundColor Gray
    }
}

# Build the Docker image
if (-not $NoBuild) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Building Docker image (this may take a while on first run)..." -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    docker build --build-arg CUDA_ARCHITECTURES="$cudaArch" -t deepbeepmeep/wan2gp .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Docker build failed!" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "[OK] Docker image built successfully!" -ForegroundColor Green
    Write-Host ""
}

# Prepare docker run arguments
$dockerArgs = @(
    "run", "--rm", "-it",
    "--name", "wan2gp",
    "--gpus", "all",
    "-p", "${Port}:7860",
    "-v", "${PWD}:/workspace",
    "-v", "$env:USERPROFILE\.cache\huggingface:/home/user/.cache/huggingface",
    "-v", "$env:USERPROFILE\.cache\torch:/home/user/.cache/torch",
    "-v", "$env:USERPROFILE\.cache\numba:/home/user/.cache/numba",
    "-v", "$env:USERPROFILE\.cache\matplotlib:/home/user/.cache/matplotlib"
)

# Add image name
$dockerArgs += "deepbeepmeep/wan2gp"

# Add WanGP arguments
$dockerArgs += "--profile", $Profile
$dockerArgs += "--attention", $Attention

if ($Compile) {
    $dockerArgs += "--compile"
}

$dockerArgs += "--perc-reserved-mem-max", "1"

# Run the container
Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Starting WanGP container..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "WanGP will be available at: http://localhost:$Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the container." -ForegroundColor Yellow
Write-Host ""

& docker $dockerArgs

Write-Host ""
Write-Host "WanGP container stopped." -ForegroundColor Yellow
