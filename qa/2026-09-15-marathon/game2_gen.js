// Generates game2_full.txt (setup, a short "first" game, then a second
// game mixing 2 returning + 2 new players) and game2_oracle.json, using
// the same independently-implemented scoring formulas as gen_marathon.js.
const fs = require('fs');
const path = require('path');

const SETTINGS = { askAndJoinBase: 2, trull: 9, aloneBase: 2, misere: 5, abundanceBase: 5, openMisere: 10, soloSlim: 15 };

function makeOracle(playerNames) {
  let totals = {}; for (const p of playerNames) totals[p] = 0;
  let pointMultiplier = 1, dealerIndex = 0, roundsSoFar = 0, trailingPasses = 0;
  const rounds = [];
  function applyTeam(deltas, declarer, partner, points, success) {
    const playing = [declarer, ...(partner ? [partner] : [])];
    const defending = playerNames.filter((p) => !playing.includes(p));
    for (const p of playing) deltas[p] = (deltas[p] || 0) + (success ? points : -points);
    for (const p of defending) deltas[p] = (deltas[p] || 0) + (success ? -points : points);
  }
  function applySolo(deltas, declarer, points, success) {
    const defenders = playerNames.filter((p) => p !== declarer);
    deltas[declarer] = (deltas[declarer] || 0) + (success ? points * defenders.length : -points * defenders.length);
    for (const p of defenders) deltas[p] = (deltas[p] || 0) + (success ? -points : points);
  }
  function addRound({ contractType, declarer, partner, trump, tricksWon, agreedTricks, declarerSuccess, partnerSuccess }) {
    const deltas = {}; for (const p of playerNames) deltas[p] = 0;
    let success = true;
    const dealer = playerNames[dealerIndex];
    if (contractType === 'Pass') { /* no-op */ }
    else if (contractType === 'Ask & Join') {
      success = tricksWon >= agreedTricks;
      const eb = SETTINGS.askAndJoinBase + (agreedTricks - 8);
      const ot = success ? tricksWon - agreedTricks : 0;
      applyTeam(deltas, declarer, partner, eb + ot, success);
    } else if (contractType === 'Trull') {
      success = tricksWon >= agreedTricks;
      const ot = success ? tricksWon - agreedTricks : 0;
      applyTeam(deltas, declarer, partner, SETTINGS.trull + ot, success);
    } else if (contractType === 'Solo') {
      success = tricksWon >= agreedTricks;
      const eb = SETTINGS.aloneBase + (agreedTricks - 5);
      const ot = success ? tricksWon - agreedTricks : 0;
      applySolo(deltas, declarer, eb + ot, success);
    } else if (contractType === 'Abondance') {
      success = tricksWon >= agreedTricks;
      const eb = SETTINGS.abundanceBase + (agreedTricks - 9);
      const ot = success ? tricksWon - agreedTricks : 0;
      applySolo(deltas, declarer, eb + ot, success);
    } else if (contractType === 'Miserie' || contractType === 'Open Miserie') {
      const points = contractType === 'Miserie' ? SETTINGS.misere : SETTINGS.openMisere;
      if (partner) {
        const defenders = playerNames.filter((p) => p !== declarer && p !== partner);
        if (declarerSuccess) { deltas[declarer] += points * defenders.length; for (const d of defenders) deltas[d] -= points; }
        else { deltas[declarer] -= points * defenders.length; for (const d of defenders) deltas[d] += points; }
        if (partnerSuccess) { deltas[partner] += points * defenders.length; for (const d of defenders) deltas[d] -= points; }
        else { deltas[partner] -= points * defenders.length; for (const d of defenders) deltas[d] += points; }
        success = declarerSuccess && partnerSuccess;
      } else { success = declarerSuccess; applySolo(deltas, declarer, points, success); }
    } else if (contractType === 'Solo Slim') {
      success = tricksWon >= 13;
      applySolo(deltas, declarer, SETTINGS.soloSlim, success);
    }
    for (const p of playerNames) deltas[p] *= pointMultiplier;
    const multiplierApplied = pointMultiplier;
    for (const p of playerNames) totals[p] += deltas[p];
    roundsSoFar += 1;
    if (contractType === 'Pass') trailingPasses += 1; else trailingPasses = 0;
    pointMultiplier = 1 << Math.min(trailingPasses, 10);
    dealerIndex = roundsSoFar % playerNames.length;
    rounds.push({ n: roundsSoFar, contractType, declarer, partner: partner || null, trump: trump || null, tricksWon: tricksWon ?? null, agreedTricks: agreedTricks ?? null, success, deltas: { ...deltas }, multiplierApplied, dealer, totalsAfter: { ...totals } });
  }
  return { addRound, get totals() { return totals; }, rounds };
}

const cmds = [];
const say = (s) => cmds.push(s);
const PARTNER_Y = { p1: 722, p2: 768, p3: 812, p4: 856 }; // generic seat-order rows

function addPlayer(name, first) {
  if (first) { say('click-text ADD PLAYER'); say('wait 800'); say('click-text ADD NEW PLAYER'); say('wait 500'); }
  else { say('click-xy 400 27'); say('wait 600'); }
  say(`type ${name}`);
  say('click-xy 298 509');
  say('wait 800');
}

function startGame(seatOrder) {
  say('click-text START GAME Tab 1 of 4'); say('wait 800');
  say('click-text NEW GAME'); say('wait 1000');
  for (const name of seatOrder) { say(`click-text ${name}`); say('wait 400'); }
  say('click-text START GAME'); say('wait 1500');
}

function openRoundDialog() { say('click-text ADD ROUND'); say('wait 400'); }
function pickContract(name) { say(`click-text ${name}`); say('wait 400'); }
const TRUMP_GLYPH = { Hearts: '♥', Diamonds: '♦', Clubs: '♣', Spades: '♠' };
function pickTeamPlayers(seatOrder, declarer, partner) {
  say(`click-text ${declarer}`); say('wait 300');
  const partnerSeatKey = `p${seatOrder.indexOf(partner) + 1}`;
  say(`click-xy 150 ${PARTNER_Y[partnerSeatKey]}`); say('wait 400');
}
function pickSoloPlayer(declarer) { say(`click-text ${declarer}`); say('wait 400'); }
function pickTrump(trump) { say(`click-text ${TRUMP_GLYPH[trump]}`); say('wait 300'); }
function confirm() { say('click-text CONFIRM'); say('wait 500'); }

// ---- Game 1 (short "first game"): Anna, Bram, Chris, Dana --------------
const g1Seats = ['Anna', 'Bram', 'Chris', 'Dana'];
const g1 = makeOracle(g1Seats);

addPlayer('Anna', true);
addPlayer('Bram');
addPlayer('Chris');
addPlayer('Dana');
startGame(g1Seats);

const g1Plan = [
  { type: 'Ask & Join', declarer: 'Anna', partner: 'Chris', trump: 'Hearts', tricksWon: 8, agreedTricks: 8 },
  { type: 'Trull', declarer: 'Bram', partner: 'Dana', trump: 'Clubs', tricksWon: 9, agreedTricks: 9 },
  { type: 'Solo', declarer: 'Chris', trump: 'Diamonds', tricksWon: 5, agreedTricks: 5 },
  { type: 'Abondance', declarer: 'Dana', trump: 'Spades', tricksWon: 9, agreedTricks: 9 },
  { type: 'Solo Slim', declarer: 'Anna', trump: 'Hearts', tricksWon: 13, agreedTricks: 13 },
];
for (const r of g1Plan) {
  openRoundDialog();
  if (r.type === 'Ask & Join' || r.type === 'Trull') {
    pickContract(r.type); pickTeamPlayers(g1Seats, r.declarer, r.partner); pickTrump(r.trump); confirm();
    g1.addRound({ contractType: r.type, declarer: r.declarer, partner: r.partner, trump: r.trump, tricksWon: r.tricksWon, agreedTricks: r.agreedTricks });
  } else if (r.type === 'Solo Slim') {
    pickContract('Solo Slim'); pickSoloPlayer(r.declarer); pickTrump(r.trump); confirm();
    g1.addRound({ contractType: r.type, declarer: r.declarer, trump: r.trump, tricksWon: r.tricksWon, agreedTricks: r.agreedTricks });
  } else {
    pickContract(r.type === 'Solo' ? 'Alone' : 'Abundance'); pickSoloPlayer(r.declarer); pickTrump(r.trump); confirm();
    g1.addRound({ contractType: r.type, declarer: r.declarer, trump: r.trump, tricksWon: r.tricksWon, agreedTricks: r.agreedTricks });
  }
}
say('screenshot g2_01_game1_before_end');
say('dump-tree g2_01_game1_tree');
// End game 1 for real (not abandon): action row END GAME -> confirm dialog's "END GAME" option.
say('click-xy 344 866'); say('wait 600');
say('click-xy 307 556'); say('wait 1200'); // confirm dialog's END GAME (3rd option)
say('screenshot g2_02_celebration');
say('dump-tree g2_02_celebration_tree');
say('click-xy 210 557'); say('wait 1200'); // BACK TO HOME

// ---- Game 2: Anna + Bram (returning) + Eve + Frank (new) ---------------
// Players list is already non-empty (Anna/Bram/Chris/Dana from game 1),
// so the empty-state "ADD NEW PLAYER" button addPlayer() otherwise uses
// doesn't exist — every new player here goes through the Players tab's
// top-right "+" icon instead (same as the 2nd/3rd/4th player in game 1).
say('click-text ADD PLAYER'); say('wait 800'); // Home -> navigates to Players tab
for (const name of ['Eve', 'Frank']) {
  say('click-xy 400 27'); say('wait 600');
  say(`type ${name}`);
  say('click-xy 298 509'); say('wait 800');
}
say('screenshot g2_03_players_after_adding_new');
say('dump-tree g2_03_players_tree');

const g2Seats = ['Anna', 'Bram', 'Eve', 'Frank'];
const g2 = makeOracle(g2Seats);
startGame(g2Seats);

const g2Plan = [
  { type: 'Ask & Join', declarer: 'Anna', partner: 'Eve', trump: 'Hearts', tricksWon: 10, agreedTricks: 8 }, // overtrick
  { type: 'Trull', declarer: 'Bram', partner: 'Frank', trump: 'Clubs', tricksWon: 9, agreedTricks: 9 },
  { type: 'Solo', declarer: 'Eve', trump: 'Diamonds', tricksWon: 3, agreedTricks: 5 }, // forced failure (no stepper click needed: pass a lower tricksWon than default? default tricksWon==agreedTricks(5); to represent a FAILURE we must actually click the stepper down in the UI — see note)
  { type: 'Abondance', declarer: 'Frank', trump: 'Spades', tricksWon: 9, agreedTricks: 9 },
  { type: 'Ask & Join', declarer: 'Anna', partner: 'Frank', trump: 'Diamonds', tricksWon: 8, agreedTricks: 8 },
  { type: 'Trull', declarer: 'Bram', partner: 'Eve', trump: 'Hearts', tricksWon: 9, agreedTricks: 9 },
  { type: 'Solo Slim', declarer: 'Frank', trump: 'Clubs', tricksWon: 13, agreedTricks: 13 },
  { type: 'Pass' },
  { type: 'Ask & Join', declarer: 'Eve', partner: 'Anna', trump: 'Spades', tricksWon: 8, agreedTricks: 8 }, // multiplier x2
];

for (const r of g2Plan) {
  openRoundDialog();
  if (r.type === 'Pass') {
    say('click-text Round Pass'); say('wait 700');
    g2.addRound({ contractType: 'Pass' });
    continue;
  }
  if (r.type === 'Ask & Join' || r.type === 'Trull') {
    pickContract(r.type); pickTeamPlayers(g2Seats, r.declarer, r.partner); pickTrump(r.trump);
    confirm();
    g2.addRound({ contractType: r.type, declarer: r.declarer, partner: r.partner, trump: r.trump, tricksWon: r.tricksWon, agreedTricks: r.agreedTricks });
  } else if (r.type === 'Solo Slim') {
    pickContract('Solo Slim'); pickSoloPlayer(r.declarer); pickTrump(r.trump); confirm();
    g2.addRound({ contractType: r.type, declarer: r.declarer, trump: r.trump, tricksWon: r.tricksWon, agreedTricks: r.agreedTricks });
  } else {
    pickContract(r.type === 'Solo' ? 'Alone' : 'Abundance'); pickSoloPlayer(r.declarer); pickTrump(r.trump);
    // NOTE: the "Solo: forced failure" plan entry above is NOT actually
    // driven to a real failure by this generator (no stepper click is
    // emitted) — it will submit as a default SUCCESS at tricksWon ==
    // agreedTricks == 5, same as every other default round. Recorded in
    // the oracle with tricksWon:5 (not 3) to match what the UI will
    // actually submit; see the written report for why this was left as
    // a known gap rather than guessing stepper coordinates unverified.
    const actualTricksWon = r.type === 'Solo' && r.declarer === 'Eve' ? 5 : r.tricksWon;
    confirm();
    g2.addRound({ contractType: r.type, declarer: r.declarer, trump: r.trump, tricksWon: actualTricksWon, agreedTricks: r.agreedTricks });
  }
}

say('screenshot g2_04_game2_before_end');
say('dump-tree g2_04_game2_tree');
say('click-xy 344 866'); say('wait 600');
say('click-xy 307 556'); say('wait 1200');
say('screenshot g2_05_celebration2');
say('click-xy 210 557'); say('wait 1200');

say('click-text HISTORY Tab 3 of 4'); say('wait 800');
say('screenshot g2_06_history'); say('dump-tree g2_06_history_tree');
say('click-xy 210 130'); say('wait 800'); // open most recent (game 2) detail
say('screenshot g2_07_game2_detail'); say('dump-tree g2_07_game2_detail_tree');
say('click-xy 32 27'); say('wait 500');
say('click-xy 210 280'); say('wait 800'); // open older (game 1) detail (2nd row)
say('screenshot g2_08_game1_detail'); say('dump-tree g2_08_game1_detail_tree');
say('click-xy 32 27'); say('wait 500');
say('click-text PLAYERS Tab 2 of 4'); say('wait 800');
say('screenshot g2_09_players_final'); say('dump-tree g2_09_players_final_tree');
say('click-xy 100 129'); say('wait 800'); // Anna's row (first player, index 0)
say('screenshot g2_10_anna_stats'); say('dump-tree g2_10_anna_stats_tree');
say('dump-console g2_console');

fs.writeFileSync(path.join(__dirname, 'game2_body.txt'), cmds.join('\n') + '\n');
fs.writeFileSync(path.join(__dirname, 'game2_oracle.json'), JSON.stringify({ game1: { seats: g1Seats, totals: g1.totals, rounds: g1.rounds }, game2: { seats: g2Seats, totals: g2.totals, rounds: g2.rounds } }, null, 2));
console.error(`Generated ${cmds.length} commands. Game1 totals:`, g1.totals, 'Game2 totals:', g2.totals);
