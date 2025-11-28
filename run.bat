@echo off
setlocal enabledelayedexpansion

REM ===========================================================================
REM WanGP Windows Run Script
REM ===========================================================================
REM This script runs WanGP using the virtual environment created by install.bat
REM ===========================================================================

echo.
echo ===========================================================================
echo  WanGP - Starting Application
echo ===========================================================================
echo.

REM Check if venv exists
if not exist "venv\Scripts\activate.bat" (
    echo [ERROR] Virtual environment not found!
    echo         Please run 'install.bat' first to set up WanGP.
    echo.
    pause
    exit /b 1
)

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

REM Check for command line arguments or use defaults
set "ARGS=%*"
if "%ARGS%"=="" (
    REM Auto-detect optimal settings
    set "ATTENTION=sdpa"
    
    REM Check for SageAttention availability using pip
    REM First check if package is installed
    pip show sageattention >nul 2>&1
    if !errorlevel! equ 0 (
        REM Check if this is SageAttention 2.x (supports sage2)
        for /f "tokens=2" %%v in ('pip show sageattention ^| findstr /i "Version"') do (
            echo %%v | findstr /b "2\." >nul
            if !errorlevel! equ 0 (
                set "ATTENTION=sage2"
            ) else (
                set "ATTENTION=sage"
            )
        )
    )
    
    set "ARGS=--attention !ATTENTION!"
)

echo ===========================================================================
echo  Starting WanGP...
echo  Args: %ARGS%
echo ===========================================================================
echo.
echo WanGP will be available at: http://localhost:7860
echo Press Ctrl+C to stop the application.
echo.

REM Run WanGP
python wgp.py %ARGS%

echo.
echo WanGP stopped.
pause
