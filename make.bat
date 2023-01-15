@echo off

mkdir bin 1>NUL 2>NUL
v main.v -prod -cc gcc -o ".\bin\predictor.exe"
echo Compiled
