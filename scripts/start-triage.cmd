@echo off
REM ============================================================
REM  Ticket-triage startscript (Windows).
REM  Pas de twee paden hieronder aan voor je eigen machine:
REM    - pad naar claude.exe
REM    - werkdirectory (waar de lokale eeg-main checkout staat)
REM ============================================================
title Ticket-Triage - mijn openstaande tickets
cd /d "C:\Users\l.bouckaert\OneDrive - EEG NV\Bureaublad"
echo ================================================================
echo   TICKET-TRIAGE  -  jouw openstaande tickets met overschreden
echo   streeftijd   (scan + QA-diagnose + interne notitie)
echo ================================================================
echo.
echo Claude Code wordt nu interactief gestart met: /ticket-triage mij
echo Volg de stappen en keur acties (QA / notitie) goed waar gevraagd.
echo Sluit dit venster NIET tijdens het werk.
echo.
"C:\Users\l.bouckaert\.local\bin\claude.exe" "/ticket-triage mij"
echo.
echo ================================================================
echo   Triage afgelopen. Druk op een toets om dit venster te sluiten.
echo ================================================================
pause >nul
