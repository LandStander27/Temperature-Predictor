@echo off

mkdir bin 1>NUL 2>NUL
v predict.v -prod -cc tcc -o ".\bin\predictor.exe"
echo Compiled
