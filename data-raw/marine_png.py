"""Marine example data for geo_mde_3d(): reef corals (Scleractinia) and
ray-finned fishes (Actinopterygii) with recorded depths in the seas of
Papua New Guinea (142-156 E, 12-1 S), from OBIS, and GEBCO bathymetry on a
0.1 degree grid from the OBIS xylookup service. Writes
inst/extdata/obis_png_marine.csv (then gzip -9) and inst/extdata/png_bathymetry.csv (then gzip -9).
Only records under CC0 or CC BY licences are kept."""
import csv, json, sys, time, urllib.parse, urllib.request

BOX = "POLYGON((142 -12,156 -12,156 -1,142 -1,142 -12))"
TAXA = {"coral": 1363, "fish": 10194}
FIELDS = ("id,scientificName,species,decimalLongitude,decimalLatitude,depth,"
          "minimumDepthInMeters,maximumDepthInMeters,date_year,license,dataset_id")


def get(url, data=None):
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, data=data,
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)
        except Exception as e:  # retry on timeouts
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(url)


_dataset_licence = {}


def dataset_licence(did):
    """Licence of an OBIS dataset (records often leave it blank)."""
    if did not in _dataset_licence:
        res = get(f"https://api.obis.org/v3/dataset/{did}").get("results") or [{}]
        _dataset_licence[did] = res[0].get("intellectualrights") or ""
    return _dataset_licence[did]


def open_licence(text):
    t = (text or "").lower().replace(" ", "")
    if "nc" in t.replace("cc0", "").replace("license", "").replace("licence", ""):
        if "by-nc" in t or "non-commercial" in t or "noncommercial" in t or "(cc-by-nc" in t:
            return False
    return any(k in t for k in ("cc0", "zero", "publicdomain", "by/4", "by/3", "cc-by", "ccby"))


rows = []
for group, taxid in TAXA.items():
    after = None
    while True:
        u = (f"https://api.obis.org/v3/occurrence?taxonid={taxid}"
             f"&geometry={urllib.parse.quote(BOX)}&size=5000&fields={FIELDS}")
        if after:
            u += f"&after={after}"
        res = get(u)["results"]
        if not res:
            break
        for r in res:
            d = r.get("depth")
            if d is None and r.get("minimumDepthInMeters") is not None:
                lo, hi = r.get("minimumDepthInMeters"), r.get("maximumDepthInMeters")
                d = lo if hi is None else (lo + hi) / 2
            if d is None or not r.get("species"):
                continue
            lic = r.get("license") or dataset_licence(r.get("dataset_id"))
            if not open_licence(lic):
                continue
            r["license"] = lic
            rows.append({"group": group, "species": r["species"],
                         "lon": r["decimalLongitude"], "lat": r["decimalLatitude"],
                         "depth": round(float(d), 1), "year": r.get("date_year"),
                         "dataset_id": r.get("dataset_id"), "license": r.get("license")})
        after = res[-1]["id"]
        print(group, len(rows), file=sys.stderr)

seen, out = set(), []
for r in rows:
    k = (r["species"], round(r["lon"], 3), round(r["lat"], 3), r["depth"])
    if k not in seen and 0 <= r["depth"] <= 2000:
        seen.add(k)
        out.append(r)
with open("inst/extdata/obis_png_marine.csv (then gzip -9)", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0]))
    w.writeheader()
    w.writerows(out)

pts = [(round(142.05 + 0.1 * i, 2), round(-11.95 + 0.1 * j, 2))
       for j in range(110) for i in range(140)]
bathy = []
for s in range(0, len(pts), 1000):
    chunk = pts[s:s + 1000]
    res = get("https://api.obis.org/xylookup",
              json.dumps({"points": [list(p) for p in chunk]}).encode())
    for (x, y), r in zip(chunk, res):
        bathy.append((x, y, r.get("grids", {}).get("bathymetry")))
with open("inst/extdata/png_bathymetry.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["lon", "lat", "depth"])
    w.writerows(bathy)
