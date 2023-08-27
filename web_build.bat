@echo off
if not exist build_web mkdir build_web

robocopy .\wasm_stuff .\build_web /s > nul

odin build src\platform_wasm -out:build_web\index.wasm -target:js_wasm32