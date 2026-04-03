// Runs inside a Web Worker — no React, no Firebase imports
importScripts('/sql-wasm.js');

let SQL = null;

initSqlJs({ locateFile: () => '/sql-wasm.wasm' }).then(s => { SQL = s; });

self.onmessage = async ({ data: { id, type, dbname, config, query } }) => {
  try {
    if (!SQL) {
      // Wait up to 3s for sql.js to initialise
      await new Promise((res, rej) => {
        const t = setTimeout(() => rej(new Error('sql.js failed to load')), 3000);
        const check = setInterval(() => { if (SQL) { clearInterval(check); clearTimeout(t); res(); } }, 50);
      });
    }

    // Build the in-memory DB from the Firestore config
    const dbConfig = config[dbname];
    if (!dbConfig) throw new Error(`No config for database: ${dbname}`);

    const db = new SQL.Database();
    for (const q of dbConfig.queries) db.run(q);

    let result;
    if (type === 'exec') {
      // selectQuery path — returns raw sql.js result array
      result = db.exec(query);
      self.postMessage({ id, isSuccessful: true, data: result });
    } else {
      // fetchData path — returns array of row objects
      const stmt = db.prepare(query);
      const rows = [];
      while (stmt.step()) rows.push(stmt.getAsObject());
      stmt.free();
      self.postMessage({ id, isSuccessful: true, data: rows });
    }

    db.close();
  } catch (err) {
    self.postMessage({ id, isSuccessful: false, message: err.message });
  }
};
