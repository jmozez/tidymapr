// tidymapr web map helpers (Leaflet 1.9)
const map = L.map('map', { zoomControl: true });
const esri = 'https://server.arcgisonline.com/ArcGIS/rest/services/';
const base = {
  'Topographic (Esri)': L.tileLayer(esri + 'World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    { maxZoom: 19, attribution: 'Tiles &copy; Esri' }),
  'Imagery (Esri)': L.tileLayer(esri + 'World_Imagery/MapServer/tile/{z}/{y}/{x}',
    { maxZoom: 19, attribution: 'Tiles &copy; Esri' }),
  'OpenStreetMap': L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    { maxZoom: 19, attribution: '&copy; OpenStreetMap contributors' }),
  'Light (CARTO)': L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    { maxZoom: 19, attribution: '&copy; OpenStreetMap contributors &copy; CARTO' })
};
const overlays = {};

function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;',
    '"': '&quot;', "'": '&#39;' }[c]));
}

function svgPoint(shape, fill, stroke, px) {
  const h = px / 2;
  let b;
  if (shape === 'square') b = `<rect x='2' y='2' width='${px - 4}' height='${px - 4}'`;
  else if (shape === 'triangle') b = `<polygon points='${h},1 ${px - 1},${px - 1} 1,${px - 1}'`;
  else if (shape === 'diamond') b = `<polygon points='${h},1 ${px - 1},${h} ${h},${px - 1} 1,${h}'`;
  else b = `<circle cx='${h}' cy='${h}' r='${h - 1.5}'`;
  return `<svg width='${px}' height='${px}' viewBox='0 0 ${px} ${px}'>${b} fill='${fill}' ` +
    `stroke='${stroke}' stroke-width='1.2'/></svg>`;
}

function popupHtml(p) {
  let r = '';
  for (const k in p) {
    if (k.startsWith('_') || p[k] === null) continue;
    r += `<tr><td>${esc(k)}</td><td>${esc(p[k])}</td></tr>`;
  }
  return r ? `<table>${r}</table>` : '';
}

function addFeatures(id, gj, kind, st, opt) {
  const lyr = L.geoJSON(gj, {
    style: f => kind === 'polygon'
      ? { fillColor: f.properties._c || '#fff', fillOpacity: f.properties._c ? st.fillOpacity : 0,
          color: st.color, weight: st.weight, dashArray: st.dashArray }
      : { color: f.properties._c, weight: st.weight, opacity: st.opacity, dashArray: st.dashArray },
    pointToLayer: (f, ll) => L.marker(ll, { icon: L.divIcon({ className: '',
      html: svgPoint(st.shape, f.properties._c, st.border, st.size),
      iconSize: [st.size, st.size], iconAnchor: [st.size / 2, st.size / 2] }) }),
    onEachFeature: (f, l) => {
      if (opt.popup) { const h = popupHtml(f.properties); if (h) l.bindPopup(h); }
    }
  }).addTo(map);
  overlays[esc(opt.name || id)] = lyr;
}

function addImage(id, src, b, name) {
  overlays[esc(name || id)] = L.imageOverlay(src, b, { opacity: 1, interactive: false }).addTo(map);
}

function addLabels(id, rows) {
  const g = L.layerGroup(rows.map(r => L.circleMarker([r.lat, r.lng],
    { radius: 0, opacity: 0, fillOpacity: 0 })
    .bindTooltip(esc(r.text), { permanent: true, direction: 'center', className: 'lbl' })));
  g.addTo(map);
  overlays['Labels'] = g;
}

function finish(opts) {
  base[opts.basemap].addTo(map);
  L.control.layers(base, overlays, { collapsed: false }).addTo(map);
  L.control.scale({ metric: true, imperial: false, position: 'bottomleft' }).addTo(map);
  const T = L.control({ position: 'topleft' });
  T.onAdd = () => { const d = L.DomUtil.create('div', 'panel'); d.innerHTML = opts.title; return d; };
  T.addTo(map);
  const G = L.control({ position: 'bottomright' });
  G.onAdd = () => {
    const d = L.DomUtil.create('div', 'panel legend');
    d.innerHTML = opts.legend;
    L.DomEvent.disableScrollPropagation(d);
    return d;
  };
  G.addTo(map);
  map.fitBounds(opts.bounds, { padding: [20, 20] });
}
