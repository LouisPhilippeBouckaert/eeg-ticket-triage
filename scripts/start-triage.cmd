@echo off
REM ============================================================
REM  Ticket-triage startscript (Windows).
REM  Pas de twee paden hieronder aan voor je eigen machine:
REM    - pad naar claude.exe
REM    - werkdirectory (waar de lokale eeg-main checkout staat)
REM  Permissions/auto-modus worden geladen uit triage-permissions.json
REM  (verwacht in dezelfde map als dit script; geladen via %~dp0).
REM ============================================================
title Ticket-Triage v2 - al mijn open tickets
cd /d "C:\Users\l.bouckaert\OneDrive - EEG NV\Bureaublad"
echo ================================================================
echo   TICKET-TRIAGE v2  -  al jouw open tickets, ongeacht status
echo   (vervallen eerst; status-/activiteitsgates beperken het werk)
echo ================================================================
echo.
echo Claude Code wordt nu ZELFSTANDIG gestart met: /ticket-triage mij
echo (auto-modus: scant, diagnosticeert en plaatst notities zonder te vragen)
echo Veiligheidsvangrails actief: geen ticketwijzigingen, enkel interne notities.
echo Sluit dit venster NIET tijdens het werk.
echo.
"C:\Users\l.bouckaert\.local\bin\claude.exe" --settings "%~dp0triage-permissions.json" "/ticket-triage mij"
echo.
echo ================================================================
echo   Triage afgelopen. Druk op een toets om dit venster te sluiten.
echo ================================================================
pause >nul
