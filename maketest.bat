@echo off
tools\vasm -nomsg=2050 -nomsg=2054 -nomsg=2052 -Fhunk -quiet -devpac -o test.o test.asm
if errorlevel 1 goto error
tools\vlink -S -s -o test test.o
if errorlevel 1 goto error
del test.o
:error
