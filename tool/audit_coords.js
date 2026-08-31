// Compares every coordinate in the catalogue against what OpenStreetMap holds.
//
// A wrong coordinate is invisible in the app — it just makes the distance, the
// fuel and the drive time quietly wrong, which is exactly the complaint that
// prompted this. Panjpeer Rocks was 4.5 km out. This finds the rest.
//
// Photon is queried once per place with a Pakistan bounding box, at roughly one
// request a second. Only a hit whose name really matches is compared, so a
// place OSM does not know is reported as "not found" rather than as an error.
const fs = require('fs');
const https = require('https');

const PATH = 'assets/data/destinations.json';
const BBOX = '60.87,23.63,77.84,37.10';
const UA = 'TripPlanner/1.0 (coordinate audit)';

/// Kilometres between two points.
function haversine(a, b) {
  const R = 6371;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const la1 = (a.lat * Math.PI) / 180;
  const la2 = (b.lat * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

const norm = (s) =>
  s
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

function get(url) {
  return new Promise((resolve) => {
    https
      .get(url, { headers: { 'User-Agent': UA } }, (res) => {
        let d = '';
        res.on('data', (c) => (d += c));
        res.on('end', () => {
          try {
            resolve(JSON.parse(d));
          } catch (_) {
            resolve(null);
          }
        });
      })
      .on('error', () => resolve(null));
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function lookup(name) {
  const url =
    'https://photon.komoot.io/api/?q=' +
    encodeURIComponent(name) +
    '&limit=8&lang=en&bbox=' +
    BBOX;
  const j = await get(url);
  if (!j || !Array.isArray(j.features)) return [];
  return j.features
    .filter((f) => f.properties && f.properties.countrycode === 'PK')
    .map((f) => ({
      name: f.properties.name || '',
      value: f.properties.osm_value || '',
      lat: f.geometry.coordinates[1],
      lng: f.geometry.coordinates[0],
    }));
}

/// A hit only counts when the name genuinely corresponds, so a nearby village
/// with a different name never moves a coordinate.
function bestMatch(target, hits) {
  const t = norm(target);
  for (const h of hits) {
    const n = norm(h.name);
    if (n === t) return h;
  }
  for (const h of hits) {
    const n = norm(h.name);
    if (n.startsWith(t) || t.startsWith(n)) return h;
  }
  return null;
}

(async () => {
  const doc = JSON.parse(fs.readFileSync(PATH, 'utf8'));
  const places = [];
  for (const d of doc.destinations) {
    places.push({ kind: 'town', id: d.id, name: d.name, lat: d.lat, lng: d.lng, ref: d });
    for (const a of d.attractions) {
      places.push({
        kind: 'stop',
        id: `${d.id}.${a.id}`,
        name: a.name,
        lat: a.lat,
        lng: a.lng,
        ref: a,
      });
    }
  }

  const only = process.argv[2];
  const list = only ? places.filter((p) => p.id.includes(only)) : places;

  console.log(`checking ${list.length} places against OpenStreetMap\n`);

  const off = [];
  let notFound = 0;

  for (let i = 0; i < list.length; i++) {
    const p = list[i];
    const hits = await lookup(p.name);
    const match = bestMatch(p.name, hits);
    await sleep(1100);

    if (!match) {
      notFound++;
      continue;
    }

    const km = haversine(p, match);
    if (km >= 3) {
      off.push({ ...p, osm: match, km });
      console.log(
        `${km.toFixed(1).padStart(6)} km off   ${p.name}` +
          `\n                  catalogue ${p.lat}, ${p.lng}` +
          `\n                  osm       ${match.lat.toFixed(4)}, ${match.lng.toFixed(4)}` +
          `  [${match.value}]`,
      );
    }

    if ((i + 1) % 25 === 0) console.log(`   … ${i + 1}/${list.length}`);
  }

  console.log(
    `\n${off.length} coordinates 3 km or more from OSM, ` +
      `${notFound} not found in OSM, ` +
      `${list.length - off.length - notFound} agree`,
  );

  fs.writeFileSync(
    'build/coord_audit.json',
    JSON.stringify(
      off.map((o) => ({
        id: o.id,
        kind: o.kind,
        name: o.name,
        km: Number(o.km.toFixed(2)),
        catalogue: { lat: o.lat, lng: o.lng },
        osm: { lat: Number(o.osm.lat.toFixed(4)), lng: Number(o.osm.lng.toFixed(4)) },
        osmName: o.osm.name,
        osmValue: o.osm.value,
      })),
      null,
      2,
    ) + '\n',
  );
  console.log('written to build/coord_audit.json');
})();
