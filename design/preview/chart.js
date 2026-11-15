// Draws the multi-unit progress chart into every <svg class="mu-chart">. Preview only (the app uses fl_chart).
// Each unit has its own colour and its own scale; left axis = first unit, right axis = second unit.
function drawMultiUnitChart(svg, opts = {}) {
  const W = 380, H = opts.height || 210, L = 36, R = 344, T = 26, B = H - 28;
  const days = 106; // 1 Aug → 15 Nov
  const x = (d) => L + (d / days) * (R - L);
  const series = opts.series || [
    { cls: 1, unit: 'kg', min: 30, max: 45, ticks: [30, 35, 40, 45], pts: [[3, 32.5], [10, 35], [17, 35], [24, 37.5], [31, 37.5], [38, 40], [52, 40], [66, 42.5, 'pr'], [80, 42.5]] },
    { cls: 2, unit: 'level', min: 4, max: 7, ticks: [4, 5, 6, 7], pts: [[45, 5], [59, 5], [73, 6], [87, 6], [101, 7, 'pr']] },
  ];
  let s = '<g class="grid">';
  series[0].ticks.forEach((t, i) => {
    const yy = B - (i / (series[0].ticks.length - 1)) * (B - T);
    s += `<line x1="${L}" x2="${R}" y1="${yy}" y2="${yy}"/>`;
  });
  s += '</g>';
  series.forEach((se, k) => {
    const y = (v) => B - ((v - se.min) / (se.max - se.min)) * (B - T);
    se.ticks.forEach((t) => {
      s += k === 0
        ? `<text class="ax t${se.cls}" x="${L - 6}" y="${y(t) + 4}" text-anchor="end">${t}</text>`
        : `<text class="ax t${se.cls}" x="${R + 6}" y="${y(t) + 4}">${t}</text>`;
    });
    s += `<text class="ax t${se.cls}" x="${k === 0 ? L - 6 : R + 6}" y="${T - 14}" text-anchor="${k === 0 ? 'end' : 'start'}" style="font-weight:600">${se.unit}</text>`;
    s += `<polyline class="line s${se.cls}" style="fill:none" points="${se.pts.map((p) => `${x(p[0])},${y(p[1])}`).join(' ')}"/>`;
    se.pts.forEach((p) => {
      s += p[2] === 'pr'
        ? `<circle class="pr" cx="${x(p[0])}" cy="${y(p[1])}" r="6"/>`
        : `<circle class="pt s${se.cls}" cx="${x(p[0])}" cy="${y(p[1])}" r="4.5"/>`;
    });
    se.y = y;
  });
  [['Aug', 0], ['Sep', 31], ['Oct', 61], ['Nov', 92]].forEach(([m, d]) => {
    s += `<text class="ax x" x="${x(d)}" y="${H - 8}" text-anchor="start">${m}</text>`;
  });
  if (opts.cursor) {
    const [si, pi] = opts.cursor; const se = series[si]; const p = se.pts[pi];
    s = `<line class="cursor" x1="${x(p[0])}" x2="${x(p[0])}" y1="${T}" y2="${B}"/>` + s;
  }
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.innerHTML = s;
}
document.querySelectorAll('svg.mu-chart').forEach((el) => drawMultiUnitChart(el, { cursor: el.dataset.cursor ? JSON.parse(el.dataset.cursor) : null, height: Number(el.dataset.h) || 200 }));
