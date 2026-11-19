@echo off
rem Descarrega as ruas (OpenStreetMap) e as areas atuais (goMAP) para a pasta dados. Nao fica nada a correr.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0extrair.ps1" %*
pause
