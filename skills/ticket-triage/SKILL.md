---
name: ticket-triage
description: Onderzoekt open Xurrent-tickets binnen de gekozen scope (of een batch ticket-ID's). Een ticket dat al een AI-analyse kreeg wordt nooit opnieuw bekeken, tenzij LP het expliciet vraagt (`#id` of codewoord `#AI-herbekijk` op het ticket). Reconstrueert/diagnosticeert het probleem op de Odoo QA-database en in de lokale eeg-main code, test een voorgestelde fix op QA (nooit prod), bekijkt bijlagen, raadpleegt de historiek in de context-MCP en plaatst een herkenbare interne notitie (🤖 AI-ticket-analyse). Houdt een register van behandelde tickets, QA-restanten en een dagrapport met open go's bij. Max 3 volle QA-diagnoses per run. Draait dagelijks via Taakplanner (run-scheduled.ps1) of manueel.
---

# Ticket-triage agent v3

Voer onderstaande pijplijn uit. Argument `$ARGUMENTS` bepaalt de scope:
- leeg of `mij` → enkel Louis-Philippe BOUCKAERT (standaard)
- `team` → alle medewerkers (teambreed)
- `<naam>` → die ene medewerker
- `#<id> [#<id> ...]` → **batch**: precies die tickets (expliciete vraag van LP)

Extra vlaggen (gezet door `run-scheduled.ps1`):
- `--headless` → er is niemand om vragen aan te stellen. Nooit wachten op input:
  twijfel = open punt in het dagrapport, niet gokken.
- `--sessie <uuid>` → sessie-ID van deze run (voor de resume-regel in de notitie).
  Zonder vlag: resume-regel weglaten tenzij het sessie-ID bekend is.

## Bestanden (werkmap `~/.claude/ticket-triage/`)
| Bestand | Doel |
|---|---|
| `behandeld.json` | register van behandelde tickets: `{"tickets": {"<id>": {"datum": "YYYY-MM-DD", "sessie": "<uuid>", "bron": "triage"}}}` |
| `qa-restanten.md` | elke test-write op QA (ticket, model, ids, opgeruimd ja/nee) |
| `rapporten/<datum>.md` | dagrapport (zie Afsluiting) |
| `logs/` | ruwe output van geplande runs (door het script) |

## Handle-conventie (herkenning)
Elke notitie die deze skill plaatst begint met exact deze regel:

`🤖 AI-ticket-analyse [v3 · <DATUM>]`

waarbij `<DATUM>` = de dag van uitvoering (YYYY-MM-DD).

Herkenning van **eigen eerdere notities**: substring `AI-ticket-analyse` óf de
legacy-marker `[AI-TRIAGE` (v1). Match op substring, niet op de exacte regel —
encoding-verschillen mogen de herkenning niet breken. Dit geldt ook voor
analyses uit manuele Claude-sessies (die gebruiken hetzelfde label).

## AI-notities van derden (Autokwalifier)
Notities die beginnen met `🤖 Autokwalifier`:
- tellen **nooit** mee als menselijke activiteit;
- worden inhoudelijk **genegeerd** bij de diagnose.

## Stap 1 — SCAN (Xurrent)
Bij een batch (`#id`): sla de scan over en ga met precies die tickets naar stap 5.

Anders: zoek alle open tickets binnen de scope. De `open`-metafilter en de
`member_name`-filter van `xurrent_search_requests` zijn stuk (GraphQL-fouten) →
**per status apart bevragen** en zelf op medewerker filteren. Niet-afgesloten
statussen: `assigned`, `accepted`, `in_progress`, `waiting_for`,
`waiting_for_customer`, `workflow_pending`, `project_pending`,
`reservation_pending`, `on_backlog`. De tool toont max 100 resultaten: bij
"X gevonden (toon 100)" met X>100 **pagineren** via `created_after`/`created_before`.
Noteer per ticket: status, categorie, volgende target, toegewezen medewerker.
Gebruik een subagent voor de filtering om context te sparen.

## Stap 2 — STATUSGATE
| Status | Gedrag |
|---|---|
| `assigned`, `accepted` | kandidaat **volle triage** |
| `in_progress` | kandidaat **lichte triage**: historiek + korte tip-notitie, géén QA-diagnose |
| `waiting_for`, `waiting_for_customer`, `*_pending`, `on_backlog` | **SKIP** — alleen vermelden in het rapport |

## Stap 3 — NOOIT DUBBEL (al-behandeld-gate)
Een ticket wordt **overgeslagen** zodra één van beide checks raak is:
1. er staat een eigen AI-notitie op het ticket (handle-herkenning hierboven);
2. het ticket-ID staat in `behandeld.json`.

Er is **geen automatische her-triage** meer (ook niet na weken stilte).
Enige uitzonderingen — LP vraagt het expliciet:
- **batch-argument** `#<id>` (rechtstreeks aan Claude) → gates 2 en 3 vervallen;
- **codewoord op het ticket**: een notitie van Louis-Philippe BOUCKAERT, zónder
  AI-handle, met `#AI-herbekijk` (hoofdletterongevoelig), geplaatst **ná** de
  laatste eigen AI-notitie → opnieuw behandelen, ongeacht status-gate.
  De tekst bij het codewoord is de vraag/focus van de nieuwe analyse.
  Na de nieuwe notitie is het codewoord "verbruikt" (de AI-notitie staat er nu ná).

## Stap 4 — PRIORITERING & BUDGET
- Codewoord-tickets eerst, dan **vervallen tickets** (volgende target < vandaag),
  daarna de rest, oudste laatste-activiteit eerst.
- **Maximaal 3 volle QA-diagnoses per run** (batch: geen cap, wel melden als >3).
  Wat boven de cap valt → "wachtrij" in het rapport; de volgende run pikt het op
  (het staat nog niet in het register). Lichte triages tellen niet mee.

## Stap 5 — CONTEXT VERZAMELEN
- **Alle notities** ophalen (bij waarschuwing over afkapping: de rest ophalen —
  de recentste notities bepalen de actuele stand).
- **Bijlagen** (volle triage): `xurrent_get_request_attachments`, downloaden via
  `download_url` naar `_tmp_odoo_check/<ticket>/` en bekijken (screenshots, Excel;
  `.msg` recursief uitpakken).
- **Historiek** (context-MCP): `it-tickets-knowledge.md` als gateway,
  `tickets/system-*.md`; zoek gelijkaardige opgeloste tickets op
  foutmelding/keywords/cluster en citeer de ID's + wat toen werkte.
- **Projectgeheugen**: zoek het ticket-ID in de memory-map
  (`~/.claude/projects/*/memory/`) voor eerdere context.

## Stap 6 — CLASSIFICEER (bepaalt de diepte)
- `bug/incident (reproduceerbaar)` → **volle diagnose** (stap 7).
- `rfc/rfi`, `datakwestie`, `documentatie/overig` → **lichte analyse**:
  classificatie + historiek + advies. Bij een rfc/datakwestie waar een concrete
  QA-test het advies veel sterker maakt (zoals config- of datafix), mag het als
  volle triage tellen (telt dan mee voor de cap).
- `in_progress` → altijd licht.

## Stap 7 — DIAGNOSE + FIX TESTEN OP QA (enkel volle triage)
- **QA-healthcheck eerst**: is `https://odoo-qa.eeg.be/` bereikbaar?
  Niet bereikbaar → diagnose overslaan, ticket signaleren, niet in register zetten.
- QA-connectie: DB-lijst dynamisch opvragen (naam roteert), meest recente
  `backup_prod_*` kiezen. Credentials uit
  een lokale `config.py` (zie `scripts/conn.example.py`).
  **Nooit** een module importeren die ook prod-connecties bevat (bv. `prod.py`
  en QA-scripts delen een `qa`-module → per ongeluk prod lezen).
- Reconstrueer het probleem op QA via XML-RPC; verifieer kerncijfers/foutmeldingen zelf.
- Analyseer relevante modules in
  de lokale checkout van `eeg-main/custom`
  (negeer ` - kopie`-bestanden).
- **Fix testen**: een voorgestelde fix (configuratie, automatisatie, view zonder
  xml-id, datafix, groep/menu) mag op QA uitgevoerd en getest worden. Regels:
  - **nooit iets op productie** schrijven — geen code, geen data, geen config;
  - geen creates die niet terug te draaien zijn (uid 5520 heeft geen unlink op
    `account.account`; creates in GROUP delegeren naar 13 bedrijven);
  - nieuwe automatisaties op QA **inactief** achterlaten na de test, met
    `[QA-TEST <ticket>]` in de naam;
  - **elke** test-write meteen registreren in `qa-restanten.md`;
  - terugdraaien waar dat kan zonder het testbewijs te verliezen, en dat in
    het register aanvinken.
- Gebruik subagents per ticket om context te sparen; subagents leveren hun
  rapport via hand-back af.

## Stap 8 — OUTPUT (interne notitie, internal=true)
Volle triage:
1. de handle-regel
2. classificatie
3. bevinding + geverifieerde feiten (op QA gereconstrueerd)
4. **getest op QA**: wat, resultaat, record-id's (zodat LP zelf kan nakijken)
5. verwijzing naar gelijkaardige historiek-tickets
6. concreet voorstel, met wat een **go** van LP vraagt (prod-actie, CR Somko, …)
7. resume-regel (als sessie-ID bekend):
   ``Resume this AI session with: `claude --resume <uuid>` ``
   `Uitvoeren vanuit: <werkdirectory>`

Lichte triage: handle-regel + classificatie + historiek + kort advies (± 10 regels).

**Direct na het posten**: ticket-ID toevoegen aan `behandeld.json`
(datum, sessie, bron `triage`). Een ticket waarvoor géén notitie geplaatst werd
(skip, wachtrij, QA onbereikbaar) komt **niet** in het register.

## Tijdelijke scripts
QA-checkscripts en bijlagen in `_tmp_odoo_check/`; einde run de scripts en
downloads van deze run opruimen (het QA-restantenregister blijft).

## Afsluiting — dagrapport `rapporten/<datum>.md`
(Bij meerdere runs op één dag: aanvullen onder een nieuwe kop met het uur.)
1. **Behandeld** (vol / licht): ticket, titel, aanvrager, 1 zin bevinding.
2. **Open go's voor LP**: per ticket de concrete beslissing/actie die LP moet
   geven (prod-write, CR, antwoord aan aanvrager, …).
3. **Nieuwe QA-restanten** van deze run.
4. **Overgeslagen**, met reden: status-gate / al behandeld / boven cap (wachtrij).
5. **Gesignaleerd**: QA onbereikbaar, fouten, open vragen (headless twijfels).

Geef dezelfde samenvatting kort als eindantwoord (het script toont het aantal
notities in een melding).

## Werkmodus-afwijking (bewust)
Deze skill draait autonoom (Taakplanner). Interne notities op **eigen** tickets
mogen zonder bijkomende go. Bij een teambrede run die notities plaatst op
tickets van collega's: eerst één scope-overzicht en één go vóór de plaatsing —
in `--headless` modus dus **geen** notities op tickets van collega's, enkel rapporteren.
