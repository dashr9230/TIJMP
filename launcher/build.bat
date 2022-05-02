@echo off
cls
setlocal ENABLEEXTENSIONS
set REG_KEY="HKEY_CLASSES_ROOT\AutoIt3Script\Shell\Compile\Command"
for /F "usebackq eol=; tokens=3,4*" %%A IN (`reg query %REG_KEY%`) DO set Aut2Exe=%%A
if defined Aut2Exe (
	%Aut2Exe% /in "launcher.au3" /out "tijmp.exe" /icon "1.ico" /nopack /x86 /gui
) else (
	@echo Failed to locate Aut2Exe.exe
	pause>nul
)