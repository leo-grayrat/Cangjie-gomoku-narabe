'use strict';

const SIZE = 15;
const CELL = 36;       // px per cell
const PAD  = 22;       // board padding
const RADIUS = 14;     // stone radius

const BOARD_PX = PAD * 2 + CELL * (SIZE - 1);  // = 560 with above values

const ALGO_HINTS = {
  greedy:    '贪心启发式：对每个候选落点计算棋型得分，取最高分直接落子，无搜索，速度最快。',
  minimax:   'Minimax（深度 3）：递归枚举双方应对，叶节点用棋型评估函数打分，回溯选最优路径。',
  alphabeta: 'Alpha-Beta 剪枝（深度 4）：维护搜索上下界，提前剪掉无效分支，效率远优于纯 Minimax。',
  solver:    '必胜算法：优先检测立即赢棋和必防点，关键局面走出强制获胜序列，退化时使用 Alpha-Beta。',
};

const ALGO_NAMES = {
  greedy: '人机·贪心', minimax: '人机·Minimax',
  alphabeta: '人机·Alpha-Beta', solver: '人机·必胜',
};

let state = null;
let busy  = false;

// animation state
let pulseFrames = [];   // [{row, col, t}]
let dropFrames  = [];   // [{row, col, stone, t}] stone=1|2
let rafId       = null;

const canvas  = document.getElementById('board');
const ctx     = canvas.getContext('2d');
canvas.width  = BOARD_PX;
canvas.height = BOARD_PX;

// ── Views ──────────────────────────────────────────────────────

function showView(id) {
  const views = document.querySelectorAll('.view');
  views.forEach(v => { v.classList.remove('active', 'slide-in'); });
  const target = document.getElementById(id);
  target.classList.add('active', 'slide-in');
}

function goHome() { showView('view-home'); }

// ── Game lifecycle ─────────────────────────────────────────────

async function startGame(mode, diff) {
  if (busy) return;
  showView('view-game');

  // set labels
  const label = mode === 'pvp' ? '本地双人' : (ALGO_NAMES[diff] || diff);
  document.getElementById('mode-label').textContent = label;
  document.getElementById('algo-hint').textContent =
    mode === 'pvp' ? '双人对弈模式：两位玩家轮流落子，先连五子者获胜。' : (ALGO_HINTS[diff] || '');

  setLoading(true);
  try {
    const data = await api(`/api/new?mode=${mode}&diff=${diff}`);
    applyState(data);
  } finally {
    setLoading(false);
  }
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

  // find newly placed stones → trigger drop animation
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

  // pulse on last move
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
    el.textContent = data.winner === 0 ? '平局' :
      (data.winner === 1 ? '黑子获胜' : '白子获胜');
  } else {
    const player = data.currentPlayer === 1 ? '黑子' : '白子';
    const waiting = data.mode === 'ai' && data.currentPlayer === 2;
    el.textContent = waiting ? 'AI 思考中…' : `当前：${player}`;
  }
}

// ── Loading / thinking overlay ─────────────────────────────────

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

  // grid lines
  ctx.strokeStyle = '#9a7530';
  ctx.lineWidth = 1;
  for (let i = 0; i < SIZE; i++) {
    ctx.beginPath();
    ctx.moveTo(cx(0), cy(i)); ctx.lineTo(cx(SIZE-1), cy(i));
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(cx(i), cy(0)); ctx.lineTo(cx(i), cy(SIZE-1));
    ctx.stroke();
  }

  // star points
  const stars = [[3,3],[3,11],[7,7],[11,3],[11,11]];
  ctx.fillStyle = '#7a5c20';
  stars.forEach(([r,c]) => {
    ctx.beginPath();
    ctx.arc(cx(c), cy(r), 3, 0, Math.PI*2);
    ctx.fill();
  });
}

function drawStone(row, col, stone, scale) {
  const x = cx(col), y = cy(row);
  const r = RADIUS * scale;

  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);

  const grad = ctx.createRadialGradient(-RADIUS*0.3, -RADIUS*0.3, 1, 0, 0, RADIUS);
  if (stone === 1) {
    grad.addColorStop(0, '#555');
    grad.addColorStop(1, '#111');
  } else {
    grad.addColorStop(0, '#fff');
    grad.addColorStop(1, '#d0ccc8');
  }

  ctx.beginPath();
  ctx.arc(0, 0, RADIUS, 0, Math.PI*2);
  ctx.fillStyle = grad;
  ctx.shadowColor = 'rgba(0,0,0,.4)';
  ctx.shadowBlur = 6;
  ctx.shadowOffsetY = 2;
  ctx.fill();
  ctx.restore();
}

function drawPulse(row, col, t) {
  // t in [0,1]: expanding ring fading out
  const x = cx(col), y = cy(row);
  const r = RADIUS + t * 14;
  const alpha = (1 - t) * 0.6;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI*2);
  ctx.strokeStyle = `rgba(212,168,67,${alpha})`;
  ctx.lineWidth = 2;
  ctx.stroke();
}

function render(ts) {
  rafId = null;
  ctx.clearRect(0, 0, BOARD_PX, BOARD_PX);
  drawBoard();

  if (!state) return;

  const DT = 1/60;
  const DROP_DUR = 0.18;  // seconds
  const PULSE_DUR = 1.2;

  // draw static stones (skip those being animated)
  const animating = new Set(dropFrames.map(f => `${f.row},${f.col}`));
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      if (state.board[r][c] !== 0 && !animating.has(`${r},${c}`)) {
        drawStone(r, c, state.board[r][c], 1);
      }
    }
  }

  // drop animations
  dropFrames = dropFrames.filter(f => {
    f.t += DT / DROP_DUR;
    const t = Math.min(f.t, 1);
    // easeOutBack
    const scale = 1 + (t-1)*(t-1)*((1.7+1)*(t-1)+1.7);
    drawStone(f.row, f.col, f.stone, Math.max(0.01, scale));
    return f.t < 1;
  });

  // pulse
  pulseFrames = pulseFrames.filter(f => {
    f.t += DT / PULSE_DUR;
    const t = f.t % 1;
    drawPulse(f.row, f.col, t);
    return true; // continuous
  });

  const needMore = dropFrames.length > 0 || pulseFrames.length > 0;
  if (needMore) {
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

// ── Initial render ─────────────────────────────────────────────

// Draw empty board on load
drawBoard();
