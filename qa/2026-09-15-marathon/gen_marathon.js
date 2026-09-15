// Generates the driver.js script + a parallel "oracle" expected-state log
// for a 100-round marathon game, by independently re-implementing the exact
// scoring formulas from lib/providers/game_provider.dart (as of commit
// 9a88740 — trull base 9). This lets us predict, before ever touching the
// browser, exactly what every round's delta and every running total should
// be, then compare that oracle against what the real UI actually produces.
//
// Usage: node gen_marathon.js > marathon_script.txt
// Writes marathon_oracle.json alongside it (same directory as this file).

const fs = require('fs');
const path = require('path');

const PLAYERS = ['Anna', 'Bram', 'Chris', 'Dana']; // seat order at game start
const SETTINGS = { askAndJoinBase: 2, trull: 9, aloneBase: 2, misere: 5, abundanceBase: 5, openMisere: 10, soloSlim: 15 };

// ---- oracle state -----------------------------------------------------
let totals = { Anna: 0, Bram: 0, Chris: 0, Dana: 0 };
let pointMultiplier = 1;
let dealerIndex = 0;
let roundsSoFar = 0; // real Round objects added (Pass included)
let trailingPasses = 0;
const oracleRounds = []; // { n, contractType, declarer, partner, trump, tricksWon, agreedTricks, success, deltas (post-multiplier), multiplierApplied, dealer }

function applyTeam(deltas, declarer, partner, points, success) {
  const playing = [declarer, ...(partner ? [partner] : [])];
  const defending = PLAYERS.filter((p) => !playing.includes(p));
  for (const p of playing) deltas[p] = (deltas[p] || 0) + (success ? points : -points);
  for (const p of defending) deltas[p] = (deltas[p] || 0) + (success ? -points : points);
}

function applySolo(deltas, declarer, points, success) {
  const defenders = PLAYERS.filter((p) => p !== declarer);
  deltas[declarer] = (deltas[declarer] || 0) + (success ? points * defenders.length : -points * defenders.length);
  for (const p of defenders) deltas[p] = (deltas[p] || 0) + (success ? -points : points);
}

// Records one round in the oracle, applying pointMultiplier exactly as
// GameProvider.addRound does (base deltas computed first, then scaled),
// and recomputes dealerIndex/pointMultiplier the way recomputeFromRounds
// does: purely from the round list (trailing-Pass streak), not incrementally.
function addRound({ contractType, declarer, partner, trump, tricksWon, agreedTricks, declarerSuccess, partnerSuccess, miseriePlayerCount }) {
  const deltas = { Anna: 0, Bram: 0, Chris: 0, Dana: 0 };
  let success = true;
  const dealer = PLAYERS[dealerIndex];

  if (contractType === 'Pass') {
    // no-op deltas
  } else if (contractType === 'Ask & Join') {
    success = tricksWon >= agreedTricks;
    const escalatedBase = SETTINGS.askAndJoinBase + (agreedTricks - 8);
    const overtricks = success ? tricksWon - agreedTricks : 0;
    applyTeam(deltas, declarer, partner, escalatedBase + overtricks, success);
  } else if (contractType === 'Trull') {
    success = tricksWon >= agreedTricks;
    const overtricks = success ? tricksWon - agreedTricks : 0;
    applyTeam(deltas, declarer, partner, SETTINGS.trull + overtricks, success);
  } else if (contractType === 'Solo') {
    success = tricksWon >= agreedTricks;
    const escalatedBase = SETTINGS.aloneBase + (agreedTricks - 5);
    const overtricks = success ? tricksWon - agreedTricks : 0;
    applySolo(deltas, declarer, escalatedBase + overtricks, success);
  } else if (contractType === 'Abondance') {
    success = tricksWon >= agreedTricks;
    const escalatedBase = SETTINGS.abundanceBase + (agreedTricks - 9);
    const overtricks = success ? tricksWon - agreedTricks : 0;
    applySolo(deltas, declarer, escalatedBase + overtricks, success);
  } else if (contractType === 'Miserie' || contractType === 'Open Miserie') {
    const points = contractType === 'Miserie' ? SETTINGS.misere : SETTINGS.openMisere;
    if (partner) {
      const defenders = PLAYERS.filter((p) => p !== declarer && p !== partner);
      if (declarerSuccess) { deltas[declarer] = (deltas[declarer] || 0) + points * defenders.length; for (const d of defenders) deltas[d] = (deltas[d] || 0) - points; }
      else { deltas[declarer] = (deltas[declarer] || 0) - points * defenders.length; for (const d of defenders) deltas[d] = (deltas[d] || 0) + points; }
      if (partnerSuccess) { deltas[partner] = (deltas[partner] || 0) + points * defenders.length; for (const d of defenders) deltas[d] = (deltas[d] || 0) - points; }
      else { deltas[partner] = (deltas[partner] || 0) - points * defenders.length; for (const d of defenders) deltas[d] = (deltas[d] || 0) + points; }
      success = declarerSuccess && partnerSuccess;
    } else {
      success = declarerSuccess;
      applySolo(deltas, declarer, points, success);
    }
  } else if (contractType === 'Solo Slim') {
    success = tricksWon >= 13;
    applySolo(deltas, declarer, SETTINGS.soloSlim, success);
  }

  for (const p of PLAYERS) deltas[p] = (deltas[p] || 0) * pointMultiplier;
  const multiplierApplied = pointMultiplier;
  for (const p of PLAYERS) totals[p] += deltas[p];
  roundsSoFar += 1;

  if (contractType === 'Pass') trailingPasses += 1; else trailingPasses = 0;
  const exponent = Math.min(trailingPasses, 10);
  pointMultiplier = 1 << exponent;
  dealerIndex = roundsSoFar % PLAYERS.length;

  oracleRounds.push({
    n: roundsSoFar, contractType, declarer, partner: partner || null, trump: trump || null,
    tricksWon: tricksWon ?? null, agreedTricks: agreedTricks ?? null, success, deltas: { ...deltas },
    multiplierApplied, dealer, totalsAfter: { ...totals }, pointMultiplierAfter: pointMultiplier, dealerIndexAfter: dealerIndex,
  });
  return { deltas, success };
}

function undoLast() {
  const removed = oracleRounds.pop();
  roundsSoFar -= 1;
  // recompute purely from remaining rounds, mirroring recomputeFromRounds
  totals = { Anna: 0, Bram: 0, Chris: 0, Dana: 0 };
  for (const r of oracleRounds) for (const p of PLAYERS) totals[p] += r.deltas[p];
  dealerIndex = roundsSoFar % PLAYERS.length;
  trailingPasses = 0;
  for (let i = oracleRounds.length - 1; i >= 0; i--) { if (oracleRounds[i].contractType === 'Pass') trailingPasses++; else break; }
  pointMultiplier = 1 << Math.min(trailingPasses, 10);
  return removed;
}

// ---- UI command emission ----------------------------------------------
const cmds = [];
const say = (s) => cmds.push(s);
const oracleUndoLog = [];
const oracleDeleteLog = [];

// Fixed partner-row y-coordinates in the "Select Players" step, in the
// player order Anna/Bram/Chris/Dana — validated empirically in earlier
// sessions (round_setup_dialog.dart's partner list order never changes,
// only whether a given row is enabled).
const PARTNER_Y = { Anna: 722, Bram: 768, Chris: 812, Dana: 856 };
// Validated empirically (probe_miserie2b.txt): the Miserie 2-player
// layout's "Player 2" rows land at the same y-coordinates as the
// declarer/partner rows in every other contract's players step — the
// extra "1 Player / 2 Players" toggle row doesn't push things down
// further than expected.
const MISERIE_PARTNER_Y = PARTNER_Y;
const MISERIE_2P_TOGGLE_XY = [303, 638];

const TRUMP_GLYPH = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };

function openRoundDialog() { say('click-text ADD ROUND'); say('wait 350'); }

function pickContract(name) { say(`click-text ${name}`); say('wait 350'); }

function pickTeamPlayers(declarer, partner) {
  say(`click-text ${declarer}`);
  say('wait 300');
  say(`click-xy 150 ${PARTNER_Y[partner]}`);
  say('wait 350');
}

function pickSoloPlayer(declarer) { say(`click-text ${declarer}`); say('wait 350'); }

function pickTrump(trump) { say(`click-text ${TRUMP_GLYPH[trump]}`); say('wait 300'); }

// Adjust the "tricks won" (bottom) stepper by delta steps (+ or -).
function bumpTricksWon(delta) {
  const btnX = delta > 0 ? 265 : 155;
  for (let i = 0; i < Math.abs(delta); i++) { say(`click-xy ${btnX} 778`); say('wait 150'); }
}
// Adjust the "negotiated tricks" (top) stepper.
function bumpNegotiated(delta) {
  const btnX = delta > 0 ? 265 : 155;
  for (let i = 0; i < Math.abs(delta); i++) { say(`click-xy ${btnX} 692`); say('wait 150'); }
}

function confirm() { say('click-text CONFIRM'); say('wait 500'); }
// The confirm button's label varies (ACHIEVEMENT/FAILURE/etc.) but always
// starts with "CONFIRM" per _confirmButtonLabel — matching that prefix
// avoids needing to know success/fail ahead of the click.

function pickMiseriePlayers1(declarer) { say(`click-text ${declarer}`); say('wait 350'); }
function pickMiseriePlayers2(declarer, partner) {
  say(`click-xy ${MISERIE_2P_TOGGLE_XY[0]} ${MISERIE_2P_TOGGLE_XY[1]}`); // "2 Players" toggle
  say('wait 300');
  say(`click-text ${declarer}`);
  say('wait 300');
  say(`click-xy 150 ${MISERIE_PARTNER_Y[partner]}`);
  say('wait 350');
}
// Every Miserie/Open Miserie round in this marathon uses the default
// success toggle (declarer/partner both succeed) — no extra clicks
// needed, so there is no analogous setMiserieSuccess(false, ...) path
// exercised here. Mixed-success Miserie is already covered exhaustively
// by unit tests (game_provider_test.dart's "Double Miserie" group) and
// was exercised once via this same UI in an earlier validation session.

// ---- round plan ---------------------------------------------------------
// 100 rounds, round-robin through every contract type with rotating
// declarer/partner, a controlled 3x-Rondpas multiplier-stacking segment,
// and a couple of forced failures/overtricks (tricksWon nudged via the
// already-validated stepper coordinates). Undo and per-round delete are
// deliberately NOT exercised mid-marathon: both are already validated
// (this session and unit tests) and each depends on a screen-relative
// coordinate that shifts with on-screen content — an acceptable risk for
// a short, watched script, not for 100 unattended rounds where a single
// missed click cascades into every subsequent command clicking the wrong
// thing with no chance to notice until the very end. They get their own
// small, closely-watched check after the marathon instead.
const cycle = ['Ask & Join', 'Trull', 'Solo', 'Abondance', 'Miserie1', 'Miserie2', 'Solo Slim', 'OpenMiserie1'];
const TRUMPS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

let declarerCursor = 0;
function nextDeclarer() { const p = PLAYERS[declarerCursor % 4]; declarerCursor++; return p; }
function partnerOf(declarer) { const idx = (PLAYERS.indexOf(declarer) + 2) % 4; return PLAYERS[idx]; }

const plan = []; // sequence of round descriptors, consumed in order
let roundCounter = 0;
while (roundCounter < 100) {
  // Deliberate multiplier-stacking segment right after round 40: 3 passes
  // (x2 -> x4 -> x8) then one real contract to see the stacked multiplier
  // applied, then it resets.
  if (roundCounter === 40) {
    plan.push({ kind: 'pass' }); roundCounter++;
    plan.push({ kind: 'pass' }); roundCounter++;
    plan.push({ kind: 'pass' }); roundCounter++;
    continue;
  }
  // One forced Ask & Join FAILURE around round 55 (tricksWon nudged below
  // agreedTricks).
  if (roundCounter === 55) {
    plan.push({ kind: 'contract', type: 'Ask & Join', forceFail: true }); roundCounter++;
    continue;
  }
  // One forced Solo overtrick around round 65.
  if (roundCounter === 65) {
    plan.push({ kind: 'contract', type: 'Solo', overtrick: 1 }); roundCounter++;
    continue;
  }
  const type = cycle[roundCounter % cycle.length];
  plan.push({ kind: 'contract', type });
  roundCounter++;
}

let trumpCursor = 0;
function nextTrump() { const t = TRUMPS[trumpCursor % 4]; trumpCursor++; return t; }

for (const step of plan) {
  if (step.kind === 'pass') {
    openRoundDialog();
    say('click-text Round Pass');
    say('wait 700');
    addRound({ contractType: 'Pass' });
    continue;
  }

  const type = step.type;
  if (type === 'Ask & Join' || type === 'Trull') {
    const declarer = nextDeclarer();
    const partner = partnerOf(declarer);
    const trump = nextTrump();
    const required = type === 'Ask & Join' ? 8 : 9;
    let tricksWon = required;
    openRoundDialog();
    pickContract(type);
    pickTeamPlayers(declarer, partner);
    pickTrump(trump);
    if (step.forceFail) { bumpTricksWon(-2); tricksWon = required - 2; }
    confirm();
    addRound({ contractType: type, declarer, partner, trump, tricksWon, agreedTricks: required });
  } else if (type === 'Solo' || type === 'Abondance') {
    const declarer = nextDeclarer();
    const trump = nextTrump();
    const required = type === 'Solo' ? 5 : 9;
    let tricksWon = required;
    openRoundDialog();
    pickContract(type === 'Solo' ? 'Alone' : 'Abundance');
    pickSoloPlayer(declarer);
    pickTrump(trump);
    if (step.overtrick) { bumpTricksWon(step.overtrick); tricksWon = required + step.overtrick; }
    confirm();
    addRound({ contractType: type, declarer, trump, tricksWon, agreedTricks: required });
  } else if (type === 'Solo Slim') {
    const declarer = nextDeclarer();
    const trump = nextTrump();
    openRoundDialog();
    pickContract('Solo Slim');
    pickSoloPlayer(declarer);
    pickTrump(trump);
    confirm();
    addRound({ contractType: type, declarer, trump, tricksWon: 13, agreedTricks: 13 });
  } else if (type === 'Miserie1') {
    const declarer = nextDeclarer();
    openRoundDialog();
    pickContract('Misery');
    pickMiseriePlayers1(declarer);
    confirm();
    addRound({ contractType: 'Miserie', declarer, declarerSuccess: true });
  } else if (type === 'Miserie2') {
    const declarer = nextDeclarer();
    const partner = partnerOf(declarer);
    openRoundDialog();
    pickContract('Misery');
    pickMiseriePlayers2(declarer, partner);
    confirm();
    addRound({ contractType: 'Miserie', declarer, partner, declarerSuccess: true, partnerSuccess: true });
  } else if (type === 'OpenMiserie1') {
    const declarer = nextDeclarer();
    openRoundDialog();
    pickContract('Open Misery');
    pickMiseriePlayers1(declarer);
    confirm();
    addRound({ contractType: 'Open Miserie', declarer, declarerSuccess: true });
  }

  // periodic checkpoint: screenshot + full tree dump + a progress marker
  // printed to stdout, so a still-running (or crashed) marathon can be
  // checked on without waiting for the final dump.
  if (roundsSoFar % 10 === 0) {
    say(`screenshot marathon_r${roundsSoFar}`);
    say(`dump-tree marathon_r${roundsSoFar}_tree`);
  }
}

say('screenshot marathon_final');
say('dump-tree marathon_final_tree');
say('dump-console marathon_console');

fs.writeFileSync(path.join(__dirname, 'marathon_script.txt'), cmds.join('\n') + '\n');
fs.writeFileSync(
  path.join(__dirname, 'marathon_oracle.json'),
  JSON.stringify({ finalTotals: totals, finalMultiplier: pointMultiplier, finalDealerIndex: dealerIndex, roundsRecorded: roundsSoFar, rounds: oracleRounds }, null, 2),
);
console.error(`Generated ${cmds.length} UI commands for ${roundsSoFar} oracle rounds.`);
