export function compareQueryResult(teacherQuery, studentQuery, isOrder = false, isAlias = false) {
  if (!teacherQuery || !studentQuery) return false;
  //get all columns in the result -> convert them to lower case and sort()
  const teacherResult = getResultSet(teacherQuery);
  const studentResult = getResultSet(studentQuery);
  if (!studentResult || !teacherResult) return false;
  const teacherColumns = teacherResult.columns.map(normalizeColumnName);
  const studentColumns = studentResult.columns.map(normalizeColumnName);
  //compare list of columns
  if (teacherColumns.length !== studentColumns.length) return false;
  if (isAlias) {
    const sortedTeacherColumns = teacherColumns.sort();
    const sortedStudentColumns = studentColumns.sort();
    const isMatchColumn = arrayMatch(
      sortedTeacherColumns,
      sortedStudentColumns,
    );
    if (!isMatchColumn) return false;
  }
  const teacherRows = teacherResult.values;
  const studentRows = studentResult.values;
  if (teacherRows.length !== studentRows.length) return false;
  return isOrder
    ? compareRowInOrder(teacherRows, studentRows)
    : compareRowsAsMultiset(teacherRows, studentRows);
}

function normalizeColumnName(columnName) {
  return columnName.toLowerCase();
}

function convertRowValueToString(row) {
  let newRow = JSON.stringify(row);
  return newRow.toLowerCase();
}

function getResultSet(result) {
  if (!result || result.length === 0) return null;
  
  const columns = result[0]?.lc;
  const values = result[0]?.values;
  if (!columns || !values) return null;
  return { columns, values };
}

function compareRowsAsMultiset(teacherRows, studentRows) {
  let teacherCounter = new Map();
  for (let i = 0; i < teacherRows.length; i++) {
    const teacherNewRow = convertRowValueToString(teacherRows[i]);
    teacherCounter.set(
      teacherNewRow,
      (teacherCounter.get(teacherNewRow) ?? 0) + 1,
    );
  }

  for (let i = 0; i < studentRows.length; i++) {
    const studentNewRow = convertRowValueToString(studentRows[i]);
    const count = teacherCounter.get(studentNewRow) ?? 0;
    if (count === 0) return false;
    else if (count > 1) {
      teacherCounter.set(studentNewRow, count - 1);
    } else {
      teacherCounter.delete(studentNewRow);
    }
  }
  return true;
}

function compareRowInOrder(teacherRows, studentRows) {
  for (let i = 0; i < teacherRows.length; i++) {
    const teacherNewRow = convertRowValueToString(teacherRows[i]);
    const studentNewRow = convertRowValueToString(studentRows[i]);
    if (teacherNewRow !== studentNewRow) {
      return false;
    }
  }
  return true;
}

function arrayMatch(teacherArr, studentArr) {
  if (teacherArr.length !== studentArr.length) return false;
  return teacherArr.every((value, index) => (value === studentArr[index]));
}
