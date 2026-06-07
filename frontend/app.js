'use strict';

const SIZE = 15;
const CELL = 36;
const PAD = 22;
const RADIUS = 14;
const BOARD_PX = PAD * 2 + CELL * (SIZE - 1);

const MODE_TEXT = {
  pvp: '本地双人',
  easy: '人机对战 · Easy',
  medium: '人机对战 · Medium',
  hard: '人机对战 · Hard',
  expert: '人机对战 · Expert',
  joseki: '人机对战 · Joseki'
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
  document.querySelectorAll('.view').forEach((view) => {
    view.classList.remove('active', 'slide-in');
  });
  const target = document.getElementById(id);
  target.classList.add('active', 'slide-in');
}

function setDiffPanel(open) {
  const panel = document.getElementById('diff-panel');
  const chevron = document.getElementById('diff-chevron');
  panel.classList.toggle('open', open);
  chevron.classList.toggle('rotated', open);
}

function toggleDiffPanel() {
  const panel = document.getElementById('diff-panel');
  setDiffPanel(!panel.classList.contains('open'));
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
  moveHistory = [];
  setDiffPanel(false);
  clearResultTimer();
  hideResult();
  closeReview();
  setFlash('', 0);
  showView('view-game');

  const key = mode === 'pvp' ? 'pvp' : diff;
  document.getElementById('mode-label').textContent = MODE_TEXT[key] || key;
  showAlgoDetail(mode, diff);

  setLoading(true);
  try {
    const data = await api(`/api/new?mode=${mode}&diff=${diff}`);
    applyState(data, { action: 'new' });
  } catch (error) {
    setFlash('新对局创建失败，请重试。');
  } finally {
    setLoading(false);
  }
}

function showAlgoDetail(mode, diff) {
  document.querySelectorAll('.algo-detail-block').forEach((block) => {
    block.classList.remove('visible');
  });
  const key = mode === 'pvp' ? 'pvp' : diff;
  const target = document.querySelector(`.algo-detail-block[data-diff="${key}"]`);
  if (target) target.classList.add('visible');
}

async function api(url) {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }
  return res.json();
}

async function doMove(row, col) {
  if (busy || !state || state.gameOver || reviewState.open) return;
  if (state.mode === 'ai' && state.currentPlayer !== 1) return;

  setLoading(true);
  try {
    const data = await api(`/api/move?row=${row}&col=${col}`);
    applyState(data, { action: 'move', moveRow: row, moveCol: col });
  } catch (error) {
    setFlash('落子失败，请重试。');
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
  } catch (error) {
    setFlash('悔棋失败，请重试。');
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
      setFlash('建议落点已标出。');
      updateButtons();
      startRaf();
    } else {
      setFlash(data.message || '当前不能请求帮助。');
    }
  } catch (error) {
    setFlash('帮助请求失败，请重试。');
  } finally {
    setLoading(false);
  }
}

function openReview() {
  if (!state || !state.gameOver || moveHistory.length <= 1) {
    setFlash('只有终局后才能复盘。');
    return;
  }

  clearResultTimer();
  reviewState.open = true;
  reviewState.index = moveHistory.length - 1;
  document.getElementById('review-panel').classList.remove('hidden');
  updateReviewUI();
  updateButtons();
  startRaf();
}

function closeReview() {
  reviewState.open = false;
  document.getElementById('review-panel').classList.add('hidden');
  updateReviewUI();
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

  if (action === 'new' || (data.ok && (action === 'move' || action === 'undo'))) {
    hintPos = null;
  }

  dropFrames = [];
  if (prev && !reviewState.open) {
    dropFrames = findDiffs(prev.board, data.board)
      .filter((diff) => diff.value !== 0)
      .map((diff) => ({ row: diff.row, col: diff.col, stone: diff.value, t: 0 }));
  }

  pulseFrames = [];
  if (!reviewState.open && action !== 'undo' && data.lastRow >= 0 && data.lastCol >= 0) {
    pulseFrames.push({ row: data.lastRow, col: data.lastCol, t: 0 });
  }

  if (!data.gameOver) {
    clearResultTimer();
    hideResult();
  }

  updateTurnIndicator(data);
  updateButtons();
  updateReviewUI();

  if (action === 'new' && data.ok) {
    setFlash('新对局已开始。');
  } else if (action === 'undo') {
    setFlash(data.ok ? '已悔棋。' : (data.message || '当前没有可悔棋的步骤。'));
  } else if (!data.ok) {
    setFlash(data.message || '当前不能这样操作。');
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
      text.textContent = '黑子获胜';
    } else {
      stone.classList.add('white');
      text.textContent = '白子获胜';
    }

    clearResultTimer();
    resultTimer = window.setTimeout(() => {
      if (state && state.gameOver) {
        showResult(state.winner);
      }
    }, 240);
    return;
  }

  clearResultTimer();
  if (data.mode === 'ai' && data.currentPlayer === 2) {
    stone.classList.add('white', 'ai');
    text.textContent = 'AI 回合';
    return;
  }

  if (data.currentPlayer === 1) {
    stone.classList.add('black');
    text.textContent = '黑子落子';
  } else {
    stone.classList.add('white');
    text.textContent = '白子落子';
  }
}

function showResult(winner) {
  const panel = document.getElementById('result-panel');
  const icon = document.getElementById('result-icon');
  const title = document.getElementById('result-title');

  if (winner === 0) {
    icon.className = 'result-icon draw';
    icon.textContent = '和';
    title.textContent = '本局平局';
  } else if (winner === 1) {
    icon.className = 'result-icon black';
    icon.textContent = '●';
    title.textContent = '黑子获胜';
  } else {
    icon.className = 'result-icon white';
    icon.textContent = '●';
    title.textContent = '白子获胜';
  }

  panel.classList.remove('hidden');
}

function hideResult() {
  document.getElementById('result-panel').classList.add('hidden');
}

function restartGame() {
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

  canvas.classList.toggle('locked', busy || reviewState.open);
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
  return board.map((row) => row.slice());
}

function boardsEqual(a, b) {
  for (let r = 0; r < SIZE; r += 1) {
    for (let c = 0; c < SIZE; c += 1) {
      if (a[r][c] !== b[r][c]) return false;
    }
  }
  return true;
}

function findDiffs(prevBoard, nextBoard) {
  const diffs = [];
  for (let r = 0; r < SIZE; r += 1) {
    for (let c = 0; c < SIZE; c += 1) {
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
    const diffs = findDiffs(prev, next).filter((diff) => diff.value !== 0);
    return diffs.length > 0 ? diffs[0] : null;
  }

  if (state && state.lastRow >= 0 && state.lastCol >= 0) {
    return { row: state.lastRow, col: state.lastCol };
  }
  return null;
}

function cx(col) {
  return PAD + col * CELL;
}

function cy(row) {
  return PAD + row * CELL;
}

function drawBoardSurface(context) {
  const wood = context.createLinearGradient(0, 0, BOARD_PX, BOARD_PX);
  wood.addColorStop(0, '#d2ad60');
  wood.addColorStop(0.48, '#c69a4c');
  wood.addColorStop(1, '#b78434');
  context.fillStyle = wood;
  context.fillRect(0, 0, BOARD_PX, BOARD_PX);

  context.fillStyle = 'rgba(255,255,255,0.07)';
  for (let y = 0; y < BOARD_PX; y += 46) {
    context.fillRect(0, y, BOARD_PX, 1);
  }

  context.strokeStyle = '#845c1f';
  context.lineWidth = 1;
  for (let i = 0; i < SIZE; i += 1) {
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
  context.fillStyle = '#6f4b16';
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

  const grad = context.createRadialGradient(-RADIUS * 0.32, -RADIUS * 0.32, 1, 0, 0, RADIUS);
  if (stone === 1) {
    grad.addColorStop(0, '#666a70');
    grad.addColorStop(0.55, '#21252d');
    grad.addColorStop(1, '#0b0d12');
  } else {
    grad.addColorStop(0, '#ffffff');
    grad.addColorStop(0.7, '#ece5d9');
    grad.addColorStop(1, '#c9c0b4');
  }

  context.beginPath();
  context.arc(0, 0, RADIUS, 0, Math.PI * 2);
  context.fillStyle = grad;
  context.shadowColor = 'rgba(0,0,0,0.34)';
  context.shadowBlur = 7;
  context.shadowOffsetY = 2;
  context.fill();
  context.restore();
}

function drawLastMark(context, row, col) {
  const x = cx(col);
  const y = cy(row);
  const size = 6;
  context.fillStyle = 'rgba(177, 84, 64, 0.92)';
  context.fillRect(x - size / 2, y - size / 2, size, size);
}

function drawPulse(context, row, col, t) {
  const x = cx(col);
  const y = cy(row);
  const radius = RADIUS + t * 12;
  const alpha = (1 - t) * 0.46;
  context.beginPath();
  context.arc(x, y, radius, 0, Math.PI * 2);
  context.strokeStyle = `rgba(177, 84, 64, ${alpha})`;
  context.lineWidth = 2;
  context.stroke();
}

function drawHintMark(context, row, col) {
  const x = cx(col);
  const y = cy(row);
  context.beginPath();
  context.arc(x, y, RADIUS + 5, 0, Math.PI * 2);
  context.strokeStyle = 'rgba(92, 208, 191, 0.88)';
  context.lineWidth = 2;
  context.stroke();

  context.beginPath();
  context.arc(x, y, 4, 0, Math.PI * 2);
  context.fillStyle = 'rgba(92, 208, 191, 0.34)';
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
    dropFrames.forEach((frame) => animating.add(`${frame.row},${frame.col}`));
  }

  for (let r = 0; r < SIZE; r += 1) {
    for (let c = 0; c < SIZE; c += 1) {
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
  const pulseDuration = 1.05;

  dropFrames = dropFrames.filter((frame) => {
    frame.t += dt / dropDuration;
    const t = Math.min(frame.t, 1);
    const eased = 1 + (t - 1) * (t - 1) * ((1.65 + 1) * (t - 1) + 1.65);
    drawStone(ctx, frame.row, frame.col, frame.stone, Math.max(0.01, eased));
    return frame.t < 1;
  });

  pulseFrames = pulseFrames.filter((frame) => {
    frame.t += dt / pulseDuration;
    drawPulse(ctx, frame.row, frame.col, frame.t);
    return frame.t < 1;
  });

  if (dropFrames.length > 0 || pulseFrames.length > 0) {
    rafId = requestAnimationFrame(render);
  }
}

function startRaf() {
  if (rafId) cancelAnimationFrame(rafId);
  rafId = requestAnimationFrame(render);
}

canvas.addEventListener('click', (event) => {
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
