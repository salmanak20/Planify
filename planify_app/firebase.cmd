@echo off
setlocal
set "NPX_CMD=%ProgramFiles%\nodejs\npx.cmd"

if exist "%NPX_CMD%" (
  call "%NPX_CMD%" firebase-tools %*
) else (
  npx firebase-tools %*
)
