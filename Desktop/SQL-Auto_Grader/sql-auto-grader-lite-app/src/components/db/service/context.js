import { createContext, useContext, useMemo, useCallback } from "react"
import { fetchTablesDB, fetchDatasetsDB, insertDataset, insertTable, getTableSchema, generateCreateTableSQL, fetchData, selectQuery, getTableInTable } from "./setupDatabases";
import { addDataToFirestore } from '../setup/setupFirebaseDb'
// Create a Context object to hold global data
// Creates the 'Context' object—the global storage container for your Todo data.
const AppContext = createContext();
// Extract the Provider component to wrap the app and share data
// Pulls out the 'Provider' component used to wrap the app and "broadcast" the data.
const { Provider } = AppContext;

const AppProvider = ({ children }) => {

    const allDataset = useCallback(async () => {
        const data = await fetchDatasetsDB()
        return data
    }, [])
    const allTables = useCallback(async (name) => {
        const data = await fetchTablesDB(name)
        return data
    }, [])

    const addDataset = useCallback(async (name) => {
        await insertDataset(name)
    }, [])
    const addTable = useCallback(async (name, db_name) => {
        await insertTable(name, db_name)
    }, [])

    const fetchItems = useCallback(async (dbname, query) => {//column, values
        const result = await fetchData(dbname, query)
        return result
    }, [])
    const insertData = useCallback(async (db, query) => {
        await addDataToFirestore(db, [query])
    }, [])
    const runSelectQuery = useCallback(async (dbname, query) => {//{1: name:'tham', lastname:'nt',...}
        const result = await selectQuery(dbname, query)        
        return result
    }, [])
    const getTable = useCallback(async (datasetName, tableName) => {
        const schema = await getTableSchema(tableName, datasetName);
        if (schema) {
            return { exists: true, schema };
        }
        return { exists: false, schema }
    }, [])
    const getTableSchemaInTable = useCallback(async (datasetName, tableName) => {
        const schema = await getTableInTable(tableName, datasetName);
        return schema;
    }, [])
    const createTable = useCallback(async (dbname, tableName, columns) => {
        const data = await generateCreateTableSQL(dbname, tableName, columns)
        return data
    }, [])
    // useMemo: Memoizes the data object so child components don't re-render 
    // unless the todoList or functions actually change.
    const value = useMemo(() => ({
        insertData,
        fetchItems,
        allDataset,
        allTables,
        addDataset,
        addTable,
        getTable,
        createTable,
        runSelectQuery,
        getTableSchemaInTable
        }), [insertData, fetchItems, allDataset, allTables, addDataset, addTable, getTable, createTable, runSelectQuery,getTableSchemaInTable])
    return <Provider value={value}>{children}</Provider>
}

/**
 * A custom hook that allows components to "consume" the Todo data.
 * It includes a safety check to ensure it's only used within an AppProvider.
 */
export const useAppContext = () => {
    const context = useContext(AppContext);

    if (!context) {
        throw new Error(
            "useAppContext must be used inside an AppProvider"
        );
    }

    return context;
}

export default AppProvider;