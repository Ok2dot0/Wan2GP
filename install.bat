@echo off
setlocal enabledelayedexpansion

REM ===========================================================================
REM WanGP Windows Native Installation Script
REM ===========================================================================
REM This script installs WanGP natively on Windows using Python venv.
REM Requirements:
REM   - Python 3.10.9 (will be installed automatically if not present)
REM   - NVIDIA GPU with CUDA support
REM   - NVIDIA drivers installed
REM ===========================================================================

echo.
echo ===========================================================================
echo  WanGP Windows Native Installation Script
echo ===========================================================================
echo.

REM Python 3.10.9 installer configuration
set "PYTHON_INSTALLER_URL=https://www.python.org/ftp/python/3.10.9/python-3.10.9-amd64.exe"
set "PYTHON_INSTALLER=python-3.10.9-amd64.exe"

REM Check if Python 3.10 is available
set "PYTHON_EXE="
set "PYTHON_FOUND=0"

REM First, try to find Python 3.10 specifically using py launcher
py -3.10 --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_EXE=py -3.10"
    for /f "tokens=2" %%v in ('py -3.10 --version 2^>^&1') do set PYTHON_VERSION=%%v
    set "PYTHON_FOUND=1"
    goto :check_python_version
)

REM Try default python command and check if it's 3.10
python --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do set TEMP_VERSION=%%v
    for /f "tokens=1,2 delims=." %%a in ("!TEMP_VERSION!") do (
        if "%%a"=="3" if "%%b"=="10" (
            set "PYTHON_EXE=python"
            set "PYTHON_VERSION=!TEMP_VERSION!"
            set "PYTHON_FOUND=1"
            goto :check_python_version
        )
    )
)

:check_python_version
if "%PYTHON_FOUND%"=="1" (
    echo [INFO] Found Python %PYTHON_VERSION%
    
    REM Verify it's Python 3.10.x
    for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
        set PYTHON_MAJOR=%%a
        set PYTHON_MINOR=%%b
    )
    
    if "!PYTHON_MAJOR!"=="3" if "!PYTHON_MINOR!"=="10" (
        echo [OK] Python 3.10 is installed
        echo [INFO] Using Python command: %PYTHON_EXE%
        goto :python_ready
    )
)

REM Python 3.10 not found - need to install it
echo [INFO] Python 3.10 is not installed.
echo [INFO] WanGP requires Python 3.10.9 specifically for compatibility.
echo.
echo ===========================================================================
echo  Installing Python 3.10.9...
echo ===========================================================================
echo.

REM Check if installer already exists
if exist "%PYTHON_INSTALLER%" (
    echo [INFO] Python installer already downloaded.
) else (
    echo [INFO] Downloading Python 3.10.9 installer...
    echo [INFO] URL: %PYTHON_INSTALLER_URL%
    echo.
    
    REM Try PowerShell to download
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PYTHON_INSTALLER_URL%' -OutFile '%PYTHON_INSTALLER%'}" 2>nul
    
    if not exist "%PYTHON_INSTALLER%" (
        REM Try curl as fallback
        curl -L -o "%PYTHON_INSTALLER%" "%PYTHON_INSTALLER_URL%" 2>nul
    )
    
    if not exist "%PYTHON_INSTALLER%" (
        echo [ERROR] Failed to download Python installer!
        echo Please download Python 3.10.9 manually from:
        echo   %PYTHON_INSTALLER_URL%
        echo.
        echo Make sure to check "Add Python to PATH" during installation.
        pause
        exit /b 1
    )
    
    echo [OK] Python installer downloaded successfully!
)

echo.
echo [INFO] Installing Python 3.10.9...
echo [INFO] This will install Python with the following options:
echo        - Add Python to PATH
echo        - Install for all users
echo        - Include pip
echo.

REM Install Python silently with required options
"%PYTHON_INSTALLER%" /passive InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_launcher=1

if %errorlevel% neq 0 (
    echo [ERROR] Python installation failed!
    echo Please install Python 3.10.9 manually from:
    echo   %PYTHON_INSTALLER_URL%
    echo.
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

echo [OK] Python 3.10.9 installed successfully!
echo.

REM Update PATH for current session by reading from registry
echo [INFO] Refreshing environment variables...
set "SYSTEM_PATH="
set "USER_PATH="
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSTEM_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%b"

REM Build PATH carefully to avoid malformed entries
if defined SYSTEM_PATH (
    if defined USER_PATH (
        set "PATH=%SYSTEM_PATH%;%USER_PATH%"
    ) else (
        set "PATH=%SYSTEM_PATH%"
    )
) else if defined USER_PATH (
    set "PATH=%USER_PATH%"
)

REM Verify Python 3.10 is now available
set "PYTHON_EXE="
py -3.10 --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_EXE=py -3.10"
    for /f "tokens=2" %%v in ('py -3.10 --version 2^>^&1') do set PYTHON_VERSION=%%v
    goto :python_ready
)

REM Try the default install location
if exist "C:\Program Files\Python310\python.exe" (
    set "PYTHON_EXE=C:\Program Files\Python310\python.exe"
    for /f "tokens=2" %%v in ('"C:\Program Files\Python310\python.exe" --version 2^>^&1') do set PYTHON_VERSION=%%v
    goto :python_ready
)

echo [ERROR] Python 3.10 installation could not be verified.
echo Please restart your command prompt and run this script again.
echo If the issue persists, install Python 3.10.9 manually from:
echo   %PYTHON_INSTALLER_URL%
pause
exit /b 1

:python_ready
echo [INFO] Python %PYTHON_VERSION% is ready
echo.

REM Set major/minor for later use
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set PYTHON_MAJOR=%%a
    set PYTHON_MINOR=%%b
)

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
echo.

REM Detect GPU information
echo Detecting GPU information...

set "GPU_NAME=Unknown GPU"
set "VRAM_MB=0"

REM Try to get GPU name
for /f "tokens=*" %%i in ('nvidia-smi --query-gpu^=name --format^=csv 2^>nul ^| findstr /v /i "name"') do (
    set "GPU_NAME=%%i"
    goto :got_gpu
)
:got_gpu

REM Try to get VRAM
for /f "tokens=*" %%i in ('nvidia-smi --query-gpu^=memory.total --format^=csv 2^>nul ^| findstr /v /i "memory"') do (
    for /f "tokens=1" %%j in ("%%i") do (
        set "VRAM_MB=%%j"
    )
    goto :got_vram
)
:got_vram

REM Calculate VRAM in GB
if !VRAM_MB! gtr 0 (
    set /a "VRAM_GB=!VRAM_MB! / 1024"
) else (
    set "VRAM_GB=0"
)

echo [INFO] Detected GPU: %GPU_NAME%
echo [INFO] VRAM: %VRAM_GB% GB
echo.

REM Determine GPU generation and PyTorch version
set "PYTORCH_VERSION=2.6.0"
set "CUDA_VERSION=cu126"
set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu126"
set "GPU_GEN=30XX"
set "INSTALL_SAGE=0"
set "SAGE_VERSION="
set "INSTALL_TRITON=0"

REM RTX 50XX series (Blackwell)
echo %GPU_NAME% | findstr /i "5090 5080 5070 5060" >nul
if !errorlevel! equ 0 (
    set "GPU_GEN=50XX"
    set "PYTORCH_VERSION=2.7.1"
    set "CUDA_VERSION=cu128"
    set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu128"
    set "INSTALL_SAGE=1"
    set "SAGE_VERSION=https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu128torch2.7.1-cp310-cp310-win_amd64.whl"
    set "INSTALL_TRITON=1"
    set "TRITON_VERSION=triton-windows<3.4"
    goto :gpu_detected
)

REM RTX 40XX series (Ada Lovelace)
echo %GPU_NAME% | findstr /i "4090 4080 4070 4060 RTX 40" >nul
if !errorlevel! equ 0 (
    set "GPU_GEN=40XX"
    set "PYTORCH_VERSION=2.7.1"
    set "CUDA_VERSION=cu128"
    set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu128"
    set "INSTALL_SAGE=1"
    set "SAGE_VERSION=https://github.com/woct0rdho/SageAttention/releases/download/v2.2.0-windows/sageattention-2.2.0+cu128torch2.7.1-cp310-cp310-win_amd64.whl"
    set "INSTALL_TRITON=1"
    set "TRITON_VERSION=triton-windows<3.4"
    goto :gpu_detected
)

REM RTX 30XX series (Ampere)
echo %GPU_NAME% | findstr /i "3090 3080 3070 3060 RTX 30" >nul
if !errorlevel! equ 0 (
    set "GPU_GEN=30XX"
    set "PYTORCH_VERSION=2.6.0"
    set "CUDA_VERSION=cu126"
    set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu126"
    set "INSTALL_SAGE=1"
    set "SAGE_VERSION=https://github.com/woct0rdho/SageAttention/releases/download/v2.1.1-windows/sageattention-2.1.1+cu126torch2.6.0-cp310-cp310-win_amd64.whl"
    set "INSTALL_TRITON=1"
    set "TRITON_VERSION=triton-windows<3.3"
    goto :gpu_detected
)

REM RTX 20XX series (Turing)
echo %GPU_NAME% | findstr /i "2080 2070 2060 RTX 20 Titan RTX" >nul
if !errorlevel! equ 0 (
    set "GPU_GEN=20XX"
    set "PYTORCH_VERSION=2.6.0"
    set "CUDA_VERSION=cu126"
    set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu126"
    set "INSTALL_SAGE=1"
    set "SAGE_VERSION=sageattention==1.0.6"
    set "INSTALL_TRITON=1"
    set "TRITON_VERSION=triton-windows<3.3"
    goto :gpu_detected
)

REM GTX 16XX series (Turing)
echo %GPU_NAME% | findstr /i "1660 1650 GTX 16" >nul
if !errorlevel! equ 0 (
    set "GPU_GEN=16XX"
    set "PYTORCH_VERSION=2.6.0"
    set "CUDA_VERSION=cu126"
    set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu126"
    set "INSTALL_SAGE=0"
    set "INSTALL_TRITON=0"
    goto :gpu_detected
)

REM GTX 10XX series (Pascal)
echo %GPU_NAME% | findstr /i "1080 1070 1060 GTX 10" >nul
if !errorlevel! equ 0 (
    set "GPU_GEN=10XX"
    set "PYTORCH_VERSION=2.6.0"
    set "CUDA_VERSION=cu126"
    set "PYTORCH_INDEX=https://download.pytorch.org/whl/cu126"
    set "INSTALL_SAGE=0"
    set "INSTALL_TRITON=0"
    goto :gpu_detected
)

REM Default to RTX 30XX settings if unknown
echo [WARNING] GPU not recognized: %GPU_NAME%
echo           Using default RTX 30XX settings.

:gpu_detected
echo.
echo [INFO] GPU Generation: %GPU_GEN%
echo [INFO] PyTorch Version: %PYTORCH_VERSION%
echo [INFO] CUDA Version: %CUDA_VERSION%
echo.

REM Check if venv already exists
if exist "venv" (
    echo [INFO] Virtual environment already exists.
    echo        Delete the 'venv' folder to reinstall from scratch.
    echo.
    set /p CHOICE="Do you want to continue and update the installation? (y/N): "
    if /i not "!CHOICE!"=="y" (
        echo Installation cancelled.
        pause
        exit /b 0
    )
    goto :activate_venv
)

REM Create virtual environment
echo ===========================================================================
echo Creating virtual environment with Python %PYTHON_VERSION%...
echo ===========================================================================
echo.

%PYTHON_EXE% -m venv venv
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create virtual environment!
    pause
    exit /b 1
)

REM Verify venv was created with correct Python version
if not exist "venv\Scripts\python.exe" (
    echo [ERROR] Virtual environment creation failed - python.exe not found!
    pause
    exit /b 1
)

for /f "tokens=2" %%v in ('venv\Scripts\python.exe --version 2^>^&1') do set VENV_PYTHON_VERSION=%%v
echo [INFO] Virtual environment Python version: %VENV_PYTHON_VERSION%

REM Extract major.minor from venv Python version for comparison
for /f "tokens=1,2 delims=." %%a in ("%VENV_PYTHON_VERSION%") do (
    set VENV_PYTHON_MAJOR=%%a
    set VENV_PYTHON_MINOR=%%b
)

if not "%VENV_PYTHON_MAJOR%.%VENV_PYTHON_MINOR%"=="%PYTHON_MAJOR%.%PYTHON_MINOR%" (
    echo [WARNING] Virtual environment Python version differs from expected!
    echo           Expected: %PYTHON_MAJOR%.%PYTHON_MINOR%.x, Got: %VENV_PYTHON_VERSION%
)

echo [OK] Virtual environment created successfully!
echo.

:activate_venv
REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat
if %errorlevel% neq 0 (
    echo [ERROR] Failed to activate virtual environment!
    pause
    exit /b 1
)

echo [OK] Virtual environment activated
echo.

REM Upgrade pip
echo ===========================================================================
echo Upgrading pip...
echo ===========================================================================
echo.
python -m pip install --upgrade pip
echo.

REM Install PyTorch
echo ===========================================================================
echo Installing PyTorch %PYTORCH_VERSION% with CUDA %CUDA_VERSION%...
echo ===========================================================================
echo.

if "%CUDA_VERSION%"=="cu128" (
    pip install torch==%PYTORCH_VERSION% torchvision torchaudio --index-url %PYTORCH_INDEX%
) else (
    pip install torch==%PYTORCH_VERSION%+%CUDA_VERSION% torchvision torchaudio --index-url %PYTORCH_INDEX%
)

if %errorlevel% neq 0 (
    echo [ERROR] Failed to install PyTorch!
    pause
    exit /b 1
)

echo [OK] PyTorch installed successfully!
echo.

REM Install Triton if needed
if "%INSTALL_TRITON%"=="1" (
    echo ===========================================================================
    echo Installing Triton...
    echo ===========================================================================
    echo.
    pip install -U %TRITON_VERSION%
    if !errorlevel! neq 0 (
        echo [WARNING] Failed to install Triton. Continuing without it...
    ) else (
        echo [OK] Triton installed successfully!
    )
    echo.
)

REM Install SageAttention if needed
if "%INSTALL_SAGE%"=="1" (
    echo ===========================================================================
    echo Installing SageAttention...
    echo ===========================================================================
    echo.
    pip install %SAGE_VERSION%
    if !errorlevel! neq 0 (
        echo [WARNING] Failed to install SageAttention. You can use SDPA attention instead.
    ) else (
        echo [OK] SageAttention installed successfully!
    )
    echo.
)

REM Install requirements
echo ===========================================================================
echo Installing requirements...
echo ===========================================================================
echo.
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install requirements!
    pause
    exit /b 1
)

echo [OK] Requirements installed successfully!
echo.

REM Installation complete
echo ===========================================================================
echo  Installation Complete!
echo ===========================================================================
echo.
echo To run WanGP:
echo   1. Double-click 'run.bat' in this folder
echo   - OR -
echo   2. Open a terminal and run:
echo      venv\Scripts\activate
echo      python wgp.py
echo.
echo WanGP will be available at: http://localhost:7860
echo.
if "%INSTALL_SAGE%"=="1" (
    echo [INFO] SageAttention: Installed
) else (
    echo [INFO] SageAttention: Not available for your GPU ^(using SDPA^)
)
echo.
pause
