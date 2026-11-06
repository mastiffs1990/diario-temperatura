# Esportare i dati dalla PWA originale

Questa procedura è **sola lettura**: scarica un JSON dal browser e non modifica né cancella il localStorage della vecchia app.

1. Apri la vecchia PWA pubblicata da `main`: https://mastiffs1990.github.io/diario-temperatura/
2. Apri gli strumenti sviluppatore di Chrome con `F12`, quindi la scheda Console.
3. Incolla tutto lo script qui sotto e premi Invio.
4. Salva il file JSON scaricato. Non aprirlo né modificarlo.

```javascript
(() => {
  const ARCH = "diario-temperatura-archivio-v1";
  const read = key => {
    try { return JSON.parse(localStorage.getItem(key) || "null"); }
    catch { return null; }
  };
  const extract = value => {
    if (Array.isArray(value)) return value;
    if (value && Array.isArray(value.rows)) return value.rows;
    if (value && Array.isArray(value.data)) return value.data;
    return [];
  };
  const normalize = (r, i, prefix) => {
    const temp = Number(String(r.temp ?? r.temperature ?? r.temperatura ?? "").replace(",", "."));
    const rawDate = r.when ?? r.date ?? r.datetime ?? r.data ?? r.timestamp;
    const date = new Date(rawDate);
    if (!Number.isFinite(temp) || !Number.isFinite(date.getTime())) return null;
    const rawMed = String(r.med ?? r.medicine ?? r.farmaco ?? r.medicinale ?? "Nessuno").trim().toLowerCase();
    const med = rawMed.includes("nurofen") ? "Nurofen"
      : rawMed.includes("tachipirina") ? "Tachipirina"
      : rawMed.includes("antibiot") ? "Antibiotico" : "Nessuno";
    return {
      id: String(r.id ?? (prefix + "-" + i + "-" + date.getTime())),
      temp, when: date.toISOString(), med,
      note: String(r.note ?? r.notes ?? "")
    };
  };

  const candidates = [];
  const sourceKeys = [];
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key || !key.includes("diario-temperatura") || key === ARCH) continue;
    sourceKeys.push(key);
    candidates.push(...extract(read(key)));
  }

  const activeSeen = new Set();
  const activeRows = candidates.map((r, i) => normalize(r, i, "active"))
    .filter(Boolean)
    .filter(r => {
      const signature = [r.when, r.temp, r.med, r.note].join("|");
      if (activeSeen.has(signature)) return false;
      activeSeen.add(signature);
      return true;
    });

  const archivesRaw = read(ARCH);
  const archives = (Array.isArray(archivesRaw) ? archivesRaw : []).map((a, ai) => ({
    title: String(a.title ?? ("Episodio " + (ai + 1))),
    createdAt: a.createdAt ?? new Date().toISOString(),
    note: String(a.note ?? ""),
    rows: extract(a.rows).map((r, ri) => normalize(r, ri, "archive-" + ai)).filter(Boolean)
  }));

  const payload = {
    format: "diario-temperatura-export",
    version: 1,
    exportedAt: new Date().toISOString(),
    sourceKeys,
    activeRows,
    archives
  };
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "diario-temperatura-backup-" + new Date().toISOString().slice(0, 10) + ".json";
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  console.table({
    chiaviLette: sourceKeys.length,
    misurazioniAttive: activeRows.length,
    episodiArchiviati: archives.length,
    misurazioniArchiviate: archives.reduce((n, a) => n + a.rows.length, 0)
  });
  console.log("Esportazione completata: localStorage non è stato modificato.");
})();
```

Poi apri la nuova app cloud, accedi, seleziona il JSON nella sezione **Porting dati dalla vecchia app**, controlla il riepilogo e premi **Importa dati verificati**. La procedura è idempotente: se viene interrotta, puoi ripeterla con lo stesso file.
