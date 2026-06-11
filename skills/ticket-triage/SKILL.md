---
name: ticket-triage
description: Onderzoekt alle open Xurrent-tickets binnen de gekozen scope (ongeacht status). Status-, activiteits- en categoriegates bepalen per ticket of een (her)analyse zinvol is. Reconstrueert/diagnosticeert het probleem op de Odoo QA-database en in de lokale eeg-main code, raadpleegt de historiek van afgesloten tickets in de context-MCP, en plaatst een herkenbare interne notitie (🤖 AI-ticket-analyse). Her-triage alleen bij nieuwe menselijke activiteit gevolgd door 4 weken stilte; vervallen tickets krijgen altijd voorrang; max 3 volle QA-diagnoses per run. Lokale testversie; blauwdruk voor de latere ACA-Job op de VM.
---

# Ticket-triage agent v2 (lokale versie)

Voer onderstaande pijplijn uit. Argument `$ARGUMENTS` bepaalt de scope:
- leeg of `team` → alle medewerkers (teambreed)
- `mij` → enkel Louis-Philippe BOUCKAERT
- `<naam>` → die ene medewerker
- `#<id>` → één specifiek ticket-nummer

## Handle-conventie (idempotentie & herkenning)
Elke notitie die deze skill plaatst begint met exact deze regel:

`🤖 AI-ticket-analyse [v2 · <DATUM>]`

waarbij `<DATUM>` = de dag van uitvoering (YYYY-MM-DD).

Herkenning van **eigen eerdere notities**: substring `AI-ticket-analyse` óf de
legacy-marker `[AI-TRIAGE` (v1). Match op substring, niet op de exacte regel —
encoding-verschillen mogen de idempotentie niet breken.

## AI-notities van derden (Autokwalifier)
Op elk ticket reageert een andere AI-functionaliteit automatisch: notities die
beginnen met `🤖 Autokwalifier`. Deze notities:
- tellen **nooit** mee als menselijke activiteit (stap 3);
- worden inhoudelijk **genegeerd** bij de diagnose.

## Stap 1 — SCAN (Xurrent)
Zoek **alle open tickets** binnen de scope (status-filter `open` = alles wat niet
afgesloten is; één query per medewerker). Noteer per ticket: status, categorie
(incident/rfc/rfi/...), volgende target en toegewezen medewerker.
Gebruik een subagent voor de filtering om context te sparen.

## Stap 2 — STATUSGATE
| Status | Gedrag |
|---|---|
| toegewezen (`assigned`), geaccepteerd (`accepted`) | kandidaat **volle triage** |
| in behandeling (`in_progress`) | kandidaat **lichte triage**: enkel historiek-lookup + korte tip-notitie, géén QA-diagnose (de medewerker is er zelf mee bezig) |
| wachtend op... (`waiting_for`), wachtend op klant, afgehandeld (`completed`), geweigerd, gesloten/geannuleerd | **SKIP** — alleen vermelden in het eindrapport |

## Stap 3 — ACTIVITEITSGATE (her-triage)
Haal de notities op en filter alle bot-notities weg (eigen handles + Autokwalifier).
Beslis op wat overblijft (échte menselijke activiteit):
- **Geen eerdere eigen analyse** → behandelen.
- **Eigen analyse is de laatste relevante reactie** → SKIP, ongeacht hoe oud.
- **Menselijke reactie ná de eigen analyse** én de laatste activiteit op het ticket
  is **meer dan 4 weken (28 dagen) geleden** (= de update-doorlooptijd) → opnieuw
  behandelen.
- **Menselijke reactie ná de eigen analyse**, maar het ticket was de afgelopen
  4 weken nog actief → SKIP (er wordt aan gewerkt; de agent moet er niet tussen zitten).

## Stap 4 — PRIORITERING & BUDGET
- **Vervallen tickets** (volgende target < vandaag) krijgen **altijd voorrang**.
- Daarna de rest, oudste laatste-activiteit eerst.
- **Maximaal 3 volle QA-diagnoses per run.** Wat boven de cap valt → in het
  eindrapport als "wachtrij"; een volgende run pikt het vanzelf op.
  Lichte triages (geen QA-werk) tellen niet mee voor de cap.

## Stap 5 — HISTORIEK-LOOKUP (context-MCP)
Raadpleeg de afgesloten-ticket-historiek (`it-tickets-knowledge.md` als gateway,
`tickets/system-*.md` aggregaties, en relevante `tickets/by-id/<id>.md`).
Zoek gelijkaardige, reeds opgeloste tickets op basis van foutmelding/keywords/cluster.
Citeer gevonden ticket-IDs + de stappen die toen werkten.

## Stap 6 — CLASSIFICEER (bepaalt de diepte)
- `bug/incident (reproduceerbaar)` → **volle diagnose** (stap 7).
- `rfc/rfi`, `datakwestie`, `documentatie/overig` → **lichte analyse**:
  classificatie + historiek + advies, géén QA-reproductie (bespaart tokens/ruis).
- Status *in behandeling* (stap 2) → altijd licht, ongeacht categorie.

## Stap 7 — DIAGNOSE (enkel volle triage)
- **QA-healthcheck eerst** (gate): is `https://odoo-qa.eeg.be/` bereikbaar?
  - Niet bereikbaar → diagnose overslaan, ticket enkel signaleren, en waarschuwen.
- QA-connectie: vraag de DB-lijst dynamisch op (naam roteert maandelijks),
  kies de meest recente `backup_prod_*`. Credentials uit de lokale `config.py`.
- Reconstrueer het probleem op QA via XML-RPC (read-only waar mogelijk; test-writes
  enkel op QA en altijd herstellen). Verifieer kerncijfers/foutmeldingen zelf.
- Analyseer relevante modules in de lokale checkout van `eeg-main/custom`
  (negeer ` - kopie`-bestanden). Geen code- of datawijzigingen op productie.
- Gebruik subagents per ticket om context te sparen.

## Stap 8 — OUTPUT
Plaats een **interne notitie** (internal=true).

Volle triage:
1. de handle-regel
2. classificatie
3. diagnose + geverifieerde feiten (op QA gereconstrueerd)
4. verwijzing naar gelijkaardige historiek-tickets (stap 5)
5. concreet hersteladvies — **nooit zelf code/data wijzigen**

Lichte triage: handle-regel + classificatie + historiek-verwijzing + kort advies.
Houd lichte notities beknopt (max ± 10 regels).

## Tijdelijke scripts
QA-checkscripts in `_tmp_odoo_check/` (niet los op het bureaublad); einde run opruimen.

## Afsluiting
Geef een overzicht, gegroepeerd per medewerker:
- behandeld (vol / licht)
- overgeslagen, met reden: status-gate / eigen notitie laatste / recent actief / boven cap (wachtrij)
- gesignaleerd (QA onbereikbaar)

## Werkmodus-afwijking (bewust)
Deze skill is bedoeld om autonoom te draaien (cron op VM in fase 2). Bij een teambrede
run die notities plaatst op tickets van collega's: toon eerst één scope-overzicht en
vraag één go vóór de massale plaatsing (onomkeerbare, naar collega's zichtbare actie).
