@echo off
"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in "summon_heroes_trainer.ahk" /out "summon_heroes_trainer.exe"
if %errorlevel% equ 0 (
    echo Build successful: summon_heroes_trainer.exe
) else (
    echo Build failed.
)
pause
