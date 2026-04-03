import { loadSqliteData, addDataToFirestore, getSqliteConfig } from '../setup/setupFirebaseDb';


const initDB = async (dbname) => {
    const databases = await loadSqliteData();
    return databases[dbname];
};

export const fetchDatasetsDB = async () => {
    const db = await initDB('db');
    const result = db.exec('SELECT datasetName FROM Datasets');
    const dbs = result[0]?.values.map(row => ({ datasetName: row[0] })) || [];
    return dbs;
}

export const fetchTablesDB = async (datasetName) => {
    const db = await initDB('db');
    const result = db.exec(`SELECT * FROM Tables WHERE datasetName = '${datasetName}'`);
    const tables = result[0]?.values.map(row => ({ tableName: row[1] })) || [];
    return tables;
}

export const insertDataset = async (name) => {
    await addDataToFirestore('db', [`INSERT INTO Datasets (datasetName) VALUES ('${name}')`])
    await addDataToFirestore(name);
}

export const insertTable = async (tableName, datasetName) => {
    await addDataToFirestore('db', [`INSERT INTO Tables (tableName, datasetName) VALUES ('${tableName}', '${datasetName}')`])
}

export const getTableSchema = async (tableName, dbname) => {
    const db = await initDB(dbname);
    try {
        const allTables = db.exec(`SELECT name FROM sqlite_master WHERE type='table'`);

        if (allTables.length === 0) {
            console.warn('No tables found in database, checking localStorage...');
            const schemaKey = `schema_${dbname}`
            const existingSchema = JSON.parse(localStorage.getItem(schemaKey) || '{}');
            return existingSchema['Users']?.createSQL || null;
        }
        const result = db.exec(`SELECT sql FROM sqlite_master WHERE type='table' AND name='${tableName}'`);
        return result[0]?.values[0]?.[0] || null;
    } catch (error) {
        console.error('Error getting table schema:', error);
        return null;
    }
}

export const getTableInTable = async (tableName, dbname) => {
    const createSQL = await getTableSchema(tableName, dbname);

    if (!createSQL) return [];
    const match = createSQL.match(/\((.+)\)$/s);
    if (!match) return [];
    const splitCols = (str) => {
        const cols = [];
        let depth = 0, cur = '';
        for (const ch of str) {
            if (ch === '(') depth++;
            else if (ch === ')') depth--;
            else if (ch === ',' && depth === 0) { cols.push(cur.trim()); cur = ''; continue; }
            cur += ch;
        }
        if (cur.trim()) cols.push(cur.trim());
        return cols;
    };
    const allCols = splitCols(match[1]).filter(Boolean);

    const fkCols = new Set(
        allCols
            .filter(col => col.toUpperCase().startsWith('FOREIGN KEY'))
            .map(col => { const m = col.match(/FOREIGN KEY\s*\((\w+)\)/i); return m?.[1]; })
            .filter(Boolean)
    );

    return allCols.filter(col => !col.toUpperCase().startsWith('FOREIGN KEY') && !col.toUpperCase().startsWith('PRIMARY KEY')).map(col => {
        const parts = col.split(/\s+/);
        return {
            name: parts[0],
            type: parts[1] || '',
            notNull: col.toUpperCase().includes('NOT NULL'),
            primaryKey: col.toUpperCase().includes('PRIMARY KEY'),
            foreignKey: fkCols.has(parts[0]),
        };
    });
};

export const generateCreateTableSQL = async (dbname, tableName, columns) => {
    const columnDefs = columns.map(col => {
        let def = `${col.name} ${col.type}`;
        if (!col.nullable) def += ' NOT NULL';
        if (col.key === 'primary') def += ' PRIMARY KEY';
        return def;
    });

    const foreignKeys = columns
        .filter(col => col.key === 'foreign')
        .map(col => `FOREIGN KEY (${col.name}) REFERENCES ${col.refTable}(id)`);

    const allDefs = [...columnDefs, ...foreignKeys];
    const createSQL = `CREATE TABLE ${tableName} (${allDefs.join(', ')})`;
    await addDataToFirestore(dbname, [createSQL])

    return createSQL;
};

// Runs a query in a Web Worker — worker.terminate() on timeout actually kills
// the thread, unlike Promise.race which can't interrupt synchronous sql.js.
function runInWorker(type, dbname, query, timeoutMs = 5000) {
    return new Promise(async (resolve) => {
        const config = await getSqliteConfig();
        if (!config) return resolve({ isSuccessful: false, message: 'No database config found' });

        const worker = new Worker('/sqlWorker.js');
        const id = crypto.randomUUID();

        const timer = setTimeout(() => {
            worker.terminate();
            resolve({ isSuccessful: false, message: 'Query timed out' });
        }, timeoutMs);

        worker.onmessage = ({ data }) => {
            if (data.id !== id) return;
            clearTimeout(timer);
            worker.terminate();
            resolve({ isSuccessful: data.isSuccessful, data: data.data, message: data.message });
        };

        worker.onerror = (e) => {
            clearTimeout(timer);
            worker.terminate();
            resolve({ isSuccessful: false, message: e.message });
        };

        worker.postMessage({ id, type, dbname, config, query });
    });
}

export const fetchData = (dbname, query) => runInWorker('fetch', dbname, query);

export const selectQuery = (dbname, query, timeoutMs = 5000) => runInWorker('exec', dbname, query, timeoutMs);
