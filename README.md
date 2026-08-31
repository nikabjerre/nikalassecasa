# Store lejligheder · Frederiksberg & 1799

En webside der viser kvadratmeterpris, størrelse og samlet pris for ejerlejligheder
**over 100 m²** i Frederiksberg Kommune og postnummer 1799 — både solgte (fra januar 2025)
og dem der er til salg lige nu. Data hentes fra boligsiden.dk's offentlige søge-API.

Publiceret som Claude Artifact:
https://claude.ai/code/artifact/0fe9406d-3c7d-496a-b404-b0332903dad0

## Filer

| Fil | Rolle |
|-----|-------|
| `index.html` | Den færdige side — ét selvstændigt dokument med data indlejret. Dette er artifact-kilden. |
| `template.html` | Skabelonen (markup + CSS + JavaScript) med pladsholderen `__DATA__`. Rediger her. |
| `data.json` | Datasnapshot hentet fra boligsiden. |
| `bs-core.ps1` | Fælles kerne: henter og samler datasættet fra `api.boligsiden.dk`. |
| `fetch.ps1` | Skriver et friskt `data.json` (bruger `bs-core.ps1`). |
| `build.ps1` | Sætter `data.json` ind i `template.html` → `index.html`. |
| `serve.ps1` | Lokal webserver på `http://localhost:8791/` + `/live.json` med friske tal. |

## To måder at få friske tal

**1. Live ved hver indlæsning (lokalt).** Start serveren og åbn siden dér:

```powershell
powershell -ExecutionPolicy Bypass -File .\serve.ps1
```

Åbn så `http://localhost:8791/`. Siden viser først det indlejrede snapshot og henter
straks friske tal fra `api.boligsiden.dk` via `/live.json` (grøn prik = live).
Serveren cacher de friske tal i 5 minutter, så gentagne åbninger er hurtige.

**2. Opdatér snapshot + artifact.**

```powershell
powershell -ExecutionPolicy Bypass -File .\fetch.ps1
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

Upload derefter `index.html` som ny version af artifact'et.
Selve artifact-linket kan **ikke** hente data ved åbning (claude.ai's sandbox
blokerer eksterne kald) — det viser altid snapshot'et fra sidste build.

## Datakilder (api.boligsiden.dk)

- **Solgte:** `GET /search/list/addresses?municipalities=Frederiksberg&addressTypes=condo&sold=true&sortBy=soldDate&sortAscending=false&yearSoldFrom=2025&yearSoldTo=2026&areaMin=100`
  (og tilsvarende med `zipCodes=1799`)
- **Til salg:** `GET /search/cases?addressTypes=condo&municipalities=frederiksberg&areaMin=100`
  (og tilsvarende med `zipCodes=1799`)

## Metode-noter

- «Størrelse» er BBR-boligareal. m²-pris beregnes som samlet pris / boligareal.
- Handler markeret *familie* / *anden* og handler med åbenlyst afvigende tinglyst
  areal/pris (m²-pris uden for 10.000–200.000 kr) tælles med i antal, men holdes
  ude af median­priser og prisgrafer.
- De seneste måneders solgte tal er ufuldstændige pga. forsinkelse i tinglysningen.
- Postnummer 1799 ligger i Københavns Kommune (København V), ikke i Frederiksberg —
  de to områder er derfor selvstændige filtre der kan slås sammen.
