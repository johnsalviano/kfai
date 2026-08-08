// Lê (somente leitura) quais provedores de IA estão configurados no 9Router.
// NÃO exibe segredos: retorna apenas provider, isActive e se tem chave salva.
const path = process.argv[2];
const betterSqlite = process.argv[3];
const D = require(betterSqlite);
let db;
try {
  db = new D(path, { readonly: true });
} catch (e) {
  console.log(JSON.stringify({ error: "open", message: String(e && e.message || e) }));
  process.exit(0);
}
try {
  const rows = db.prepare("SELECT provider, isActive, data FROM providerConnections").all();
  const out = rows.map(r => {
    let hasKey = false;
    try {
      const d = JSON.parse(r.data || "{}");
      hasKey = !!(d.apiKey || d.api_key || d.token || d.key);
    } catch (e) {}
    return { provider: r.provider, isActive: r.isActive, hasKey };
  });
  console.log(JSON.stringify({ providers: out }));
} catch (e) {
  console.log(JSON.stringify({ error: "query", message: String(e && e.message || e) }));
}
try { db.close(); } catch (e) {}
