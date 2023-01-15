@echo off

mkdir bin 1>NUL 2>NUL
v main.v -prod -cc tcc -o ".\bin\predictor.exe"
echo Compiled
