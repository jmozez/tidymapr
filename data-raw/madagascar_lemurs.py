"""Lemur occurrence records in Madagascar (GBIF, order Primates, country MG)
for the geo_mde() example. Only CC0 and CC BY 4.0 records with coordinates
and no geospatial issues; one record per species and location (3 decimal
places). Writes inst/extdata/gbif_lemurs_madagascar.csv (then gzip -9)."""
import csv, json, time, urllib.request

BASE = ("https://api.gbif.org/v1/occurrence/search?country=MG&taxonKey=798"
        "&hasCoordinate=true&hasGeospatialIssue=false&license=CC0_1_0&license=CC_BY_4_0"
        "&limit=300&offset=")


def get(url):
    for attempt in range(6):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return json.load(r)
        except Exception:
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(url)


rows, offset = [], 0
while True:
    page = get(BASE + str(offset))
    for r in page["results"]:
        if not r.get("species"):
            continue
        unc = r.get("coordinateUncertaintyInMeters")
        if unc is not None and unc > 10000:
            continue
        rows.append({"species": r["species"], "lon": r["decimalLongitude"],
                     "lat": r["decimalLatitude"], "year": r.get("year"),
                     "basis_of_record": r.get("basisOfRecord"),
                     "dataset_key": r.get("datasetKey"), "license": r.get("license")})
    offset += 300
    if page.get("endOfRecords") or offset >= page["count"]:
        break
import collections
crowd = collections.defaultdict(set)
for r in rows:
    crowd[(r["dataset_key"], r["lon"], r["lat"])].add(r["species"])
rows = [r for r in rows if len(crowd[(r["dataset_key"], r["lon"], r["lat"])]) < 20]
seen, out = set(), []
for r in rows:
    k = (r["species"], round(r["lon"], 3), round(r["lat"], 3))
    if k not in seen:
        seen.add(k)
        out.append(r)
with open("inst/extdata/gbif_lemurs_madagascar.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(out[0]))
    w.writeheader()
    w.writerows(out)
print(len(rows), len(out))
