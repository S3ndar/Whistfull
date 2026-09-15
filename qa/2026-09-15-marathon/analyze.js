// Parses a dump-tree JSON (Flutter accessibility snapshot) and extracts
// round-history row strings like:
//   "6 ♠ Ask & Join Bram & Dana · Anna -4 Bram +4 Chris -4 Dana +4 SUCCEEDED"
// plus standings rows, suit-strip counts, and header text — then diffs
// round count and final per-player totals against an oracle JSON.
const fs = require('fs');

function walk(node, out) {
  if (!node) return;
  if (node.name) out.push(node.name);
  if (node.children) for (const c of node.children) walk(c, out);
}

function loadTreeTexts(file) {
  const tree = JSON.parse(fs.readFileSync(file, 'utf8'));
  const out = [];
  walk(tree, out);
  return out;
}

// A round row's accessible name is one long string containing " · " and
// ending in SUCCEEDED/FAILED (Pass rows look different, no badge).
function extractRoundRows(texts) {
  return texts.filter((t) => / · /.test(t) && /(SUCCEEDED|FAILED)$/.test(t));
}
function extractPassRows(texts) {
  return texts.filter((t) => /Round Pass/.test(t) && t.includes('Dealer:'));
}
function parsePassRow(text) {
  const m = text.match(/^(\d+)\s+Round Pass\s+Dealer:\s+(\w+)$/);
  if (!m) return { raw: text, parsed: false };
  return { raw: text, parsed: true, n: parseInt(m[1], 10), contractName: 'Pass', dealer: m[2] };
}

const KNOWN_CONTRACTS = ['Ask & Join', 'Trull', 'Alone', 'Abundance', 'Misery', 'Open Misery', 'Solo Slim'];

function parseRoundRow(text) {
  // "<n> [<glyph>] <ContractName> <who> · <deltas...> <SUCCEEDED|FAILED>"
  const head = text.match(/^(\d+)\s+(?:([♠♥♦♣])\s+)?(.*)$/);
  if (!head) return { raw: text, parsed: false };
  const [, n, glyph, rest] = head;
  const contractName = KNOWN_CONTRACTS.find((c) => rest.startsWith(c + ' '));
  if (!contractName) return { raw: text, parsed: false };
  const afterContract = rest.slice(contractName.length).trim();
  const m = afterContract.match(/^(.+?)\s+·\s+(.+?)\s+(SUCCEEDED|FAILED)$/);
  if (!m) return { raw: text, parsed: false };
  const [, who, deltasStr, result] = m;
  const deltaPairs = [...deltasStr.matchAll(/([A-Za-z]+)\s+([+-]\d+)/g)].map((mm) => [mm[1], parseInt(mm[2], 10)]);
  return { raw: text, parsed: true, n: parseInt(n, 10), glyph, contractName, who, deltas: Object.fromEntries(deltaPairs), result };
}

module.exports = { loadTreeTexts, extractRoundRows, extractPassRows, parseRoundRow, parsePassRow };

if (require.main === module) {
  const file = process.argv[2];
  const texts = loadTreeTexts(file);
  const rows = extractRoundRows(texts).map(parseRoundRow);
  const passes = extractPassRows(texts);
  console.log(`Round rows found: ${rows.length}, Pass rows found: ${passes.length}`);
  console.log('First 3:', JSON.stringify(rows.slice(0, 3), null, 1));
  console.log('Last 3:', JSON.stringify(rows.slice(-3), null, 1));
}
