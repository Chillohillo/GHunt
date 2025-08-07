// Kickbase KES Analyzer – Scriptable (iOS)
// Fetches player data from Kickly and fabilous dashboards,
// computes Kickbase Efficiency Score (KES) and exports results
// as JSON (and optionally PDF) to iCloud and local storage.

// Set to false to skip PDF generation
const GENERATE_PDF = true;

// Optional credentials via widget parameter in the format "email:password"
const credentials = (args.widgetParameter || "").split(":");

// Benchmarks for KES calculation
const benchmarks = {
  ST: { euro: 12000, points: 150 },
  MF: { euro: 8000, points: 120 },
  ABW: { euro: 5000, points: 95 },
  TW: { euro: 6000, points: 100 }
};

function calculateKES(euroPerPoint, avgPoints, valueEfficiency, trendRatio, position) {
  const b = benchmarks[position] || benchmarks["MF"];
  const valueScore = Math.max(0, Math.min(40, 40 * (1 - (euroPerPoint - b.euro * 0.3) / (b.euro * 1.5))));
  const performanceScore = Math.max(0, Math.min(30, 30 * (avgPoints / (b.points * 1.2))));
  const efficiencyScore = Math.max(0, Math.min(20, 20 * Math.min(1, valueEfficiency / 300)));
  const trendBonus = Math.max(-5, Math.min(10, trendRatio * 1000));
  return Math.round((valueScore + performanceScore + efficiencyScore + trendBonus) * 10) / 10;
}

function recommend(kes) {
  if (kes >= 70) return "Kaufen";
  if (kes >= 50) return "Halten";
  if (kes >= 30) return "Beobachten";
  return "Verkaufen";
}

function cleanNumber(str) {
  return parseFloat((str || "0").replace(/[^\d.-]/g, "")) || 0;
}

async function fetchTable(url, login) {
  const web = new WebView();
  await web.loadURL(url);
  if (login && login[0] && login[1]) {
    try {
      await web.evaluateJavaScript(`
        const email = document.querySelector('input[type="email"]');
        const pass = document.querySelector('input[type="password"]');
        if (email && pass) {
          email.value = '${login[0]}';
          pass.value = '${login[1]}';
          const form = email.closest('form');
          if (form) form.submit();
        }
      `, false);
      await web.waitForLoad();
    } catch (e) {
      console.log("Login failed", e);
    }
  }
  const script = `
    [...document.querySelectorAll('table tbody tr')].map(row => {
      const cells = row.querySelectorAll('td');
      return {
        name: cells[0]?.innerText.trim(),
        position: cells[1]?.innerText.trim(),
        totalPoints: cleanNumber(cells[2]?.innerText),
        avgPoints: cleanNumber(cells[3]?.innerText),
        marketValue: cleanNumber(cells[4]?.innerText),
        trend: cleanNumber(cells[5]?.innerText)
      };
      function cleanNumber(str){return parseFloat((str||'0').replace(/[^\d.-]/g,''))||0;}
    });
  `;
  return await web.evaluateJavaScript(script, true);
}

function enrich(player) {
  const trendRatio = player.marketValue ? player.trend / player.marketValue : 0;
  const euroPerPoint = player.totalPoints ? player.marketValue / player.totalPoints : 0;
  const valueEfficiency = euroPerPoint ? (player.avgPoints / euroPerPoint) * 1000 : 0;
  const kes = calculateKES(euroPerPoint, player.avgPoints, valueEfficiency, trendRatio, player.position);
  return {
    name: player.name,
    position: player.position,
    totalPoints: player.totalPoints,
    avgPoints: player.avgPoints,
    marketValue: player.marketValue,
    trend: player.trend,
    trendRatio,
    euroPerPoint,
    valueEfficiency,
    kes,
    recommendation: recommend(kes)
  };
}

function buildHTML(players) {
  const rows = players.slice(0, 20).map((p, i) => `<tr><td>${i + 1}</td><td>${p.name}</td><td>${p.position}</td><td>${p.kes}</td></tr>`).join('');
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><style>table{width:100%;border-collapse:collapse;}th,td{border:1px solid #ccc;padding:4px;text-align:left;}</style></head><body><h1>KES Top 20</h1><table><tr><th>#</th><th>Name</th><th>Pos</th><th>KES</th></tr>${rows}</table></body></html>`;
}

async function saveOutputs(players) {
  const today = new Date().toISOString().slice(0,10);
  const jsonFile = `KES_Ergebnisse_${today}.json`;
  const pdfFile = `KES_Report_${today}.pdf`;
  const fmI = FileManager.iCloud();
  const fmL = FileManager.local();
  const dirI = fmI.documentsDirectory();
  const dirL = fmL.documentsDirectory();
  const jsonData = JSON.stringify(players, null, 2);
  fmI.writeString(fmI.joinPath(dirI, jsonFile), jsonData);
  fmL.writeString(fmL.joinPath(dirL, jsonFile), jsonData);
  if (GENERATE_PDF) {
    const html = buildHTML(players);
    const w = new WebView();
    await w.loadHTML(html);
    const pdf = await w.pdf();
    fmI.write(fmI.joinPath(dirI, pdfFile), pdf);
    fmL.write(fmL.joinPath(dirL, pdfFile), pdf);
  }
  console.log(`Saved ${players.length} players to ${jsonFile}`);
}

async function main() {
  try {
    const [kickly, fabilous] = await Promise.all([
      fetchTable('https://kickly.de/dashboard'),
      fetchTable('https://kickbase.fabilous.tech/dashboard', credentials)
    ]);
    const players = [...kickly, ...fabilous].map(enrich).sort((a, b) => b.kes - a.kes);
    await saveOutputs(players);
  } catch (err) {
    console.error(err);
    QuickLook.present(err.toString());
  }
}

await main();

