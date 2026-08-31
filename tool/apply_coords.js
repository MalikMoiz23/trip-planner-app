// Applies the coordinate corrections that are safe to trust, and says why it
// refused the rest.
//
// Not every OSM hit is better than the catalogue. Three kinds of bad match show
// up, and each would make distances worse rather than better:
//
//  * A different place with a similar name. "Naran" prefix-matched "Narang",
//    209 km away, because the matcher accepted a prefix without a word break.
//  * A road named after the place. "Pir Chinasi Rd" is a line; its midpoint is
//    not where you park.
//  * The centroid of something large. A national park or a river centroid is
//    nowhere in particular — the hand-picked access point on the highway is
//    the more useful coordinate for someone driving there.
const fs = require('fs');

const AUDIT = 'build/coord_audit.json';
const DATA = 'assets/data/destinations.json';

/// OSM feature types that name a point, and name it well enough to trust over a
/// hand-entered coordinate.
const TRUSTED = new Set([
  'village', 'town', 'city', 'hamlet', 'locality', 'neighbourhood', 'suburb',
  'lake', 'water', 'reservoir', 'waterfall', 'spring', 'glacier', 'peak',
  'viewpoint', 'beach', 'camp_site', 'attraction', 'museum', 'fort', 'castle',
  'ruins', 'archaeological_site', 'monument', 'memorial',
]);

/// Beyond this, a "match" is a different place wearing a similar name.
const MAX_KM = 60;

const norm = (s) =>
  s.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();

/// True when the OSM name is the catalogue name, optionally followed by whole
/// extra words. "Passu Cones Viewpoint" yes; "Narang" for "Naran" no.
function namesAgree(mine, osm) {
  const a = norm(mine);
  const b = norm(osm);
  if (a === b) return true;
  if (b.startsWith(a + ' ')) return true;
  if (a.startsWith(b + ' ')) return true;
  return false;
}

const audit = JSON.parse(fs.readFileSync(AUDIT, 'utf8'));
const doc = JSON.parse(fs.readFileSync(DATA, 'utf8'));

const applied = [];
const skipped = [];

for (const item of audit) {
  let reason = null;
  if (!TRUSTED.has(item.osmValue)) {
    reason = `OSM type "${item.osmValue}" is a line or an area, not a point`;
  } else if (item.km > MAX_KM) {
    reason = `${item.km} km apart — a different place`;
  } else if (!namesAgree(item.name, item.osmName)) {
    reason = `"${item.osmName}" is not the same name`;
  }

  if (reason) {
    skipped.push({ ...item, reason });
    continue;
  }

  const [townId, stopId] = item.id.split('.');
  const town = doc.destinations.find((d) => d.id === townId);
  if (!town) continue;

  const target = stopId ? town.attractions.find((a) => a.id === stopId) : town;
  if (!target) continue;

  target.lat = item.osm.lat;
  target.lng = item.osm.lng;
  applied.push(item);
}

fs.writeFileSync(DATA, JSON.stringify(doc, null, 2) + '\n', 'utf8');

console.log(`APPLIED ${applied.length}:`);
for (const a of applied.sort((x, y) => y.km - x.km)) {
  console.log(`  ${a.km.toFixed(1).padStart(6)} km  ${a.name}  [${a.osmValue}]`);
}

console.log(`\nSKIPPED ${skipped.length}:`);
for (const s of skipped.sort((x, y) => y.km - x.km)) {
  console.log(`  ${s.km.toFixed(1).padStart(6)} km  ${s.name}  —  ${s.reason}`);
}
