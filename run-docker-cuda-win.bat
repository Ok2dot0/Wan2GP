@echo off
setlocal enabledelayedexpansion

REM ═══════════════════════════════════════════════════════════════════════════
REM WanGP Docker Launcher for Windows
REM ═══════════════════════════════════════════════════════════════════════════
REM This script builds and runs WanGP in a Docker container on Windows.
REM Requirements:
REM   - Docker Desktop with WSL2 backend
REM   - NVIDIA GPU with CUDA support
REM   - NVIDIA Container Toolkit (comes with Docker Desktop for Windows)
REM ═══════════════════════════════════════════════════════════════════════════

echo ═══════════════════════════════════════════════════════════════════════════
echo  WanGP Docker Launcher for Windows
echo ═══════════════════════════════════════════════════════════════════════════
echo.

REM Check if Docker is available
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not installed or not in PATH.
    echo Please install Docker Desktop for Windows from:
    echo   https://www.docker.com/products/docker-desktop/
    echo.
    echo Make sure to enable WSL2 backend during installation.
    pause
    exit /b 1
)

echo [OK] Docker is available

REM Check if nvidia-smi is available
nvidia-smi >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] NVIDIA drivers not found.
    echo Please install NVIDIA drivers from:
    echo   https://www.nvidia.com/Download/index.aspx
    pause
    exit /b 1
)

echo [OK] NVIDIA drivers are installed

REM Detect GPU information
echo.
echo Detecting GPU information...

REM Set default values
set "GPU_NAME=Unknown GPU"
set "VRAM_MB=0"
set "VRAM_GB=0"

REM Try to get GPU name using query-gpu (works on most versions)
for /f "tokens=*" %%i in ('nvidia-smi --query-gpu^=name --format^=csv 2^>nul ^| findstr /v /i "name"') do (
    set "GPU_NAME=%%i"
    goto :got_gpu
)
:got_gpu

REM Try to get VRAM using query-gpu
for /f "tokens=*" %%i in ('nvidia-smi --query-gpu^=memory.total --format^=csv 2^>nul ^| findstr /v /i "memory"') do (
    REM Extract numeric value (removes " MiB" suffix)
    for /f "tokens=1" %%j in ("%%i") do (
        set "VRAM_MB=%%j"
    )
    goto :got_vram
)
:got_vram

REM Calculate VRAM in GB
if !VRAM_MB! gtr 0 (
    set /a "VRAM_GB=!VRAM_MB! / 1024"
)

echo [INFO] Detected GPU: %GPU_NAME%
echo [INFO] VRAM: %VRAM_GB% GB

REM Detect CUDA architecture based on GPU name
set "CUDA_ARCH=8.6"

REM RTX 50XX series (Blackwell)
echo %GPU_NAME% | findstr /i "5090 5080 5070" >nul && set "CUDA_ARCH=12.0"
REM RTX 40XX series (Ada Lovelace)
echo %GPU_NAME% | findstr /i "4090 4080 4070 4060 RTX 40" >nul && set "CUDA_ARCH=8.9"
REM RTX 30XX series (Ampere)
echo %GPU_NAME% | findstr /i "3090 3080 3070 3060 RTX 30" >nul && set "CUDA_ARCH=8.6"
REM RTX 20XX series (Turing)
echo %GPU_NAME% | findstr /i "2080 2070 2060 RTX 20" >nul && set "CUDA_ARCH=7.5"
REM GTX 16XX series (Turing)
echo %GPU_NAME% | findstr /i "1660 1650 GTX 16" >nul && set "CUDA_ARCH=7.5"
REM GTX 10XX series (Pascal)
echo %GPU_NAME% | findstr /i "1080 1070 1060 GTX 10" >nul && set "CUDA_ARCH=6.1"
REM Data center GPUs
echo %GPU_NAME% | findstr /i "H100 H800" >nul && set "CUDA_ARCH=9.0"
echo %GPU_NAME% | findstr /i "A100 A800 A40" >nul && set "CUDA_ARCH=8.0"
echo %GPU_NAME% | findstr /i "V100" >nul && set "CUDA_ARCH=7.0"

echo [INFO] Using CUDA architecture: %CUDA_ARCH%

REM Determine profile based on GPU and VRAM
set "PROFILE=4"
if !VRAM_GB! geq 24 (
    set "PROFILE=3"
) else if !VRAM_GB! geq 12 (
    set "PROFILE=2"
) else if !VRAM_GB! geq 8 (
    set "PROFILE=4"
) else (
    set "PROFILE=5"
)

echo [INFO] Selected memory profile: %PROFILE%
echo.

REM Create cache directories if they don't exist
echo Creating cache directories...
if not exist "%USERPROFILE%\.cache\huggingface" mkdir "%USERPROFILE%\.cache\huggingface"
if not exist "%USERPROFILE%\.cache\torch" mkdir "%USERPROFILE%\.cache\torch"
if not exist "%USERPROFILE%\.cache\numba" mkdir "%USERPROFILE%\.cache\numba"
if not exist "%USERPROFILE%\.cache\matplotlib" mkdir "%USERPROFILE%\.cache\matplotlib"

REM Build the Docker image
echo.
echo ═══════════════════════════════════════════════════════════════════════════
echo Building Docker image (this may take a while on first run)...
echo ═══════════════════════════════════════════════════════════════════════════
echo.

docker build --build-arg CUDA_ARCHITECTURES="%CUDA_ARCH%" -t deepbeepmeep/wan2gp .
if %errorlevel% neq 0 (
    echo [ERROR] Docker build failed!
    pause
    exit /b 1
)

echo.
echo [OK] Docker image built successfully!
echo.

REM Check if container already exists
docker container inspect wan2gp >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Existing container found. Stopping and removing...
    docker stop wan2gp >nul 2>&1
    docker rm wan2gp >nul 2>&1
)

REM Create and run the container
echo ═══════════════════════════════════════════════════════════════════════════
echo Creating and starting WanGP container...
echo ═══════════════════════════════════════════════════════════════════════════
echo.
echo WanGP will be available at: http://localhost:7860
echo Press Ctrl+C to stop the container.
echo.
echo To restart the container later, use: docker start -ai wan2gp
echo.

docker create -it ^
    --name wan2gp ^
    --gpus all ^
    -p 7860:7860 ^
    -v "%CD%:/workspace" ^
    -v "%USERPROFILE%\.cache\huggingface:/home/user/.cache/huggingface" ^
    -v "%USERPROFILE%\.cache\torch:/home/user/.cache/torch" ^
    -v "%USERPROFILE%\.cache\numba:/home/user/.cache/numba" ^
    -v "%USERPROFILE%\.cache\matplotlib:/home/user/.cache/matplotlib" ^
    deepbeepmeep/wan2gp ^
    --profile %PROFILE% ^
    --attention sage ^
    --perc-reserved-mem-max 1

if %errorlevel% neq 0 (
    echo [ERROR] Failed to create container!
    pause
    exit /b 1
)

echo [OK] Container created successfully!
echo.

REM Start the container
docker start -ai wan2gp

echo.
echo WanGP container stopped.
echo To restart, use: docker start -ai wan2gp
pause
