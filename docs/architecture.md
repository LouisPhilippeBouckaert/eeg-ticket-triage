# Architectuur & fasering

## Pijplijn

```
1. SCAN (Xurrent)        tickets assigned/waiting_for + volgende target < vandaag
2. IDEMPOTENTIE-GATE     skip tickets met [AI-TRIAGE-marker (1x checken)
3. HISTORIEK-LOOKUP      context-MCP: gelijkaardige opgeloste tickets (tickets/by-id/*)
4. CLASSIFICEER          incident (reproduceerbaar) | datakwestie | documentatie
5. DIAGNOSE              QA-reproductie (XML-RPC, read-only) + eeg-main code-analyse
6. OUTPUT                interne notitie met marker + diagnose + advies
```

## Fase 1 - lokaal (huidige status)

Draait op een werkstation binnen het EEG-netwerk via Claude Code + de bestaande lokale
MCP's (`xurrent`, `context`), QA via XML-RPC en een lokale `eeg-main` checkout.
Gestart via een **bureaublad-snelkoppeling** (manueel, onder controle van de gebruiker).

**Waarom lokaal:** drie bronnen zitten binnen het netwerk / op de machine:

| Bron | Locatie | Gevolg |
|------|---------|--------|
| QA-Odoo | intern IP (10.210.x) | enkel bereikbaar vanaf het EEG-netwerk |
| `eeg-main` broncode | lokale checkout | niet beschikbaar op een externe agent |
| MCP-servers | Docker Desktop, lokaal | verdwijnen als de pc uit is |
| Xurrent | extern (cloud) | overal bereikbaar |

Daardoor kan een **externe/cloud**-routine de QA-diagnose niet doen; vandaar lokaal.

### Afgewogen alternatieven voor onbemand draaien

- **Remote scheduled agent (cloud):** pc kan uit, maar geen route naar QA, geen lokale
  code/MCP -> enkel de Xurrent-scan/digest, niet de diagnose.
- **Geplande wake uit slaap:** geblokkeerd - wake-timers staan via policy uit en de
  gebruiker heeft geen admin-rechten (vereist IT/Intune).
- **Bureaublad-snelkoppeling (gekozen):** omzeilt alle blokkers; gebruiker start manueel
  wanneer de pc aan is (QA + code + MCP's beschikbaar) en houdt zelf controle.

## Fase 2 - onbemand op een VM (blauwdruk)

Doel: dezelfde pijplijn 's avonds (bv. 20u, voor QA om 22u uitvalt) onbemand draaien.

**Aanbevolen platform:** een **Azure Container Apps Job** met cron-schedule in de gedeelde
CAE `cae-lpn-prod-westeurope-001` (zelfde patroon als `caj-voicenote-scanner-prod-001`).

| Eis | Invulling |
|-----|-----------|
| QA bereiken | CAE in VNet `vnet-shared-prod-westeurope-001` -> interne route naar QA |
| 's Avonds, onbemand | ACA Job cron (bv. `0 20 * * 1-5`), scale-to-zero |
| Secrets | Key Vault references + user-assigned Managed Identity |
| Broncode | `eeg-main` in het container-image of clone bij start |
| Digest | Graph `sendMail` (Mail.Send app-permission) |

**Belangrijkste verschil met fase 1:** geen lokale MCP's. De job praat rechtstreeks met de
API's - **Xurrent REST**, **Odoo XML-RPC**, **Anthropic API** - en haalt de ticket-historiek
uit SharePoint/blob i.p.v. de lokale context-MCP. De diagnose-logica blijft identiek.

## Governance

- **Idempotentie:** `[AI-TRIAGE`-marker voorkomt dubbele behandeling.
- **Eigen vs collega's tickets:** bij teambrede runs eerst een scope-overzicht + go vragen
  voor er notities op andermans tickets geplaatst worden (review-first).
- **Geen wijzigingen op productie**; QA-reproductie read-only (test-writes met herstel).
- **incident vs rfc/rfi:** alleen reproduceerbare incidents krijgen volle QA-diagnose;
  rfc/rfi krijgen classificatie + historiek + signaal (bespaart tokens/ruis).
