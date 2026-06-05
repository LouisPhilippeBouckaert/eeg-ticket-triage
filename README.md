# eeg-ticket-triage

Een lokale [Claude Code](https://claude.com/claude-code)-agent die **Xurrent-tickets met een overschreden streeftijd** automatisch onderzoekt: hij reconstrueert het probleem op de Odoo **QA**-database, analyseert de lokale `eeg-main` broncode, raadpleegt de historiek van afgesloten tickets, en plaatst een **interne notitie** met de diagnose.

> **Status:** lokale testversie. Draait op een werkstation *binnen* het EEG-netwerk (QA + lokale code + MCP's vereist). De architectuur is opgezet als blauwdruk voor een latere onbemande **Azure Container Apps Job** - zie [`docs/architecture.md`](docs/architecture.md).

## Wat het doet

1. **Scan** - Xurrent: tickets met status `assigned`/`waiting_for` en "Volgende target" < vandaag.
2. **Idempotentie-gate** - tickets met een `[AI-TRIAGE`-marker worden overgeslagen (1x checken).
3. **Historiek-lookup** - zoekt gelijkaardige, reeds opgeloste tickets in de context-MCP (`tickets/by-id/*`).
4. **Classificatie** - `incident` (reproduceerbaar) / `datakwestie` / `documentatie`.
5. **Diagnose** - reproduceert op QA (XML-RPC, read-only) + analyseert `eeg-main/custom`.
6. **Notitie** - plaatst een interne notitie met marker, classificatie, geverifieerde feiten, historiek-verwijzing en advies. **Nooit code/data-wijzigingen.**

## Gebruik (lokaal)

Dubbelklik de bureaublad-snelkoppeling, of in een terminal:

```cmd
claude "/ticket-triage mij"
```

Scope-argument: `mij` | `team` | `<naam>` | `#<ticket-id>`.

De snelkoppeling (`scripts/start-triage.cmd`) start Claude Code in **auto-modus** (`--settings scripts/triage-permissions.json`): de agent scant, diagnosticeert en plaatst notities **zelfstandig**, zonder per stap toestemming te vragen. De veiligheidsvangrails blijven actief - zie [Beveiliging](#beveiliging).

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
- De agent doet **geen** wijzigingen op productie; QA-reproductie is read-only (test-writes enkel op QA, met herstel).
- Notities zijn **intern** (onzichtbaar voor de aanvrager).
