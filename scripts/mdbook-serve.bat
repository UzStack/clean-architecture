@echo off
setlocal
cargo install mdbook --locked
cd /d "%~dp0..\book"
mdbook serve -p 3000 -n 127.0.0.1 -o
endlocal
