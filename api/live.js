// Vercel serverless function — fresh data from api.boligsiden.dk (no CORS: runs server-side).
// GET /api/live  ->  same JSON shape as data.json
// Response is CDN-cached 5 min so boligsiden isn't hit on every page view.

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36";
const HEADERS = { "User-Agent": UA, Accept: "application/json" };

async function getAll(baseUrl, key) {
  let page = 1, acc = [], total = null;
  while (true) {
    const r = await fetch(`${baseUrl}&per_page=1000&page=${page}`, { headers: HEADERS });
    if (!r.ok) throw new Error(`boligsiden ${r.status} @ ${baseUrl}`);
    const j = await r.json();
    total = j.totalHits;
    const items = j[key] || [];
    acc = acc.concat(items);
    if (items.length < 1000 || acc.length >= total) break;
    page++;
  }
  return acc;
}

const addrLabel = (a) =>
  `${a.roadName || ""} ${a.houseNumber || ""}${a.floor ? ", " + a.floor + "." : ""}${a.door ? " " + a.door : ""}`.trim();

function trimSold(a) {
  const regs = (a.registrations || []).filter(Boolean).slice()
    .sort((x, y) => (y.date || "").localeCompare(x.date || ""));
  const r0 = regs[0] || {};
  const saleArea = r0.livingArea || r0.area || null;
  let m2 = r0.perAreaPrice;
  if (!m2 && r0.amount && saleArea) m2 = Math.round(r0.amount / saleArea);
  const m2calc = r0.amount && a.livingArea ? Math.round(r0.amount / a.livingArea) : null;
  return {
    addr: addrLabel(a), zip: a.zipCode, city: a.cityName, area: a.livingArea,
    price: r0.amount, saleArea, m2, m2calc, date: r0.date, type: r0.type,
    lat: a.coordinates?.lat, lon: a.coordinates?.lon, slug: a.slugAddress,
  };
}

function trimCase(c) {
  const a = c.address || {};
  let dom = null;
  if (c.daysOnMarket && c.daysOnMarket.days != null) dom = c.daysOnMarket.days;
  else if (c.daysOnMarket?.current) dom = c.daysOnMarket.current.days;
  else if (c.daysListed) dom = c.daysListed;
  else if (c.timeOnMarket?.current) dom = c.timeOnMarket.current.days;
  return {
    addr: addrLabel(a), zip: a.zipCode || c.zipCode, city: a.cityName,
    area: c.housingArea || a.livingArea,
    price: c.priceCash, m2: c.perAreaPrice,
    rooms: c.numberOfRooms, yearBuilt: c.yearBuilt, energy: c.energyLabel,
    daysOnMarket: dom, priceChangePct: c.priceChangePercentage,
    lat: c.coordinates?.lat, lon: c.coordinates?.lon,
    slug: c.slugAddress || a.slugAddress,
  };
}

async function getBoligData() {
  const yr = new Date().getFullYear();
  const soldBase = `https://api.boligsiden.dk/search/list/addresses?addressTypes=condo&sold=true&sortBy=soldDate&sortAscending=false&yearSoldFrom=2025&yearSoldTo=${yr}&areaMin=100`;
  const saleBase = `https://api.boligsiden.dk/search/cases?addressTypes=condo&areaMin=100&sortBy=price&sortAscending=true`;
  const [sf, sz, ff, fz] = await Promise.all([
    getAll(`${soldBase}&municipalities=Frederiksberg`, "addresses"),
    getAll(`${soldBase}&zipCodes=1799`, "addresses"),
    getAll(`${saleBase}&municipalities=frederiksberg`, "cases"),
    getAll(`${saleBase}&zipCodes=1799`, "cases"),
  ]);
  return {
    generated: new Date().toISOString(),
    source: "boligsiden.dk (api.boligsiden.dk)",
    criteria: { addressType: "ejerlejlighed (condo)", minLivingArea: 100, soldFrom: "2025-01-01" },
    sold: { frederiksberg: sf.map(trimSold), zip1799: sz.map(trimSold) },
    forSale: { frederiksberg: ff.map(trimCase), zip1799: fz.map(trimCase) },
  };
}

export default async function handler(req, res) {
  try {
    const data = await getBoligData();
    res.setHeader("Cache-Control", "public, s-maxage=300, stale-while-revalidate=1800");
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.status(200).send(JSON.stringify(data));
  } catch (e) {
    res.status(502).json({ error: "kunne ikke hente data fra boligsiden.dk", detail: String(e) });
  }
}
