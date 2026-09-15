const fs = require('fs');
const path = require('path');
const { loadTreeTexts, extractRoundRows, extractPassRows, parseRoundRow, parsePassRow } = require('./analyze.js');

const oracle = JSON.parse(fs.readFileSync(path.join(__dirname, 'marathon_oracle.json'), 'utf8'));
const byN = {};
for (const r of oracle.rounds) byN[r.n] = r;

const checkpoints = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
const actualByN = {};
for (const cp of checkpoints) {
  const texts = loadTreeTexts(path.join(__dirname, 'shots', `marathon_r${cp}_tree.json`));
  for (const row of extractRoundRows(texts).map(parseRoundRow)) if (row.parsed) actualByN[row.n] = row;
  for (const row of extractPassRows(texts).map(parsePassRow)) if (row.parsed) actualByN[row.n] = row;
}

const results = { matched: [], contractMismatch: [], deltaMismatch: [], missingFromUI: [], totalRoundsInOracle: oracle.rounds.length, totalRoundsCapturedFromUI: Object.keys(actualByN).length };

for (let n = 1; n <= 100; n++) {
  const exp = byN[n];
  const act = actualByN[n];
  if (!act) { results.missingFromUI.push(n); continue; }
  if (act.contractName === 'Pass') {
    if (exp.contractType === 'Pass') results.matched.push(n); else results.contractMismatch.push({ n, expected: exp.contractType, actual: 'Pass', actualRaw: act.raw });
    continue;
  }
  if (!exp) { results.contractMismatch.push({ n, expected: '(none)', actualRaw: act.raw }); continue; }
  // The delta signature is the real ground truth here — it's what the
  // scoring engine actually computed, independent of my own regex's
  // trouble splitting a multi-word contract name ("Ask & Join", "Solo
  // Slim", "Open Misery") apart from a multi-word "who" field. A round
  // is considered correctly executed iff its multiset of {player: delta}
  // pairs matches the oracle's for that round number exactly.
  const expDeltaStr = Object.entries(exp.deltas).map(([k, v]) => `${k}${v >= 0 ? '+' : ''}${v}`).sort().join(',');
  const actDeltaStr = Object.entries(act.deltas).map(([k, v]) => `${k}${v >= 0 ? '+' : ''}${v}`).sort().join(',');
  if (expDeltaStr === actDeltaStr) results.matched.push(n);
  else results.deltaMismatch.push({ n, expectedContract: exp.contractType, expectedDeltas: exp.deltas, actualRaw: act.raw, actualDeltas: act.deltas });
}

console.log(JSON.stringify({
  totalRoundsInOracle: results.totalRoundsInOracle,
  totalRoundsCapturedFromUI: results.totalRoundsCapturedFromUI,
  matchedCount: results.matched.length,
  contractMismatchCount: results.contractMismatch.length,
  deltaMismatchCount: results.deltaMismatch.length,
  missingFromUICount: results.missingFromUI.length,
  contractMismatches: results.contractMismatch,
  deltaMismatches: results.deltaMismatch,
  missingFromUI: results.missingFromUI,
}, null, 2));

fs.writeFileSync(path.join(__dirname, 'marathon_comparison.json'), JSON.stringify(results, null, 2));
