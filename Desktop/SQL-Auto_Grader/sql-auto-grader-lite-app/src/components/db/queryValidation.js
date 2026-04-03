//Validate Select query only

import { SQL_KEYWORDS } from "./common";
export function isSelectQuery(query) {
  //check query is empty or not a string
  if (!query || typeof query !== "string") return false;
  const trimedQuery = query.trim();
  const isSelectFormat = /^select\b/i.test(trimedQuery);
  return isSelectFormat;
}

export function normalizeQuery(query) {
  if (typeof query !== "string") return "";

  const keywordPattern = new RegExp(`\\b(${SQL_KEYWORDS.join("|")})\\b`, "gi");
  const lowerKeywords = (segment) =>
    segment.replace(keywordPattern, (token) => token.toLowerCase());

  // Normalize SQL syntax only; keep quoted literals untouched
  const parts = query.split(/('(?:''|[^'])*'|"(?:[^"]|"")*")/);

  return parts
    .map((part, index) => (index % 2 === 0 ? lowerKeywords(part) : part))
    .join("");
}
