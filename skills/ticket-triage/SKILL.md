---
name: ticket-triage
description: Onderzoekt teambrede Xurrent-tickets met een overschreden streeftijd (volgende target < vandaag), reconstrueert/diagnosticeert het probleem op de Odoo QA-database en in de lokale eeg-main code, raadpleegt de historiek van afgesloten tickets in de context-MCP voor gelijkaardige opgeloste gevallen, en plaatst een herkenbare interne notitie. Idempotent via een AI-TRIAGE-marker zodat een ticket niet twee keer behandeld wordt. Lokale testversie; blauwdruk voor de latere ACA-Job op de VM.
---

# Ticket-triage agent (lokale versie)

Voer onderstaande pijplijn uit. Argument `$ARGUMENTS` bepaalt de scope:
- leeg of `team` -> alle medewerkers (teambreed)
- `mij` -> enkel Louis-Philippe BOUCKAERT
- `<naam>` -> die ene medewerker
- `#<id>` -> een specifiek ticket-nummer

## Marker-conventie (idempotentie)
Elke notitie die deze skill plaatst begint met exact deze regel:

`[AI-TRIAGE v1 . <DATUM>] - automatische diagnose`

waarbij `<DATUM>` = de dag van uitvoering (YYYY-MM-DD).

## Stap 1 - SCAN (Xurrent)
Zoek tickets met status `assigned` en `waiting_for`. Filter op `Volgende target` < vandaag.
Bepaal per ticket de toegewezen medewerker. Pas de scope toe (zie argument).
Gebruik een subagent voor de target-datum-filtering om context te sparen.

## Stap 2 - IDEMPOTENTIE-GATE
Haal voor elk kandidaat-ticket de notities op. Zoek naar de string `[AI-TRIAGE`.
- Marker aanwezig -> ticket is al behandeld -> SKIP (rapporteer als overgeslagen).
- Geen marker -> behandelen.
Een keer checken: een ticket met marker wordt nooit opnieuw gediagnosticeerd.

## Stap 3 - HISTORIEK-LOOKUP (context-MCP)
Raadpleeg de afgesloten-ticket-historiek (`it-tickets-knowledge.md` als gateway,
`tickets/system-*.md` aggregaties, en relevante `tickets/by-id/<id>.md`).
Zoek gelijkaardige, reeds opgeloste tickets op basis van foutmelding/keywords/cluster.
Citeer gevonden ticket-IDs + de stappen die toen werkten.

## Stap 4 - CLASSIFICEER
`bug (reproduceerbaar)` | `datakwestie` | `documentatie/overig`.

## Stap 5 - DIAGNOSE
- **QA-healthcheck eerst** (gate): is `https://odoo-qa.eeg.be/` bereikbaar?
  - Niet bereikbaar -> diagnose overslaan, ticket enkel signaleren, en waarschuwen.
- QA-connectie: vraag de DB-lijst dynamisch op (naam roteert maandelijks),
  kies de meest recente `backup_prod_*`. Credentials uit de lokale `config.py`.
- Reconstrueer het probleem op QA via XML-RPC (read-only waar mogelijk; test-writes
  enkel op QA en altijd herstellen). Verifieer kerncijfers/foutmeldingen zelf.
- Analyseer relevante modules in de lokale checkout van `eeg-main/custom`
  (negeer ` - kopie`-bestanden). Geen code- of datawijzigingen op productie.
- Gebruik subagents per ticket om context te sparen.

## Stap 6 - OUTPUT
Plaats een **interne notitie** (internal=true) met:
1. de marker-regel
2. classificatie
3. diagnose + geverifieerde feiten (op QA gereconstrueerd)
4. verwijzing naar gelijkaardige historiek-tickets (stap 3)
5. concreet hersteladvies - **nooit zelf code/data wijzigen**

## Tijdelijke scripts
QA-checkscripts in `_tmp_odoo_check/` (niet los op het bureaublad); einde run opruimen.

## Afsluiting
Geef een overzicht: behandeld / overgeslagen (marker) / gesignaleerd (QA onbereikbaar),
gegroepeerd per medewerker.

## Werkmodus-afwijking (bewust)
Deze skill is bedoeld om autonoom te draaien (cron op VM in fase 2). Bij een teambrede
run die notities plaatst op tickets van collega's: toon eerst een scope-overzicht en
vraag een go voor de massale plaatsing (onomkeerbare, naar collega's zichtbare actie).
