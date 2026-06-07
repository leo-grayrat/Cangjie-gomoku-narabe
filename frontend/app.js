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

const TRIVIA_BY_KEY = {
  pvp: {
    title: '双人对局',
    text: '标准五子棋的目标是在横、竖或斜向先连成五子。没有 AI 参与时，这一局只检验双方对局面的判断。'
  },
  easy: {
    title: '贪心策略',
    text: '贪心算法会优先处理眼前最直接的得失。它不一定看得远，但通常会先去抓住当前最划算的一手。'
  },
  medium: {
    title: 'Minimax',
    text: 'Minimax 假设双方都会选择对自己最有利的下法，因此擅长比较一来一回之后，局面最终会走向哪里。'
  },
  hard: {
    title: 'Alpha-Beta',
    text: 'Alpha-Beta 不是另一套新规则，而是 Minimax 的剪枝加速方式，用来更早排除明显不优的分支。'
  },
  expert: {
    title: '战术预检',
    text: '很多五子棋胜负并不需要长算，只要先抓住一步取胜点或必须补防的位置，判断就会立刻清楚很多。'
  },
  joseki: {
    title: '开局定式',
    text: '定式的价值主要体现在开局。它记录的是一些常见结构下较成熟的应对方式，而不是整盘棋的完整答案。'
  }
};

const DISPLAY_MODE_TEXT = {
  pvp: '本地双人',
  easy: '人机对战 · Easy',
  medium: '人机对战 · Medium',
  hard: '人机对战 · Hard',
  expert: '人机对战 · Expert',
  joseki: '人机对战 · Joseki'
};

const TRIVIA_FACTS_BY_KEY = {
  pvp: [
    {
      title: '棋盘规格',
      text: '现代五子棋通常用 15×15 棋盘进行对局，19×19 棋盘在更早的时期也很常见。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '纸笔也能玩',
      text: '因为棋子落下后通常不会移动或拿走，五子棋也常被当作纸笔游戏来玩。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '基本胜负',
      text: '标准规则下，双方轮流落子，先在横、竖或斜方向连成五子的一方获胜。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '长连规则',
      text: '有些规则要求必须正好五连，六子以上的长连不算胜利，这种情况叫作“长连”。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '先手优势',
      text: '黑棋先行，这也是五子棋长期存在先手优势讨论的根源之一。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    }
  ],
  easy: [
    {
      title: '换手规则',
      text: '在中国常见的一类规则里，黑棋第一手落下后，白棋可以直接选择是否交换黑白，以减轻先手优势。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '趣味变体',
      text: 'Ninuki-Renju 会加入“吃子”规则：夹住对方连续两子时，可以把这一对棋子提走。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: 'Pente 亲戚',
      text: 'Pente 和 Ninuki-Renju 都带有吃子机制，但 Pente 常用 19×19 棋盘，也不采用黑方禁手。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '韩式变体',
      text: 'Omok 和自由五子棋很接近，但常在 19×19 棋盘上进行，还会加入“三三禁手”。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '越南变体',
      text: 'Caro 规则要求胜利线不能同时被两端堵死，因此防守方式和普通五子棋会有明显差别。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    }
  ],
  medium: [
    {
      title: '组合博弈',
      text: '从理论上看，五子棋属于 m,n,k 一类的连线游戏：在 m×n 棋盘上，先连成 k 子的一方获胜。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '先手必胜',
      text: '1994 年，Victor Allis 证明了在空的 15×15 棋盘上、没有额外开局限制时，先手一方存在必胜策略。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '问题还没结束',
      text: '虽然无禁自由五子棋已有经典结论，但职业比赛常用的 Swap2 开局规则至今仍未被完全求解。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '早期棋类 AI',
      text: '1962 年，Joseph Weizenbaum 就写过一篇文章，介绍如何让计算机下五子棋并击败初学者。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '复杂度很高',
      text: '广义五子棋与计算复杂性研究关系很深，相关问题后来被证明属于 PSPACE-complete。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    }
  ],
  hard: [
    {
      title: '职业开局',
      text: '职业五子棋比赛会用专门的开局规则来平衡先手优势，世界锦标赛自 2009 年起使用 Swap2。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: 'Gomocup',
      text: 'Gomocup 是面向五子棋 AI 的年度赛事，从 2000 年开始每年举行一次。',
      source: 'https://gomocup.org/'
    },
    {
      title: 'AI 与人类',
      text: '在 2017 年的公开对抗中，程序 Yixin 以 2 比 0 击败了当时的人类世界冠军。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    },
    {
      title: '比赛分组',
      text: '现在的 Gomocup 不只比一种规则，常见分组包括 freestyle、standard、renju 和 caro。',
      source: 'https://gomocup.org/results/gomocup-result-2025/'
    },
    {
      title: '电脑赛事很早',
      text: 'Computer Olympiad 在 1989 年就收录过五子棋项目，之后又有专门的 Renju 电脑世界赛。',
      source: 'https://en.wikipedia.org/wiki/Gomoku'
    }
  ],
  expert: [
    {
      title: '连珠这个名字',
      text: '“连珠”这个名称由日本记者黑岩泪香于 1899 年正式提出，原意是“连起来的珍珠”。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    },
    {
      title: '职业分支',
      text: '连珠可以看作五子棋的职业化分支，它保留了五子连线目标，但额外加入了平衡先手的规则。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    },
    {
      title: '三类黑方禁手',
      text: '连珠里黑方不能下出双三、双四和长连，这三类限制统称为黑方禁手。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    },
    {
      title: '黑白胜法不同',
      text: '连珠中黑方必须正好五连才能获胜，白方则可以用五连以上或逼出黑方禁手来赢棋。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    },
    {
      title: '允许停一手',
      text: '连珠规则允许“停着”，如果双方连续停着，整局会判作和棋。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    }
  ],
  joseki: [
    {
      title: '开局长度',
      text: 'RIF 对连珠开局规则的要求之一，是开局阶段不要超过 5 手。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    },
    {
      title: '二十六开局',
      text: '连珠理论里有 26 个规范开局，这也是很多开局研究和命名系统的基础。',
      source: 'https://gomoku.renju.net/openings/'
    },
    {
      title: '直开与斜开',
      text: '这 26 个开局通常分成两大类：13 个直开和 13 个斜开。',
      source: 'https://gomoku.renju.net/openings/'
    },
    {
      title: '开局有名字',
      text: '这些开局并不是编号而已，它们各自还有名字，例如 Chosei、Suigetsu、Kansei、Kagetsu。',
      source: 'https://gomoku.renju.net/openings/'
    },
    {
      title: '国际组织',
      text: 'Renju International Federation 成立于 1988 年 8 月 8 日，地点是瑞典斯德哥尔摩。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    },
    {
      title: '世界赛传统',
      text: '连珠世界锦标赛自 1989 年起按双年周期举办，女子和团体世界赛也都已经形成了固定体系。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    },
    {
      title: '还有未解空间',
      text: '自由连珠在 2001 年已被证明为先手胜，但带现代开局规则的连珠仍然没有被完全解完。',
      source: 'https://en.wikipedia.org/wiki/Renju'
    }
  ]
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
let triviaSeed = 0;

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
  triviaSeed += 1;
  hintPos = null;
  moveHistory = [];
  setDiffPanel(false);
  clearResultTimer();
  hideResult();
  closeReview();
  setFlash('', 0);
  showView('view-game');

  const key = mode === 'pvp' ? 'pvp' : diff;
  document.getElementById('mode-label').textContent = DISPLAY_MODE_TEXT[key] || key;
  showAlgoDetail(mode, diff);
  updatePredictionPanel(null);
  updateTriviaPanel({ mode, difficulty: diff });

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
  updatePredictionPanel(data);
  updateTriviaPanel(data);

  if (action === 'new' && data.ok) {
    setFlash('新对局已开始。');
  } else if (action === 'undo') {
    setFlash(data.ok ? '已悔棋。' : (data.message || '当前没有可悔棋的步骤。'));
  } else if (!data.ok) {
    setFlash(data.message || '当前不能这样操作。');
  } else {
    setFlash('', 0);
  }

  if (action === 'undo' && !data.ok) {
    const friendlyMessage = humanizeMessage(data.message);
    if (friendlyMessage) {
      setFlash(friendlyMessage);
    }
  } else if (!data.ok) {
    const friendlyMessage = humanizeMessage(data.message);
    if (friendlyMessage) {
      setFlash(friendlyMessage);
    }
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

function updatePredictionPanel(data) {
  const blackEl = document.getElementById('prediction-black');
  const whiteEl = document.getElementById('prediction-white');
  const labelEl = document.getElementById('prediction-label');
  const scoreEl = document.getElementById('prediction-score');
  const blackBarEl = document.getElementById('prediction-bar-black');
  const whiteBarEl = document.getElementById('prediction-bar-white');

  if (!data) {
    blackEl.textContent = '--';
    whiteEl.textContent = '--';
    labelEl.textContent = '等待对局';
    scoreEl.textContent = '估值 --';
    blackBarEl.style.width = '50%';
    whiteBarEl.style.width = '50%';
    return;
    blackEl.textContent = '--';
    whiteEl.textContent = '--';
    labelEl.textContent = '等待对局';
    scoreEl.textContent = '估值 --';
    return;
  }

  const blackRate = Number(data.blackWinRate ?? 50);
  const whiteRate = Number(data.whiteWinRate ?? (100 - blackRate));
  blackEl.textContent = `${blackRate}%`;
  whiteEl.textContent = `${whiteRate}%`;
  labelEl.textContent = labelFromRate(blackRate);
  scoreEl.textContent = `估值 ${data.positionScore}`;
  blackBarEl.style.width = `${blackRate}%`;
  whiteBarEl.style.width = `${whiteRate}%`;
  return;
  blackEl.textContent = `${data.blackWinRate}%`;
  whiteEl.textContent = `${data.whiteWinRate}%`;
  labelEl.textContent = data.positionLabel || '均势';
  scoreEl.textContent = `估值 ${data.positionScore}`;
}

function updateTriviaPanel(data) {
  const titleEl = document.getElementById('trivia-title');
  const textEl = document.getElementById('trivia-text');

  if (!data) {
    titleEl.textContent = '等待对局开始';
    textEl.textContent = '开始一局后，这里会显示一条和五子棋相关的小知识。';
    return;
    titleEl.textContent = '等待对局开始';
    textEl.textContent = '进入一局后，这里会显示一条和当前模式相关的小知识。';
    return;
  }

  const key = data.mode === 'pvp' ? 'pvp' : (data.difficulty || currentDiff);
  const item = pickTriviaItem(key);
  titleEl.textContent = item.title;
  textEl.textContent = item.text;
}

function pickTriviaItem(key) {
  const pool = TRIVIA_FACTS_BY_KEY[key] || TRIVIA_FACTS_BY_KEY.easy;
  const index = ((triviaSeed - 1) % pool.length + pool.length) % pool.length;
  return pool[index];
}

function labelFromRate(blackRate) {
  if (Math.abs(blackRate - 50) <= 5) return '均势';
  return blackRate > 55 ? '黑优' : '白优';
}

function humanizeMessage(message) {
  const MAP = {
    no_undo: '当前没有可悔棋的步骤。',
    game_over_review: '对局已结束，请通过复盘查看。',
    game_over: '游戏已经结束，请重新开始。',
    out_of_range: '坐标越界。',
    occupied: '该位置已有棋子。',
    wait_ai: '请等待 AI 落子。'
  };
  return MAP[message] || '';
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
updatePredictionPanel(null);
updateTriviaPanel(null);
