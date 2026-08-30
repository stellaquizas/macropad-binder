@echo off
cd /d "%~dp0"
py -3 -m pip install -r requirements.txt
py -3 -m macropad_binder
if errorlevel 1 (
  python -m pip install -r requirements.txt
  python -m macropad_binder
)
pause
