'use strict';

const SIZE = 15;
const CELL = 36;
const PAD = 22;
const RADIUS = 14;
const BOARD_PX = PAD * 2 + CELL * (SIZE - 1);

const ALGO_NAMES = {
  easy: '人机 · Easy',
  medium: '人机 · Medium',
  hard: '人机 · Hard',
  expert: '人机 · Expert',
  joseki: '人机 · Joseki'
};

let state = null;
let busy = false;
let currentMode = 'ai';
let currentDiff = 'easy';
let hintPos = null;
let moveHistory = [];
let reviewState = { open: false, index: 0 };
let pulseFrames = [];
let dropFrames = [];
let rafId = null;
let flashTimer = null;
let resultTimer = null;

const canvas = document.getElementById('board');
const ctx = canvas.getContext('2d');
canvas.width = BOARD_PX;
canvas.height = BOARD_PX;

function showView(id) {
  document.querySelectorAll('.view').forEach(view => view.classList.remove('active', 'slide-in'));
  const target = document.getElementById(id);
  target.classList.add('active', 'slide-in');
}

function toggleDiffPanel() {
  const panel = document.getElementById('diff-panel');
  const chevron = document.getElementById('diff-chevron');
  const open = panel.classList.toggle('open');
  chevron.classList.toggle('rotated', open);
}

function goHome() {
  clearResultTimer();
  hideResult();
  closeReview();
  setFlash('', 0);
  showView('view-home');
}

async function startGame(mode, diff) {
  if (busy) return;

  currentMode = mode;
  currentDiff = diff;
  hintPos = null;
  hideResult();
  closeReview();
  clearResultTimer();
  setFlash('', 0);
  showView('view-game');

  document.getElementById('mode-label').textContent =
    mode === 'pvp' ? '本地双人' : (ALGO_NAMES[diff] || diff);
  showAlgoDetail(mode, diff);

  setLoading(true);
  try {
    const data = await api(`/api/new?mode=${mode}&diff=${diff}`);
    applyState(data, { action: 'new' });
  } finally {
    setLoading(false);
  }
}

function showAlgoDetail(mode, diff) {
  document.querySelectorAll('.algo-detail-block').forEach(block => block.classList.remove('visible'));
  const key = mode === 'pvp' ? 'pvp' : diff;
  const target = document.querySelector(`.algo-detail-block[data-diff="${key}"]`);
  if (target) target.classList.add('visible');
}

async function api(url) {
  const res = await fetch(url);
  return res.json();
}

async function doMove(row, col) {
  if (busy || !state || state.gameOver || reviewState.open) return;
  if (state.mode === 'ai' && state.currentPlayer !== 1) return;

  setLoading(true);
  try {
    const data = await api(`/api/move?row=${row}&col=${col}`);
    applyState(data, { action: 'move', moveRow: row, moveCol: col });
  } finally {
    setLoading(false);
  }
}

async function handleUndo() {
  if (busy || !state || reviewState.open) return;

  setLoading(true);
  try {
    const data = await api('/api/undo');
    applyState(data, { action: 'undo' });
  } finally {
    setLoading(false);
  }
}

async function handleHint() {
  if (busy || !state || reviewState.open) return;
  if (!isHumanTurn(state)) return;

  setLoading(true);
  try {
    const data = await api('/api/hint');
    if (data.ok) {
      hintPos = { row: data.row, col: data.col };
      setFlash('已标出建议落点');
      updateButtons();
      startRaf();
    } else {
      setFlash(data.message || '当前无法提供帮助');
    }
  } finally {
    setLoading(false);
  }
}

function openReview() {
  if (!state || !state.gameOver || moveHistory.length <= 1) {
    setFlash('终局后才能进入复盘');
    return;
  }

  clearResultTimer();
  hideResult();
  reviewState.open = true;
  reviewState.index = moveHistory.length - 1;
  document.getElementById('review-panel').classList.remove('hidden');
  updateReviewUI();
  updateButtons();
  startRaf();
}

function closeReview() {
  clearResultTimer();
  hideResult();
  reviewState.open = false;
  document.getElementById('review-panel').classList.add('hidden');
  updateButtons();
  startRaf();
}

function stepReview(delta) {
  if (!reviewState.open) return;
  const next = Math.max(0, Math.min(moveHistory.length - 1, reviewState.index + delta));
  if (next === reviewState.index) return;
  reviewState.index = next;
  updateReviewUI();
  startRaf();
}

function applyState(data, options = {}) {
  const prev = state;
  const action = options.action || 'state';
  state = data;

  if (action === 'new' || !prev) {
    moveHistory = [cloneBoard(data.board)];
  } else if (action === 'move' && data.ok) {
    appendMoveSnapshots(prev, data, options.moveRow, options.moveCol);
  } else if (action === 'undo' && data.ok) {
    syncHistoryAfterUndo(data.board, data.moveCount);
  }

  if (action === 'new' || action === 'move' || (action === 'undo' && data.ok)) {
    hintPos = null;
  }

  dropFrames = [];
  if (prev && !reviewState.open) {
    const diffs = findDiffs(prev.board, data.board);
    dropFrames = diffs
      .filter(diff => diff.value !== 0)
      .map(diff => ({ row: diff.row, col: diff.col, stone: diff.value, t: 0 }));
  }

  pulseFrames = [];
  if (!reviewState.open && data.lastRow >= 0) {
    pulseFrames.push({ row: data.lastRow, col: data.lastCol, t: 0 });
  }

  if (action === 'undo' && data.ok) {
    pulseFrames = [];
  }

  if (!data.gameOver) {
    hideResult();
    clearResultTimer();
  }

  updateTurnIndicator(data);
  updateButtons();
  updateReviewUI();

  if (action === 'new' && data.ok) {
    setFlash(data.message || '新对局已创建');
  } else if (action === 'undo' || !data.ok) {
    setFlash(data.message || '');
  } else {
    setFlash('', 0);
  }

  startRaf();
}

function appendMoveSnapshots(prev, data, moveRow, moveCol) {
  const diffs = findDiffs(prev.board, data.board);
  if (diffs.length === 0) return;

  if (prev.mode === 'ai' && diffs.length === 2 && Number.isInteger(moveRow) && Number.isInteger(moveCol)) {
    const midBoard = cloneBoard(prev.board);
    midBoard[moveRow][moveCol] = prev.currentPlayer;
    pushHistoryBoard(midBoard);
    pushHistoryBoard(cloneBoard(data.board));
    return;
  }

  pushHistoryBoard(cloneBoard(data.board));
}

function syncHistoryAfterUndo(board, moveCount) {
  const targetLength = Math.max(1, moveCount + 1);
  moveHistory = moveHistory.slice(0, targetLength);
  if (moveHistory.length === 0) {
    moveHistory = [cloneBoard(board)];
  } else {
    moveHistory[moveHistory.length - 1] = cloneBoard(board);
  }
}

function pushHistoryBoard(board) {
  const last = moveHistory[moveHistory.length - 1];
  if (!last || !boardsEqual(last, board)) {
    moveHistory.push(board);
  }
}

function updateTurnIndicator(data) {
  const stone = document.getElementById('turn-stone');
  const text = document.getElementById('turn-text');

  stone.className = 'turn-stone';
  if (data.gameOver) {
    if (data.winner === 0) {
      stone.classList.add('white');
      text.textContent = '本局平局';
    } else if (data.winner === 1) {
      stone.classList.add('black');
      text.textContent = '黑方胜出';
    } else {
      stone.classList.add('white');
      text.textContent = '白方胜出';
    }
    clearResultTimer();
    resultTimer = window.setTimeout(() => {
      if (state && state.gameOver && !reviewState.open) {
        showResult(state.winner);
      }
    }, 400);
    return;
  }

  clearResultTimer();
  if (data.mode === 'ai' && data.currentPlayer === 2) {
    stone.classList.add('white', 'ai');
    text.textContent = 'AI 思考中';
    return;
  }

  if (data.currentPlayer === 1) {
    stone.classList.add('black');
    text.textContent = '黑方回合';
  } else {
    stone.classList.add('white');
    text.textContent = '白方回合';
  }
}

function showResult(winner) {
  if (reviewState.open) return;

  const overlay = document.getElementById('result-overlay');
  const icon = document.getElementById('result-icon');
  const title = document.getElementById('result-title');
  const sub = document.getElementById('result-sub');

  if (winner === 0) {
    icon.className = 'result-icon draw';
    icon.textContent = '●';
    title.textContent = '平局';
    sub.textContent = '这一局势均力敌。';
  } else {
    icon.className = `result-icon ${winner === 1 ? 'black' : 'white'}`;
    icon.textContent = '●';
    title.textContent = winner === 1 ? '黑子获胜' : '白子获胜';
    sub.textContent = '你可以直接开始终局复盘。';
  }

  overlay.classList.remove('hidden');
}

function hideResult() {
  document.getElementById('result-overlay').classList.add('hidden');
}

function handleOverlayClick(event) {
  if (event.target === event.currentTarget) {
    hideResult();
  }
}

function restartGame() {
  hideResult();
  startGame(currentMode, currentDiff);
}

function clearResultTimer() {
  if (resultTimer) {
    clearTimeout(resultTimer);
    resultTimer = null;
  }
}

function setLoading(on) {
  busy = on;
  canvas.classList.toggle('locked', on || reviewState.open);
  document.getElementById('thinking-overlay').classList.toggle('hidden', !on);
  updateButtons();
}

function setFlash(message, timeout = 2200) {
  const el = document.getElementById('action-message');
  el.textContent = message || '';
  if (flashTimer) {
    clearTimeout(flashTimer);
    flashTimer = null;
  }
  if (message && timeout > 0) {
    flashTimer = window.setTimeout(() => {
      el.textContent = '';
      flashTimer = null;
    }, timeout);
  }
}

function updateButtons() {
  const undoBtn = document.getElementById('undo-btn');
  const hintBtn = document.getElementById('hint-btn');
  const reviewBtn = document.getElementById('review-btn');

  const canUndo = !!state && !busy && !reviewState.open && !state.gameOver && state.histCount > 0;
  const canHint = !!state && !busy && !reviewState.open && isHumanTurn(state);
  const canReview = !!state && !busy && !reviewState.open && state.gameOver && moveHistory.length > 1;

  undoBtn.disabled = !canUndo;
  hintBtn.disabled = !canHint;
  reviewBtn.disabled = !canReview;
}

function updateReviewUI() {
  const stepEl = document.getElementById('review-step');
  const prevBtn = document.getElementById('review-prev-btn');
  const nextBtn = document.getElementById('review-next-btn');

  if (!reviewState.open) {
    stepEl.textContent = '';
    prevBtn.disabled = true;
    nextBtn.disabled = true;
    return;
  }

  const totalMoves = Math.max(0, moveHistory.length - 1);
  stepEl.textContent = `第 ${reviewState.index} 手 / 共 ${totalMoves} 手`;
  prevBtn.disabled = reviewState.index <= 0;
  nextBtn.disabled = reviewState.index >= moveHistory.length - 1;
}

function isHumanTurn(data) {
  if (!data || data.gameOver) return false;
  return data.mode === 'pvp' || data.currentPlayer === 1;
}

function cloneBoard(board) {
  return board.map(row => row.slice());
}

function boardsEqual(a, b) {
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      if (a[r][c] !== b[r][c]) return false;
    }
  }
  return true;
}

function findDiffs(prevBoard, nextBoard) {
  const diffs = [];
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      if (prevBoard[r][c] !== nextBoard[r][c]) {
        diffs.push({ row: r, col: c, value: nextBoard[r][c] });
      }
    }
  }
  return diffs;
}

function getDisplayedBoard() {
  if (reviewState.open) {
    return moveHistory[reviewState.index] || (state ? state.board : null);
  }
  return state ? state.board : null;
}

function getDisplayedLastMove() {
  if (reviewState.open) {
    if (reviewState.index <= 0) return null;
    const prev = moveHistory[reviewState.index - 1];
    const next = moveHistory[reviewState.index];
    const diffs = findDiffs(prev, next);
    return diffs.length > 0 ? diffs[0] : null;
  }

  if (state && state.lastRow >= 0) {
    return { row: state.lastRow, col: state.lastCol };
  }
  return null;
}

function cx(col) { return PAD + col * CELL; }
function cy(row) { return PAD + row * CELL; }

function drawBoardSurface(context) {
  context.fillStyle = '#c19a49';
  context.fillRect(0, 0, BOARD_PX, BOARD_PX);

  context.strokeStyle = '#9a7530';
  context.lineWidth = 1;
  for (let i = 0; i < SIZE; i++) {
    context.beginPath();
    context.moveTo(cx(0), cy(i));
    context.lineTo(cx(SIZE - 1), cy(i));
    context.stroke();

    context.beginPath();
    context.moveTo(cx(i), cy(0));
    context.lineTo(cx(i), cy(SIZE - 1));
    context.stroke();
  }

  const stars = [[3, 3], [3, 11], [7, 7], [11, 3], [11, 11]];
  context.fillStyle = '#7a5c20';
  stars.forEach(([row, col]) => {
    context.beginPath();
    context.arc(cx(col), cy(row), 3, 0, Math.PI * 2);
    context.fill();
  });
}

function drawStone(context, row, col, stone, scale) {
  const x = cx(col);
  const y = cy(row);
  context.save();
  context.translate(x, y);
  context.scale(scale, scale);

  const grad = context.createRadialGradient(-RADIUS * 0.3, -RADIUS * 0.3, 1, 0, 0, RADIUS);
  if (stone === 1) {
    grad.addColorStop(0, '#555');
    grad.addColorStop(1, '#111');
  } else {
    grad.addColorStop(0, '#fff');
    grad.addColorStop(1, '#d0ccc8');
  }

  context.beginPath();
  context.arc(0, 0, RADIUS, 0, Math.PI * 2);
  context.fillStyle = grad;
  context.shadowColor = 'rgba(0,0,0,.4)';
  context.shadowBlur = 6;
  context.shadowOffsetY = 2;
  context.fill();
  context.restore();
}

function drawLastMark(context, row, col) {
  const x = cx(col);
  const y = cy(row);
  const size = 6;
  context.fillStyle = 'rgba(212, 168, 67, 0.88)';
  context.fillRect(x - size / 2, y - size / 2, size, size);
}

function drawPulse(context, row, col, t) {
  const x = cx(col);
  const y = cy(row);
  const radius = RADIUS + t * 14;
  const alpha = (1 - t) * 0.6;
  context.beginPath();
  context.arc(x, y, radius, 0, Math.PI * 2);
  context.strokeStyle = `rgba(212, 168, 67, ${alpha})`;
  context.lineWidth = 2;
  context.stroke();
}

function drawHintMark(context, row, col) {
  const x = cx(col);
  const y = cy(row);
  context.beginPath();
  context.arc(x, y, RADIUS + 5, 0, Math.PI * 2);
  context.strokeStyle = 'rgba(90, 220, 190, 0.85)';
  context.lineWidth = 2;
  context.stroke();

  context.beginPath();
  context.arc(x, y, 4, 0, Math.PI * 2);
  context.fillStyle = 'rgba(90, 220, 190, 0.35)';
  context.fill();
}

function render() {
  rafId = null;
  ctx.clearRect(0, 0, BOARD_PX, BOARD_PX);
  drawBoardSurface(ctx);

  const board = getDisplayedBoard();
  if (!board) return;

  const animating = new Set();
  if (!reviewState.open) {
    dropFrames.forEach(frame => animating.add(`${frame.row},${frame.col}`));
  }

  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      if (board[r][c] !== 0 && !animating.has(`${r},${c}`)) {
        drawStone(ctx, r, c, board[r][c], 1);
      }
    }
  }

  const lastMove = getDisplayedLastMove();
  if (lastMove && (reviewState.open || dropFrames.length === 0)) {
    drawLastMark(ctx, lastMove.row, lastMove.col);
  }

  if (!reviewState.open && hintPos && board[hintPos.row][hintPos.col] === 0) {
    drawHintMark(ctx, hintPos.row, hintPos.col);
  }

  if (reviewState.open) return;

  const dt = 1 / 60;
  const dropDuration = 0.18;
  const pulseDuration = 1.2;

  dropFrames = dropFrames.filter(frame => {
    frame.t += dt / dropDuration;
    const t = Math.min(frame.t, 1);
    const scale = 1 + (t - 1) * (t - 1) * ((1.7 + 1) * (t - 1) + 1.7);
    drawStone(ctx, frame.row, frame.col, frame.stone, Math.max(0.01, scale));
    return frame.t < 1;
  });

  pulseFrames = pulseFrames.filter(frame => {
    frame.t += dt / pulseDuration;
    drawPulse(ctx, frame.row, frame.col, frame.t % 1);
    return true;
  });

  if (dropFrames.length > 0 || pulseFrames.length > 0) {
    rafId = requestAnimationFrame(render);
  }
}

function startRaf() {
  if (rafId) cancelAnimationFrame(rafId);
  rafId = requestAnimationFrame(render);
}

canvas.addEventListener('click', event => {
  if (busy || !state || state.gameOver || reviewState.open) return;
  if (state.mode === 'ai' && state.currentPlayer !== 1) return;

  const rect = canvas.getBoundingClientRect();
  const scaleX = BOARD_PX / rect.width;
  const scaleY = BOARD_PX / rect.height;
  const px = (event.clientX - rect.left) * scaleX;
  const py = (event.clientY - rect.top) * scaleY;

  const col = Math.round((px - PAD) / CELL);
  const row = Math.round((py - PAD) / CELL);
  if (row < 0 || row >= SIZE || col < 0 || col >= SIZE) return;

  doMove(row, col);
});

drawBoardSurface(ctx);
updateButtons();
