# eeg-ticket-triage

Een lokale [Claude Code](https://claude.com/claude-code)-agent die **alle open Xurrent-tickets** van een medewerker bewaakt — ongeacht status. Status-, activiteits- en categoriegates bepalen per ticket of een (her)analyse zinvol is. De agent reconstrueert het probleem op de Odoo **QA**-database, analyseert de lokale `eeg-main` broncode, raadpleegt de historiek van afgesloten tickets, en plaatst een **interne notitie** met de diagnose. Tickets met een **overschreden streeftijd** krijgen altijd voorrang.

> **Status:** lokale versie (v3), dagelijks gepland via Windows Taakplanner. Draait op een werkstation *binnen* het EEG-netwerk (QA + lokale code + MCP's vereist). De architectuur is opgezet als blauwdruk voor een latere onbemande **Azure Container Apps Job** - zie [`docs/architecture.md`](docs/architecture.md).

## Wat het doet

1. **Scan** - Xurrent: alle open tickets binnen de scope, ongeacht status.
2. **Statusgate** - toegewezen/geaccepteerd → volle triage; in behandeling → lichte triage (alleen historiek-tip, geen QA); wachtend op... / wachtend op klant / afgehandeld / geweigerd → overslaan.
3. **Nooit dubbel** - een ticket met een eigen AI-notitie (`AI-ticket-analyse`) of in het lokale register `behandeld.json` wordt overgeslagen. Geen automatische her-triage; opnieuw enkel op expliciete vraag: `/ticket-triage #<id>` of een eigen notitie met codewoord `#AI-herbekijk` op het ticket. Notities van de **Autokwalifier** tellen niet als activiteit.
4. **Prioritering & budget** - vervallen tickets (volgende target < vandaag) eerst; max **3 volle QA-diagnoses** per run, de rest schuift door naar de volgende run.
5. **Historiek-lookup** - zoekt gelijkaardige, reeds opgeloste tickets in de context-MCP (`tickets/by-id/*`).
6. **Classificatie** - bepaalt de diepte: `incident` (reproduceerbaar) → volle QA-diagnose; `rfc`/`rfi`/datakwestie/documentatie → lichte analyse.
7. **Diagnose + fix testen** - bekijkt bijlagen, reproduceert op QA (XML-RPC) + analyseert `eeg-main/custom`, en test een voorgestelde fix op QA. Elke test-write komt in `qa-restanten.md`.
8. **Notitie** - interne notitie met handle `🤖 AI-ticket-analyse [v3 · datum]`, classificatie, geverifieerde feiten, QA-test, historiek-verwijzing, voorstel + benodigde go en resume-regel. **Nooit wijzigingen op productie.** Daarna: ticket in `behandeld.json` + dagrapport `rapporten/<datum>.md` met open go's.

## Gebruik (lokaal)

Dubbelklik de bureaublad-snelkoppeling, of in een terminal:

```cmd
claude "/ticket-triage mij"
```

Scope-argument: `mij` (standaard) | `team` | `<naam>` | `#<id> [#<id> ...]` (batch, slaat de gates over).

### Gepland (dagelijks)

`scripts/run-scheduled.ps1` wordt door een Taakplanner-taak gestart met twee triggers: **bij aanmelden + 15 min** en **dagelijks 9u00** ("zo snel mogelijk na gemiste start"). Het script draait max. 1x per werkdag (`last-run.txt`), wacht tot QA bereikbaar is (max 30 min), start `claude -p "/ticket-triage mij --headless --sessie <uuid>"` en toont een Windows-melding. Logs in `logs/`. Manuele test: `run-scheduled.ps1 -Force -Scope "#<id>"`.

De snelkoppeling (`scripts/start-triage.cmd`) start Claude Code in **auto-modus** (`--settings scripts/triage-permissions.json`): de agent scant, diagnosticeert en plaatst notities **zelfstandig**, zonder per stap toestemming te vragen. De veiligheidsvangrails blijven actief - zie [Beveiliging](#beveiliging).

De gates maken de agent **dagelijks herhaalbaar**: een al behandeld ticket krijgt nooit automatisch een tweede notitie.

## Vereisten

- Claude Code CLI, ingelogd
- Uitvoering *binnen* het EEG-netwerk (QA `odoo-qa.eeg.be` bereikbaar)
- Lokale MCP-servers `xurrent` + `context` (Docker Desktop)
- Lokale checkout van `eeg-main` (custom Odoo-modules)
- QA-credentials via een lokale `config.py` - **niet in deze repo** (zie `scripts/conn.example.py`)

## Repo-structuur

| Pad | Inhoud |
|-----|--------|
| `skills/ticket-triage/SKILL.md` | De skill-definitie (de pijplijn) |
| `scripts/start-triage.cmd` | Windows-startscript voor de snelkoppeling |
| `scripts/run-scheduled.ps1` | Headless startscript voor de Taakplanner |
| `scripts/behandeld.example.json` | Formaat van het register van behandelde tickets |
| `scripts/triage-permissions.json` | Permissions voor de auto-modus (allow-lijst + deny-vangrails) |
| `scripts/conn.example.py` | Template QA-connectie (zonder secrets) |
| `docs/architecture.md` | Concept + fase-2 (ACA-Job) + governance |

## Installatie op een nieuwe machine

1. Plaats `skills/ticket-triage/SKILL.md` in `~/.claude/skills/ticket-triage/`.
2. Pas in `scripts/start-triage.cmd` de paden aan (claude.exe + werkdirectory). Zorg dat `triage-permissions.json` in **dezelfde map** als het script staat (het wordt relatief geladen via `%~dp0`).
3. Maak een lokale `config.py` op basis van `scripts/conn.example.py` met je QA-credentials.
4. Maak een bureaublad-snelkoppeling naar `start-triage.cmd`.

## Beveiliging

- **Geen secrets in deze repo.** QA-wachtwoord en Azure OpenAI-key horen in een lokale `config.py` / env-vars (zie `.gitignore`).
- De agent draait in **auto-modus** met een **allow-lijst** (enkel de tools die de triage nodig heeft) en **deny-vangrails**: het wijzigen of aanmaken van tickets is geblokkeerd - de agent mag uitsluitend een **interne notitie** plaatsen. Zie `scripts/triage-permissions.json`.
- De agent doet **geen** wijzigingen op productie; test-writes enkel op QA, geregistreerd in `qa-restanten.md` en waar mogelijk teruggedraaid.
- Notities zijn **intern** (onzichtbaar voor de aanvrager) en beperkt tot **één per ticket**, tenzij expliciet opnieuw gevraagd.
