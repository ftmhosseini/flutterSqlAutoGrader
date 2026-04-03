import { doc, setDoc, getDoc } from 'firebase/firestore';
import { db } from '../../../firebase.js';
import initSqlJs from 'sql.js';

let SQL = null;
let runtimeConfig = {};
let cachedDatabases = null; // cache built databases in memory

// Upload once
// Initialize SQL.js once
export const initSQL = async () => {
    if (!SQL) {
        SQL = await initSqlJs({
            locateFile: () => `/sql-wasm.wasm` // located in public
        });
    }
    return SQL;
};

// Add data such as create Dataset, table, and table Schema in Firestore
export const addDataToFirestore = async (dbname, query = []) => {
    runtimeConfig = await getSqliteConfig();
    if (!runtimeConfig[dbname]) {
        runtimeConfig[dbname] = { name: `${dbname}.sqlite`, queries: [] };
    }
    if (runtimeConfig) {
        runtimeConfig[dbname].queries.push(...query);
        await setDoc(doc(db, 'sqliteConfigs', 'mainConfig'), runtimeConfig);
        invalidateDatabaseCache(); // force rebuild on next load
        console.log('Saved to Firestore');
    }
};

// Retrieve anytime
export const getSqliteConfig = async () => {
    const docSnap = await getDoc(doc(db, 'sqliteConfigs', 'mainConfig'));
    if (docSnap.exists()) {
        return docSnap.data();
    }
    return null;
};
// Use it
export const loadSqliteData = async () => {
    if (cachedDatabases) return cachedDatabases; // return cache on subsequent calls
    const databases = {};
    await initSQL();
    runtimeConfig = await getSqliteConfig();
    if (!runtimeConfig) {
        console.error('No config found in Firestore');
        return {};
    }
    for (const [key, config] of Object.entries(runtimeConfig)) {
        const sqliteDb = new SQL.Database();
        for (const query of config.queries)
            try {
                sqliteDb.run(query);
            } catch (error) {
                console.error(`Error in ${key}:`, error.message);
                console.error('Failed query:', query);
                throw error;
            }
        databases[key] = sqliteDb;
    }
    cachedDatabases = databases; // store in cache
    return databases;
};

// Call this after teacher adds/modifies datasets so cache is refreshed
export const invalidateDatabaseCache = () => { cachedDatabases = null; };
