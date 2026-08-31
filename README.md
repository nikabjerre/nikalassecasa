# Store lejligheder · Frederiksberg & 1799

Et dashboard over **ejerlejligheder på 100 m² eller derover** i Frederiksberg Kommune
og postnummer 1799 — både solgte (fra januar 2025) og dem der er til salg lige nu.
Viser kvadratmeterpris, størrelse og samlet pris, med filtre og sortering på
størrelse, m²-pris og dato. Data kommer fra `api.boligsiden.dk`.

## Live på Vercel

Deployes som statisk side + én serverless-funktion:

- `index.html` — hele dashboardet i ét dokument, med et indlejret datasnapshot der
  vises med det samme.
- `api/live.js` — Vercel-funktion (`GET /api/live`) der henter friske tal fra
  boligsiden server-side (ingen CORS) og returnerer samme JSON-form som `data.json`.
  Svaret CDN-caches i 5 minutter.

Ved indlæsning viser siden snapshot'et og kalder straks `/api/live`; lykkes det,
skiftes til friske tal og prikken ved datoen bliver grøn.

### Deploy

1. Push dette repo til GitHub.
2. På [vercel.com](https://vercel.com) → **Add New… → Project** → importér repoet.
3. Framework Preset: **Other**. Build command: tom. Output directory: tom.
   (Ligger koden i en undermappe, sæt **Root Directory** til den mappe.)
4. **Deploy.** Vercel bygger igen automatisk ved hvert push.

Node 18+ (global `fetch`). Ingen npm-afhængigheder.

## Kør lokalt

```powershell
powershell -ExecutionPolicy Bypass -File .\serve.ps1
```

Åbn `http://localhost:8791/`. `serve.ps1` serverer også `/api/live` (og `/live.json`)
med friske tal, så den lokale side opfører sig som på Vercel.

## Opdatér det indlejrede snapshot

```powershell
powershell -ExecutionPolicy Bypass -File .\fetch.ps1   # skriver data.json
powershell -ExecutionPolicy Bypass -File .\build.ps1   # data.json -> index.html
```

Commit og push; Vercel deployer selv.

## Filer

| Fil | Rolle |
|-----|-------|
| `index.html` | Færdig side med indlejret snapshot. Genereres af `build.ps1` — rediger ikke direkte. |
| `template.html` | Kilde: markup + CSS + JavaScript med pladsholderen `__DATA__`. **Rediger her.** |
| `data.json` | Datasnapshot. |
| `api/live.js` | Vercel serverless-funktion: friske tal fra boligsiden. |
| `bs-core.ps1` | Fælles PowerShell-kerne: henter og samler datasættet. |
| `fetch.ps1` | Skriver et friskt `data.json`. |
| `build.ps1` | `data.json` + `template.html` → `index.html`. |
| `serve.ps1` | Lokal server på :8791 med `/api/live`. |
| `package.json` | Angiver Node-version til Vercel. |

## Datakilde og metode

- Endpoints: `api.boligsiden.dk/search/list/addresses` (solgte) og
  `api.boligsiden.dk/search/cases` (til salg), filtreret på `addressTypes=condo`,
  `areaMin=100`, `municipalities=Frederiksberg` / `zipCodes=1799`.
  Dette er boligsidens **udokumenterede** interne API — det kan ændre sig uden varsel.
- «Størrelse» = BBR-boligareal. m²-pris = samlet pris / boligareal.
- Familieoverdragelser og handler med m²-pris uden for 10.000–200.000 kr tælles med i
  antal, men holdes ude af medianer og prisgrafer.
- De seneste måneders solgte tal er ufuldstændige pga. forsinkelse i tinglysningen.
- Postnr. 1799 ligger i Københavns Kommune (København V), ikke i Frederiksberg —
  derfor to selvstændige filtre der kan slås sammen.
