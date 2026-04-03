# Database Architecture — SQL Auto-Grader Lite

## Overview

SQL Auto-Grader Lite is a fully browser-based educational platform. It uses a **hybrid database architecture**:

- **Firebase Firestore** — persistent cloud storage for SQL configurations and query history
- **SQL.js (SQLite via WebAssembly)** — in-memory SQL execution entirely in the browser

There is no traditional backend server. All SQL runs client-side using `sql-wasm.wasm`.

---

## Initial Setup: Seeding Firestore for the First Time

When Firestore is empty (first run), you must upload the initial database configuration manually using `db-config.json`.

### Step 1 — Prepare `db-config.json`

Located at `src/db/setup/db-config.json`. It defines all databases and their seed queries:

```json
{
  "db": {
    "name": "db.sqlite",
    "queries": [
      "CREATE TABLE IF NOT EXISTS 'Datasets' (datasetName TEXT PRIMARY KEY)",
      "CREATE TABLE IF NOT EXISTS 'Tables' ( tableId INTEGER PRIMARY KEY AUTOINCREMENT, tableName TEXT NOT NULL, datasetName TEXT, FOREIGN KEY (datasetName) REFERENCES Datasets(datasetName))",
      "INSERT INTO Datasets (datasetName) VALUES ('datasetA'), ('datasetB')",
      "INSERT INTO Tables (tableName, datasetName) VALUES ('Departments', 'datasetA'), ('Employees', 'datasetA'), ('Customers', 'datasetB'), ('Orders', 'datasetB')"
    ]
  },
  "datasetA": {
    "name": "datasetA.sqlite",
    "queries": ["CREATE TABLE IF NOT EXISTS 'Departments' (...)", "..."]
  },
  "datasetB": {
    "name": "datasetB.sqlite",
    "queries": ["CREATE TABLE IF NOT EXISTS 'Customers' (...)", "..."]
  }
}
```

### Step 2 — Run the upload function (once only)

In `setupFirebaseDb.js`, the following is used to push the JSON config into Firestore:

```javascript
import sqliteData from './db-config.json' with { type: 'json' };

export const uploadSqliteConfig = async () => {
   await setDoc(doc(db, 'sqliteConfigs', 'mainConfig'), sqliteData);
   console.log('Uploaded successfully');
};

// Run once to upload initial data
uploadSqliteConfig().then(() => console.log('Reset complete'));
```

> After a successful upload, **comment out** the `uploadSqliteConfig()` call to prevent re-uploading on every page load.

### Step 3 — Verify in Firestore

After running the app once, the Firestore document `sqliteConfigs/mainConfig` will be populated. All subsequent loads read from Firestore — no re-seeding needed.

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                    DatabaseManager.js                   │
│                   (React UI Component)                  │
└────────────────────────┬────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────┐
│                      context.js                         │
│              (React Context — Global State)             │
└────────────────────────┬────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────┐
│                  setupDatabases.js                      │
│                (Business Logic Layer)                   │
└────────────────────────┬────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────┐
│                 setupFirebaseDb.js                      │
│              (Firebase + SQL.js Integration)            │
└──────────────┬──────────────────────────┬───────────────┘
               │                          │
               ↓                          ↓
    ┌──────────────────┐      ┌──────────────────────┐
    │  Firebase        │      │  SQL.js              │
    │  Firestore       │      │  (In-memory SQLite   │
    │  (Persistence)   │      │   via WebAssembly)   │
    └──────────────────┘      └──────────────────────┘
```

---

## Core Files

### `src/db/setup/setupFirebaseDb.js`

The lowest layer — handles all Firebase and SQL.js operations directly.

#### `uploadSqliteConfig()`
- One-time setup function
- Reads `db-config.json` and writes it to `sqliteConfigs/mainConfig` in Firestore
- Only run when Firestore is empty

#### `initSQL()`
- Initializes SQL.js with WebAssembly (`sql-wasm.wasm` from `/public`)
- Cached after first call — won't re-initialize on subsequent calls

#### `getSqliteConfig()`
- Reads the full config document from Firestore
- Returns: `{ db: { name, queries }, datasetA: { name, queries }, ... }`

#### `addDataToFirestore(dbname, queries)`
- Appends SQL queries to a named database config in Firestore
- Used for: creating datasets, tables, inserting rows, defining schemas
- If the database key doesn't exist yet, it creates a new entry

```javascript
await addDataToFirestore('db', [
  "INSERT INTO Datasets (datasetName) VALUES ('myDataset')"
]);
```

#### `loadSqliteData()`
- Fetches config from Firestore
- Replays all stored queries into fresh in-memory SQL.js databases
- Returns: `{ db: Database, datasetA: Database, datasetB: Database }`

**Data flow:**
```
Firestore config → loadSqliteData() → in-memory SQLite databases
```

---

### `src/db/service/setupDatabases.js`

Business logic layer — wraps Firebase/SQL.js calls into domain operations.

#### `fetchDatasetsDB()`
- Loads the `db` database and queries the `Datasets` table
- Returns: `[{ datasetName: "datasetA" }, ...]`

#### `fetchTablesDB(datasetName)`
- Queries the `Tables` table filtered by dataset name
- Returns: `[{ tableName: "Employees" }, ...]`

#### `insertDataset(name)`
- Inserts a new row into `Datasets`
- Also creates an empty database entry in Firestore for the new dataset

#### `insertTable(tableName, datasetName)`
- Inserts a new row into `Tables` linking the table to its dataset

#### `getTableSchema(tableName, dbname)`
- Queries `sqlite_master` for the `CREATE TABLE` statement of a given table
- Falls back to `localStorage` if the in-memory database has no tables

#### `generateCreateTableSQL(dbname, tableName, columns)`
- Builds a `CREATE TABLE` SQL string from a column definition array
- Handles primary keys, foreign keys, and NOT NULL constraints
- Saves the generated SQL to Firestore via `addDataToFirestore()`

**Column definition shape:**
```javascript
{
  name: "column_name",
  type: "VARCHAR | INT | TEXT | ...",
  nullable: true | false,
  key: "none | primary | foreign",
  refTable: "referenced_table"  // only if key === 'foreign'
}
```

#### `fetchData(dbname, tableName)`
- Loads the target database and runs `SELECT * FROM tableName`
- Uses `stmt.prepare()` + `stmt.step()` to iterate rows
- Returns: array of row objects `[{ col1: val, col2: val, ... }]`

#### `insertData` (via context)
- Accepts a raw `INSERT INTO ...` SQL string
- Calls `addDataToFirestore(db, [query])` to persist the insert
- The insert is replayed on next `loadSqliteData()` call

---

### `src/db/service/context.js`

React Context provider — exposes all database operations to the component tree.

```javascript
const { allDataset, allTables, addDataset, addTable,
        getTable, createTable, fetchItems, insertData } = useAppContext();
```

| Function | Description |
|---|---|
| `allDataset()` | Fetch all datasets |
| `allTables(name)` | Fetch tables for a dataset |
| `addDataset(name)` | Create a new dataset |
| `addTable(name, db_name)` | Register a new table |
| `getTable(datasetName, tableName)` | Get schema — returns `{ exists, schema }` |
| `createTable(dbname, tableName, columns)` | Generate and save CREATE TABLE SQL |
| `fetchItems(dbname, table)` | Fetch all rows from a table |
| `insertData(db, query)` | Persist a raw INSERT SQL to Firestore |

A `refreshKey` state counter is incremented after mutations so memoized callbacks re-run on the next render cycle.

#### React Hooks Used in context.js

```javascript
import { createContext, useContext, useMemo, useState, useCallback } from "react"
```

**`createContext`**
Creates the context object itself — the "container" that holds the shared state. You call this once at the module level. Every component that wants to read from it must be wrapped inside its `Provider`.

```javascript
const AppContext = createContext();
const { Provider } = AppContext;
// Later: <Provider value={...}>{children}</Provider>
```

**`useState`**
Declares a reactive variable inside a component. When you call the setter, React re-renders the component. Used here for `refreshKey` — a counter that increments after every mutation (insert, create) to signal that dependent callbacks need to re-run.

```javascript
const [refreshKey, setRefreshKey] = useState(0);
// After a mutation:
setRefreshKey(prev => prev + 1);
```

**`useCallback`**
Memoizes a function so it isn't recreated on every render. Without it, every render would produce a new function reference, causing all child components that receive it as a prop to re-render unnecessarily. The second argument is the dependency array — the function only gets recreated when those values change. Here, `refreshKey` is a dependency so that after a mutation the callback picks up fresh data.

```javascript
const allDataset = useCallback(async () => {
    return await fetchDatasetsDB();
}, [refreshKey]); // re-created only when refreshKey changes
```

Use `useCallback` when: you pass a function as a prop to a child component, or when a function is a dependency of `useEffect` or `useMemo`.

**`useMemo`**
Memoizes a computed value (not a function). Used here to build the `value` object passed to the Provider. Without it, a new object would be created on every render, making React think the context value changed and re-rendering every consumer.

```javascript
const value = useMemo(() => ({
    allDataset, allTables, addDataset, addTable,
    getTable, createTable, fetchItems, insertData
}), [allDataset, allTables, addDataset, addTable, getTable, createTable, fetchItems, insertData]);
```

Use `useMemo` when: you're constructing an object or doing an expensive calculation that shouldn't repeat unless its inputs change.

**`useContext`**
Reads the current value from a context object. Used in the `useAppContext()` custom hook so any component can access the shared functions without prop drilling.

```javascript
export const useAppContext = () => {
    const context = useContext(AppContext);
    if (!context) throw new Error("useAppContext must be used inside an AppProvider");
    return context;
};
```

**Summary — purpose in this app:**

| Hook | Purpose in this App |
|---|---|
| `createContext` | Creates the "global container" where our database functions live. |
| `useState` | Manages the `refreshKey`. Incrementing this key signals React that the database state has changed. |
| `useCallback` | Memoizes functions like `allDataset`. This prevents child components from re-rendering unless the `refreshKey` changes, saving memory. |
| `useMemo` | Packages all functions into a single `value` object. It ensures the Provider only updates when a specific function dependency changes. |
| `useContext` | The "hook" used by components (via `useAppContext`) to grab the data without passing props. |

---

### `src/db/DatabaseManager.js`

React UI component — the visual interface for managing datasets, tables, schemas, and data.

#### Features
1. **Dataset panel** — dropdown to select + input to create new datasets
2. **Table panel** — shown after selecting a dataset; dropdown + create new table
3. **Schema editor** — column builder UI (shown when a table has no schema yet)
4. **Schema viewer** — displays the `CREATE TABLE` SQL for existing tables
5. **Fetch Data** — loads all rows from the selected table and renders them in a dynamic HTML table
6. **Insert Data** — text input accepting a raw `INSERT INTO` SQL statement; validates it starts with `INSERT INTO` before submitting

#### Fetch Data

Clicking "Fetch Data" calls `fetchItems(selectedDataset, selectedTable)` from context, which runs `SELECT * FROM tableName` via SQL.js and returns an array of row objects.

The result is rendered as a dynamic table — column headers are derived from `Object.keys(datas[0])` so the table adapts to any schema automatically:

```
User clicks "Fetch Data"
  → fetchData() calls fetchItems(selectedDataset, selectedTable)
  → context calls fetchData(dbname, tableName) in setupDatabases.js
  → loadSqliteData() rebuilds in-memory DB from Firestore queries
  → stmt.prepare("SELECT * FROM tableName") + stmt.step() iterates rows
  → returns [{ col1: val, col2: val, ... }, ...]
  → datas state is set → table renders with dynamic headers + rows
```

Example rendered output for `Employees`:

| employeeId | firstname | lastname | email | departmentId | salary |
|---|---|---|---|---|---|
| 1 | Aiden | Nguyen | aiden.nguyen@... | 3 | 98000 |
| 2 | Mia | Tran | mia.tran@... | 3 | 112500 |

Headers come from `Object.keys(datas[0])`, rows from `Object.values(row)` — no hardcoded column names needed.

#### Insert Data

Clicking "Insert Data" toggles a text input. The user types a raw SQL statement:

```
INSERT INTO Employees (firstname, lastname, email, departmentId, salary)
VALUES ('Jane', 'Doe', 'jane.doe@company.com', 3, 95000)
```

`handleInsertSubmit()` validates the input starts with `INSERT INTO`, then:

```
User submits SQL
  → handleInsertSubmit() validates prefix
  → insertData(selectedDataset, insertSQL) called from context
  → addDataToFirestore(db, [query]) appends query to Firestore
  → success/error message shown inline
  → next Fetch Data call will replay the new INSERT and show the row
```

The insert is not immediately visible — it's persisted to Firestore and replayed the next time `loadSqliteData()` is called (i.e., on the next Fetch Data click or page reload).

---

## Firestore Structure

```
sqliteConfigs/
  └── mainConfig              ← single document
      ├── db: {
      │     name: "db.sqlite",
      │     queries: [
      │       "CREATE TABLE IF NOT EXISTS 'Datasets' (...)",
      │       "CREATE TABLE IF NOT EXISTS 'Tables' (...)",
      │       "INSERT INTO Datasets ...",
      │       "INSERT INTO Tables ..."
      │     ]
      │   }
      ├── datasetA: {
      │     name: "datasetA.sqlite",
      │     queries: [
      │       "CREATE TABLE IF NOT EXISTS 'Departments' (...)",
      │       "CREATE TABLE IF NOT EXISTS 'Employees' (...)",
      │       "INSERT INTO Departments ...",
      │       "INSERT INTO Employees ..."
      │     ]
      │   }
      └── datasetB: {
            name: "datasetB.sqlite",
            queries: [
              "CREATE TABLE IF NOT EXISTS 'Customers' (...)",
              "CREATE TABLE IF NOT EXISTS 'Orders' (...)",
              "INSERT INTO Customers ...",
              "INSERT INTO Orders ..."
            ]
          }
```

All mutations (inserts, schema creation) append to the `queries` array. On every load, SQL.js replays the full query list from top to bottom to reconstruct the in-memory database state.

---

## Pre-loaded Datasets

### `db` (main registry database)
| Table | Purpose |
|---|---|
| `Datasets` | Registry of all dataset names |
| `Tables` | Registry of all table names linked to datasets |

### `datasetA`
| Table | Columns |
|---|---|
| `Departments` | departmentId, departmentName, location, budget |
| `Employees` | employeeId, firstname, lastname, email, departmentId, salary |

### `datasetB`
| Table | Columns |
|---|---|
| `Customers` | customerId, firstname, lastname, email, city, country |
| `Orders` | orderId, customerId, orderDate, totalAmount |

---

## Known Limitation: No Real-Time Sync

After mutations (insert, create), the UI does not auto-refresh because SQL.js databases are rebuilt in-memory on each `loadSqliteData()` call. The current workaround is a `refreshKey` counter in context that invalidates memoized callbacks, but a full browser refresh is sometimes still needed.

Potential fixes:
- Firestore real-time listeners (`onSnapshot`)
- React Query / SWR for cache invalidation
- Explicit reload triggers after every mutation

---

## File Structure

```
src/db/
├── setup/
│   ├── setupFirebaseDb.js     # Firebase + SQL.js integration, seed upload
│   └── db-config.json         # Initial seed data for Firestore
├── service/
│   ├── setupDatabases.js      # Business logic (fetch, insert, schema)
│   └── context.js             # React Context provider
├── DatabaseManager.js         # Main UI component
└── DatabaseManager.css        # Styles
```

---

## Dependencies

| Package | Role |
|---|---|
| `firebase` | Firestore persistence |
| `sql.js` | SQLite compiled to WebAssembly for browser execution |
| `react` | UI framework + Context API for state management |
