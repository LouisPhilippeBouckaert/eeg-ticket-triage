# eeg-ticket-triage

Een lokale [Claude Code](https://claude.com/claude-code)-agent die **alle open Xurrent-tickets** van een medewerker bewaakt — ongeacht status. Status-, activiteits- en categoriegates bepalen per ticket of een (her)analyse zinvol is. De agent reconstrueert het probleem op de Odoo **QA**-database, analyseert de lokale `eeg-main` broncode, raadpleegt de historiek van afgesloten tickets, en plaatst een **interne notitie** met de diagnose. Tickets met een **overschreden streeftijd** krijgen altijd voorrang.

> **Status:** lokale testversie (v2). Draait op een werkstation *binnen* het EEG-netwerk (QA + lokale code + MCP's vereist). De architectuur is opgezet als blauwdruk voor een latere onbemande **Azure Container Apps Job** - zie [`docs/architecture.md`](docs/architecture.md).

## Wat het doet

1. **Scan** - Xurrent: alle open tickets binnen de scope, ongeacht status.
2. **Statusgate** - toegewezen/geaccepteerd → volle triage; in behandeling → lichte triage (alleen historiek-tip, geen QA); wachtend op... / wachtend op klant / afgehandeld / geweigerd → overslaan.
3. **Activiteitsgate** - is de eigen AI-notitie de laatste reactie → niets doen. Kwam er nadien menselijke reactie én ligt het ticket >4 weken stil (de update-doorlooptijd) → opnieuw meenemen. Recent nog actief → niets doen. Notities van de **Autokwalifier** (`🤖 Autokwalifier`) tellen niet als activiteit.
4. **Prioritering & budget** - vervallen tickets (volgende target < vandaag) eerst; max **3 volle QA-diagnoses** per run, de rest schuift door naar de volgende run.
5. **Historiek-lookup** - zoekt gelijkaardige, reeds opgeloste tickets in de context-MCP (`tickets/by-id/*`).
6. **Classificatie** - bepaalt de diepte: `incident` (reproduceerbaar) → volle QA-diagnose; `rfc`/`rfi`/datakwestie/documentatie → lichte analyse.
7. **Diagnose** - reproduceert op QA (XML-RPC, read-only) + analyseert `eeg-main/custom`.
8. **Notitie** - interne notitie met handle `🤖 AI-ticket-analyse [v2 · datum]`, classificatie, geverifieerde feiten, historiek-verwijzing en advies. **Nooit code/data-wijzigingen.**

## Gebruik (lokaal)

Dubbelklik de bureaublad-snelkoppeling, of in een terminal:

```cmd
claude "/ticket-triage mij"
```

Scope-argument: `mij` | `team` | `<naam>` | `#<ticket-id>`.

De snelkoppeling (`scripts/start-triage.cmd`) start Claude Code in **auto-modus** (`--settings scripts/triage-permissions.json`): de agent scant, diagnosticeert en plaatst notities **zelfstandig**, zonder per stap toestemming te vragen. De veiligheidsvangrails blijven actief - zie [Beveiliging](#beveiliging).

De gates maken de agent **dagelijks herhaalbaar**: een ticket waar niets op gebeurde produceert geen nieuwe notitie; her-analyse gebeurt pas na nieuwe menselijke activiteit gevolgd door 4 weken stilte.

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
- Notities zijn **intern** (onzichtbaar voor de aanvrager) en beperkt tot **één per ticket**, tot er opnieuw menselijke activiteit + 4 weken stilte is (activiteitsgate).
