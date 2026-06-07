'use strict';

const SIZE = 15;
const CELL = 36;
const PAD  = 22;
const RADIUS = 14;
const BOARD_PX = PAD * 2 + CELL * (SIZE - 1);

const ALGO_HINTS = {
  easy:    '简单：防必输 + 70% 贪心启发 + 30% 随机邻近落子，会犯明显错误。',
  medium:  'Minimax（深度 3，候选 10）：无剪枝递归搜索，有基本策略意识，中级玩家可击败。',
  hard:    'Alpha-Beta（深度 4，候选 15）：剪枝优化搜索，需要提前规划才能取胜。',
  expert:  '专家：预检必胜/必防点 + Alpha-Beta（深度 4，候选 20），最强搜索难度。',
  joseki:  '定式：前期按天元开局定式落子，出库后退化为 Hard 强度。知道定式的玩家可专门引它出库。',
};

const ALGO_NAMES = {
  easy: '人机·简单', medium: '人机·Minimax',
  hard: '人机·Hard', expert: '人机·专家', joseki: '人机·定式',
};

let state = null;
let busy  = false;
let currentMode = 'ai', currentDiff = 'easy';

let pulseFrames = [];
let dropFrames  = [];
let rafId       = null;

const canvas  = document.getElementById('board');
const ctx     = canvas.getContext('2d');
canvas.width  = BOARD_PX;
canvas.height = BOARD_PX;

// ── Views ──────────────────────────────────────────────────────

function showView(id) {
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active', 'slide-in'));
  const target = document.getElementById(id);
  target.classList.add('active', 'slide-in');
}

function goHome() {
  hideResult();
  showView('view-home');
}

// ── Home interactions ──────────────────────────────────────────

function toggleDiffPanel() {
  const panel = document.getElementById('diff-panel');
  const chevron = document.getElementById('diff-chevron');
  chevron.classList.toggle('rotated', panel.classList.toggle('open'));
}

// ── Game lifecycle ─────────────────────────────────────────────

async function startGame(mode, diff) {
  if (busy) return;
  currentMode = mode;
  currentDiff = diff;
  showView('view-game');

  const label = mode === 'pvp' ? '本地双人' : (ALGO_NAMES[diff] || diff);
  document.getElementById('mode-label').textContent = label;
  document.getElementById('algo-hint').textContent =
    mode === 'pvp' ? '双人对弈模式：两位玩家轮流落子，先连五子者获胜。' : (ALGO_HINTS[diff] || '');

  showAlgoDetail(mode, diff);

  setLoading(true);
  try {
    const data = await api(`/api/new?mode=${mode}&diff=${diff}`);
    applyState(data);
  } finally {
    setLoading(false);
  }
}

function showAlgoDetail(mode, diff) {
  document.querySelectorAll('.algo-detail-block').forEach(b => b.classList.remove('visible'));
  const key = mode === 'pvp' ? 'pvp' : diff;
  const block = document.querySelector(`.algo-detail-block[data-diff="${key}"]`);
  if (block) block.classList.add('visible');
}

// ── API ────────────────────────────────────────────────────────

async function api(url) {
  const res = await fetch(url);
  return res.json();
}

async function doMove(row, col) {
  if (busy || !state || state.gameOver) return;
  if (state.mode === 'ai' && state.currentPlayer !== 1) return;
  setLoading(true);
  try {
    const data = await api(`/api/move?row=${row}&col=${col}`);
    applyState(data);
  } finally {
    setLoading(false);
  }
}

// ── State ──────────────────────────────────────────────────────

function applyState(data) {
  const prev = state;
  state = data;

  dropFrames = [];
  if (prev) {
    for (let r = 0; r < SIZE; r++) {
      for (let c = 0; c < SIZE; c++) {
        if (prev.board[r][c] === 0 && data.board[r][c] !== 0) {
          dropFrames.push({ row: r, col: c, stone: data.board[r][c], t: 0 });
        }
      }
    }
  }

  pulseFrames = [];
  if (data.lastRow >= 0) {
    pulseFrames.push({ row: data.lastRow, col: data.lastCol, t: 0 });
  }

  updateStatus(data);
  startRaf();
}

function updateStatus(data) {
  const el = document.getElementById('status-text');
  if (data.gameOver) {
    el.textContent = data.winner === 0 ? '平局' : (data.winner === 1 ? '黑子获胜' : '白子获胜');
    setTimeout(() => showResult(data.winner), 400);
  } else {
    const player = data.currentPlayer === 1 ? '黑子' : '白子';
    el.textContent = (data.mode === 'ai' && data.currentPlayer === 2) ? 'AI 思考中…' : `当前：${player}`;
  }
}

// ── Result overlay ─────────────────────────────────────────────

function showResult(winner) {
  const overlay = document.getElementById('result-overlay');
  const icon    = document.getElementById('result-icon');
  const title   = document.getElementById('result-title');
  const sub     = document.getElementById('result-sub');

  if (winner === 0) {
    icon.className = 'result-icon draw'; icon.textContent = '◈';
    title.textContent = '平局'; sub.textContent = '势均力敌，再分高下！';
  } else {
    icon.className = `result-icon ${winner === 1 ? 'black' : 'white'}`; icon.textContent = '●';
    title.textContent = winner === 1 ? '黑子获胜' : '白子获胜'; sub.textContent = '五子连珠！';
  }

  overlay.classList.remove('hidden');
  const card = overlay.querySelector('.result-card');
  card.style.animation = 'none'; void card.offsetWidth; card.style.animation = '';
}

function hideResult() { document.getElementById('result-overlay').classList.add('hidden'); }
function handleOverlayClick(e) { if (e.target === e.currentTarget) hideResult(); }
function restartGame() { hideResult(); startGame(currentMode, currentDiff); }

// ── Loading ────────────────────────────────────────────────────

function setLoading(on) {
  busy = on;
  canvas.classList.toggle('locked', on);
  document.getElementById('thinking-overlay').classList.toggle('hidden', !on);
}

// ── Drawing ────────────────────────────────────────────────────

function cx(col) { return PAD + col * CELL; }
function cy(row) { return PAD + row * CELL; }

function drawBoard() {
  ctx.fillStyle = '#c19a49';
  ctx.fillRect(0, 0, BOARD_PX, BOARD_PX);

  ctx.strokeStyle = '#9a7530';
  ctx.lineWidth = 1;
  for (let i = 0; i < SIZE; i++) {
    ctx.beginPath(); ctx.moveTo(cx(0), cy(i)); ctx.lineTo(cx(SIZE-1), cy(i)); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx(i), cy(0)); ctx.lineTo(cx(i), cy(SIZE-1)); ctx.stroke();
  }

  const stars = [[3,3],[3,11],[7,7],[11,3],[11,11]];
  ctx.fillStyle = '#7a5c20';
  stars.forEach(([r,c]) => {
    ctx.beginPath(); ctx.arc(cx(c), cy(r), 3, 0, Math.PI*2); ctx.fill();
  });
}

function drawStone(row, col, stone, scale) {
  const x = cx(col), y = cy(row);
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  const grad = ctx.createRadialGradient(-RADIUS*0.3, -RADIUS*0.3, 1, 0, 0, RADIUS);
  if (stone === 1) { grad.addColorStop(0, '#555'); grad.addColorStop(1, '#111'); }
  else             { grad.addColorStop(0, '#fff'); grad.addColorStop(1, '#d0ccc8'); }
  ctx.beginPath(); ctx.arc(0, 0, RADIUS, 0, Math.PI*2);
  ctx.fillStyle = grad;
  ctx.shadowColor = 'rgba(0,0,0,.4)'; ctx.shadowBlur = 6; ctx.shadowOffsetY = 2;
  ctx.fill();
  ctx.restore();
}

function drawLastMark(row, col) {
  const x = cx(col), y = cy(row), s = 6;
  ctx.fillStyle = 'rgba(212,168,67,0.85)';
  ctx.fillRect(x - s/2, y - s/2, s, s);
}

function drawPulse(row, col, t) {
  const x = cx(col), y = cy(row);
  const r = RADIUS + t * 14;
  const alpha = (1 - t) * 0.6;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI*2);
  ctx.strokeStyle = `rgba(212,168,67,${alpha})`; ctx.lineWidth = 2; ctx.stroke();
}

function render() {
  rafId = null;
  ctx.clearRect(0, 0, BOARD_PX, BOARD_PX);
  drawBoard();

  if (!state) return;

  const DT = 1/60;
  const DROP_DUR = 0.18;
  const PULSE_DUR = 1.2;

  const animating = new Set(dropFrames.map(f => `${f.row},${f.col}`));
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      if (state.board[r][c] !== 0 && !animating.has(`${r},${c}`)) {
        drawStone(r, c, state.board[r][c], 1);
      }
    }
  }

  if (state.lastRow >= 0 && dropFrames.length === 0) drawLastMark(state.lastRow, state.lastCol);

  dropFrames = dropFrames.filter(f => {
    f.t += DT / DROP_DUR;
    const t = Math.min(f.t, 1);
    const scale = 1 + (t-1)*(t-1)*((1.7+1)*(t-1)+1.7);
    drawStone(f.row, f.col, f.stone, Math.max(0.01, scale));
    return f.t < 1;
  });

  pulseFrames = pulseFrames.filter(f => {
    f.t += DT / PULSE_DUR;
    drawPulse(f.row, f.col, f.t % 1);
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

// ── Click handling ─────────────────────────────────────────────

canvas.addEventListener('click', e => {
  if (busy || !state || state.gameOver) return;
  if (state.mode === 'ai' && state.currentPlayer !== 1) return;

  const rect = canvas.getBoundingClientRect();
  const scaleX = BOARD_PX / rect.width;
  const scaleY = BOARD_PX / rect.height;
  const px = (e.clientX - rect.left) * scaleX;
  const py = (e.clientY - rect.top)  * scaleY;

  const col = Math.round((px - PAD) / CELL);
  const row = Math.round((py - PAD) / CELL);
  if (col < 0 || col >= SIZE || row < 0 || row >= SIZE) return;

  doMove(row, col);
});

drawBoard();
