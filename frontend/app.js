'use strict';

const SIZE = 15;
const CELL = 36;
const PAD = 22;
const RADIUS = 14;
const BOARD_PX = PAD * 2 + CELL * (SIZE - 1);

const DEFAULT_LAN_HOME_NOTE = '联机双方需要访问同一台服务器地址，例如同一局域网内的 http://主机IP:8080/。';
const DISCIPLINE_LOCK_KEY = 'gomokuModeLock';
const DISCIPLINE_REASON_KEY = 'gomokuModeLockReason';
const DISCIPLINE_PENDING_KEY = 'gomokuDisciplinePending';
const DISCIPLINE_LOCK_VALUE = 'easy-only';
const DISCIPLINE_LOCK_REASON = 'discipline';
const DISCIPLINE_LOCK_TEXT = '守棋人暂时收起了其它棋桌。先在 Easy 赢下一局，把这盘棋认真下完，门会重新打开。';
const DISCIPLINE_UNLOCK_TEXT = '守棋人点了点头。其它棋桌已经重新开放。';
const DISCIPLINE_OMEN_TEXT = '据说一直悔棋、提示或秒下棋，好像会有不好的事情发生……';
const DISCIPLINE_LINES = [
  '哦……你来了。',
  '看来，你是被“再来一次”和“帮我看看”的念头带到这里的。',
  '这张棋盘不是抽奖机。每一次落子，都应该是你愿意承担的一步。',
  '悔棋可以用来学习，不适合用来把一盘棋揉成没有结果的纸团。',
  '提示可以照亮一个位置，但不能替你尊重这局棋。',
  '如果只是不断重来、不断试探、不断让别人替你判断，游戏会慢慢失去味道。',
  '一局棋不一定要漂亮。它可以有迟疑，可以有错手，也可以有后来才看懂的地方。',
  '把一盘棋下完。赢也好，输也好，至少那是你自己的棋。'
];

const DISCIPLINE_LIMITS = {
  undoWindowMs: 90000,
  undoLimit: 6,
  hintTurnWindow: 12,
  hintLimit: 5,
  responseSamples: 6,
  fastResponseMs: 800,
  fastResponseLimit: 5,
  responseTotalMs: 5000
};

const DISPLAY_MODE_TEXT = {
  pvp: '本地双人',
  easy: '人机对战 · Easy',
  medium: '人机对战 · Medium',
  hard: '人机对战 · Hard',
  expert: '人机对战 · Expert',
  joseki: '人机对战 · Joseki',
  lan: '局域网联机'
};

const FRIENDLY_MESSAGES = {
  new_game_created: '新对局已开始。',
  no_undo: '当前没有可悔棋的步骤。',
  undo_ok: '已悔棋。',
  game_over_review: '对局已结束，请通过复盘查看。',
  game_over: '对局已经结束，请重新开始。',
  out_of_range: '坐标越界。',
  occupied: '该位置已有棋子。',
  wait_ai: '请等待 AI 落子。',
  game_over_hint: '对局已结束，无法提供帮助。',
  not_human_turn: '当前不是你的落子回合。',
  bad_params: '参数错误。',
  room_limit_reached: '当前联机房间已满，请稍后再试。',
  room_not_found: '未找到该房间，请检查房间号。',
  room_full: '该房间已经满员。',
  room_created: '房间已创建，等待对手加入。',
  room_joined: '已加入房间。',
  wait_opponent: '房间还未满员，暂时不能开始。',
  bad_player: '玩家身份无效，请重新加入房间。',
  not_your_turn: '还没轮到你落子。',
  host_only_reset: '只有房主可以重新开始本房间。',
  room_reset: '房间已重开。',
  room_closed: '房间已关闭。',
  guest_left: '白方已离开房间。'
};

const TRIVIA_FACTS_BY_KEY = {
  pvp: [
    {
      title: '先手优势',
      text: '五子棋长期存在先手优势讨论，这也是后来衍生出交换规则和职业开局规则的重要原因。'
    },
    {
      title: '纸笔游戏',
      text: '因为棋子落下后通常不会移动，五子棋也常被当作纸笔游戏来玩。'
    },
    {
      title: '基本目标',
      text: '标准规则下，先在横、竖或斜方向连成五子的玩家获胜。'
    }
  ],
  easy: [
    {
      title: '贪心思路',
      text: '贪心算法会优先抓住当前最直接的收益，因此反应快，但不一定看得很远。'
    },
    {
      title: '局部判断',
      text: '在棋类问题里，贪心常用于先处理眼前威胁，再选一个此刻最划算的位置。'
    },
    {
      title: '开局中心',
      text: '很多五子棋程序喜欢先从中心附近起手，因为这里向四个方向发展的空间最均衡。'
    }
  ],
  medium: [
    {
      title: 'Minimax',
      text: 'Minimax 的核心是假设双方都会尽量为自己争取最好的结果，再比较不同路线的最终局面。'
    },
    {
      title: '经典研究',
      text: '五子棋是早期棋类 AI 研究中经常出现的题材，因为规则清晰，攻防又很鲜明。'
    },
    {
      title: '连续应对',
      text: '比起只看一步得失，Minimax 更在意“这一步之后，对手会怎么回应”。'
    }
  ],
  hard: [
    {
      title: '剪枝思想',
      text: 'Alpha-Beta 剪枝会尽早舍弃已经不可能成为最优答案的变化，从而把计算留给更关键的分支。'
    },
    {
      title: '搜索加速',
      text: '它仍然建立在 Minimax 的对抗假设上，只是把一部分无效计算提前省掉了。'
    },
    {
      title: '比赛程序',
      text: '很多棋类程序都会把剪枝作为基础技巧，因为它几乎不改变判断逻辑，却能显著提升效率。'
    }
  ],
  expert: [
    {
      title: '战术优先',
      text: '在五子棋里，一步取胜点和必须补防点往往比一般位置更重要，因此很多强程序都会先做这层检查。'
    },
    {
      title: '对杀判断',
      text: '冲四、活三和补断一类局面变化很快，先抓住关键威胁通常比平均搜索更有效。'
    },
    {
      title: '强制应手',
      text: '当一方已经形成连续威胁时，对手往往只剩极少数可走位置，这类局面很适合先做战术预检。'
    }
  ],
  joseki: [
    {
      title: '定式',
      text: '定式记录的是常见开局结构中的成熟应对方式，它解决的是开局知识，不是整盘棋的全部答案。'
    },
    {
      title: '开局研究',
      text: '五子棋和连珠都有系统化的开局研究，许多开局结构还有固定名称。'
    },
    {
      title: '出库之后',
      text: '一旦局面偏离已知定式，程序就需要重新回到常规判断，而不能继续照搬开局知识。'
    }
  ],
  lan: [
    {
      title: '同盘对局',
      text: '局域网联机模式下，双方浏览器看到的是同一个房间里的同一盘棋。'
    },
    {
      title: '房主执黑',
      text: '当前联机模式里，房主执黑先行，加入房间的玩家执白后手。'
    },
    {
      title: '房间同步',
      text: '落子信息会写回服务器中的房间状态，再同步给房间里的另一位玩家。'
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
let homeDisciplineTimer = null;
let triviaSeed = 0;
let disciplineState = {
  active: false,
  undoTimes: [],
  hintTurns: [],
  responseTimes: [],
  aiReadyAt: null,
  playerTurnSerial: 0
};
let lanSession = {
  active: false,
  roomId: '',
  seat: 0,
  pollTimer: null
};

const pageParams = new URLSearchParams(window.location.search);

const canvas = document.getElementById('board');
const ctx = canvas.getContext('2d');

canvas.width = BOARD_PX;
canvas.height = BOARD_PX;

function wait(ms) {
  return new Promise((resolve) => {
    window.setTimeout(resolve, ms);
  });
}

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function isModeLocked() {
  return localStorage.getItem(DISCIPLINE_LOCK_KEY) === DISCIPLINE_LOCK_VALUE;
}

function setHomeDisciplineNote(message, timeout = 0) {
  const note = document.getElementById('discipline-home-note');
  if (!note) return;

  if (homeDisciplineTimer) {
    clearTimeout(homeDisciplineTimer);
    homeDisciplineTimer = null;
  }

  note.textContent = message || '';
  note.classList.toggle('hidden', !message);

  if (message && timeout > 0) {
    homeDisciplineTimer = window.setTimeout(() => {
      note.textContent = '';
      note.classList.add('hidden');
      homeDisciplineTimer = null;
    }, timeout);
  }
}

function applyModeLockUI() {
  const locked = isModeLocked();
  document.querySelectorAll('[data-discipline-lock="true"]').forEach((button) => {
    button.disabled = locked;
    button.classList.toggle('mode-locked', locked);
  });

  if (locked) {
    setHomeDisciplineNote(DISCIPLINE_LOCK_TEXT);
  } else if (!homeDisciplineTimer) {
    setHomeDisciplineNote('');
  }
}

function modeAllowedByDiscipline(mode, diff) {
  return !isModeLocked() || (mode === 'ai' && diff === 'easy');
}

function blockLockedMode() {
  applyModeLockUI();
  setHomeDisciplineNote(DISCIPLINE_LOCK_TEXT);
  showView('view-home');
  return false;
}

function resetDisciplineTracking() {
  disciplineState.undoTimes = [];
  disciplineState.hintTurns = [];
  disciplineState.responseTimes = [];
  disciplineState.aiReadyAt = null;
  disciplineState.playerTurnSerial = 0;
}

function shouldTrackDiscipline() {
  return !!state
    && state.mode === 'ai'
    && !state.gameOver
    && !disciplineState.active
    && !isModeLocked();
}

function updateDisciplineOmen(data) {
  const omen = document.getElementById('discipline-omen');
  if (!omen) return;
  const visible = !!data && data.mode === 'ai' && !disciplineState.active && !isModeLocked();
  omen.textContent = DISCIPLINE_OMEN_TEXT;
  omen.classList.toggle('hidden', !visible);
}

function trimRecentTimes(times, now, windowMs) {
  return times.filter((time) => now - time <= windowMs);
}

function recordUndoSuccess() {
  if (!shouldTrackDiscipline()) return;

  const now = Date.now();
  disciplineState.undoTimes = trimRecentTimes(disciplineState.undoTimes, now, DISCIPLINE_LIMITS.undoWindowMs);
  disciplineState.undoTimes.push(now);

  if (disciplineState.undoTimes.length >= DISCIPLINE_LIMITS.undoLimit) {
    maybeTriggerDiscipline('undo');
  }
}

function recordHintSuccess() {
  if (!shouldTrackDiscipline()) return;

  const minTurn = Math.max(0, disciplineState.playerTurnSerial - DISCIPLINE_LIMITS.hintTurnWindow + 1);
  disciplineState.hintTurns = disciplineState.hintTurns.filter((turn) => turn >= minTurn);
  disciplineState.hintTurns.push(disciplineState.playerTurnSerial);

  if (disciplineState.hintTurns.length >= DISCIPLINE_LIMITS.hintLimit) {
    maybeTriggerDiscipline('hint');
  }
}

function measurePendingPlayerResponse() {
  if (!shouldTrackDiscipline() || !disciplineState.aiReadyAt || !isHumanTurn(state)) {
    return null;
  }
  return {
    ms: Date.now() - disciplineState.aiReadyAt,
    readyAt: disciplineState.aiReadyAt
  };
}

function recordPlayerResponse(response) {
  if (!shouldTrackDiscipline() || !response) return;

  if (disciplineState.aiReadyAt === response.readyAt) {
    disciplineState.aiReadyAt = null;
  }
  disciplineState.responseTimes.push(response.ms);
  if (disciplineState.responseTimes.length > DISCIPLINE_LIMITS.responseSamples) {
    disciplineState.responseTimes.shift();
  }

  if (disciplineState.responseTimes.length < DISCIPLINE_LIMITS.responseSamples) return;

  const fastCount = disciplineState.responseTimes
    .filter((time) => time <= DISCIPLINE_LIMITS.fastResponseMs)
    .length;
  const total = disciplineState.responseTimes.reduce((sum, time) => sum + time, 0);

  if (fastCount >= DISCIPLINE_LIMITS.fastResponseLimit || total <= DISCIPLINE_LIMITS.responseTotalMs) {
    maybeTriggerDiscipline('speed');
  }
}

function noteAiResponseReady(data, action) {
  if (!data || data.mode !== 'ai' || action === 'new' || action === 'undo' || data.gameOver || isModeLocked()) {
    disciplineState.aiReadyAt = null;
    return;
  }

  if (data.ok && action === 'move' && data.currentPlayer === 1) {
    disciplineState.playerTurnSerial += 1;
    disciplineState.aiReadyAt = Date.now();
  }
}

function maybeTriggerDiscipline(reason) {
  if (disciplineState.active || isModeLocked()) return;
  localStorage.setItem(DISCIPLINE_PENDING_KEY, reason || DISCIPLINE_LOCK_REASON);
  runDisciplineSequence(reason || DISCIPLINE_LOCK_REASON);
}

async function runDisciplineSequence(reason) {
  if (disciplineState.active || isModeLocked()) return;

  disciplineState.active = true;
  localStorage.setItem(DISCIPLINE_PENDING_KEY, reason || DISCIPLINE_LOCK_REASON);
  setLoading(false);
  clearResultTimer();
  hideResult();
  closeReview(true);
  setFlash('', 0);
  updateButtons();
  updateDisciplineOmen(null);

  document.body.classList.add('discipline-sequence');
  if (!prefersReducedMotion()) {
    document.body.classList.add('discipline-flash');
    await wait(2400);
    document.body.classList.remove('discipline-flash');
  }

  const overlay = document.getElementById('discipline-overlay');
  const line = document.getElementById('discipline-line');
  overlay.classList.remove('hidden');
  document.body.classList.add('discipline-blackout');

  for (const text of DISCIPLINE_LINES) {
    line.classList.remove('visible');
    await wait(220);
    line.textContent = text;
    line.classList.add('visible');
    await wait(6100);
    line.classList.remove('visible');
    await wait(1300);
  }

  line.textContent = '';
  overlay.classList.add('hidden');
  document.body.classList.remove('discipline-sequence', 'discipline-blackout');
  disciplineState.active = false;
  resetDisciplineTracking();
  localStorage.removeItem(DISCIPLINE_PENDING_KEY);
  localStorage.setItem(DISCIPLINE_LOCK_KEY, DISCIPLINE_LOCK_VALUE);
  localStorage.setItem(DISCIPLINE_REASON_KEY, DISCIPLINE_LOCK_REASON);
  goHome(true);
  applyModeLockUI();
}

function checkEasyUnlock(data) {
  if (!isModeLocked()) return;
  if (!data || data.mode !== 'ai' || data.difficulty !== 'easy') return;
  if (!data.gameOver || data.winner !== 1) return;

  localStorage.removeItem(DISCIPLINE_LOCK_KEY);
  localStorage.removeItem(DISCIPLINE_REASON_KEY);
  localStorage.removeItem(DISCIPLINE_PENDING_KEY);
  resetDisciplineTracking();
  applyModeLockUI();
  setFlash(DISCIPLINE_UNLOCK_TEXT, 5200);
}

function resumePendingDisciplineSequence() {
  const pendingReason = localStorage.getItem(DISCIPLINE_PENDING_KEY);
  if (pendingReason && !isModeLocked()) {
    window.setTimeout(() => {
      runDisciplineSequence(pendingReason);
    }, 300);
  }
}

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

function setLanPanel(open) {
  const panel = document.getElementById('lan-panel');
  const chevron = document.getElementById('lan-chevron');
  panel.classList.toggle('open', open);
  chevron.classList.toggle('rotated', open);
}

function toggleDiffPanel() {
  const panel = document.getElementById('diff-panel');
  setDiffPanel(!panel.classList.contains('open'));
}

function toggleLanPanel() {
  if (isModeLocked()) {
    blockLockedMode();
    return;
  }
  const panel = document.getElementById('lan-panel');
  setLanPanel(!panel.classList.contains('open'));
}

function setLanHomeNote(message) {
  const note = document.getElementById('lan-home-note');
  if (!note) return;
  note.textContent = message || DEFAULT_LAN_HOME_NOTE;
}

function currentOrigin() {
  return `${window.location.protocol}//${window.location.host}/`;
}

function isLoopbackHost() {
  const host = window.location.hostname;
  return host === 'localhost' || host === '127.0.0.1' || host === '::1';
}

function currentRoomInviteLink(roomId) {
  return `${window.location.origin}/?room=${encodeURIComponent(roomId)}`;
}

async function copyText(text, successMessage) {
  try {
    await navigator.clipboard.writeText(text);
    setFlash(successMessage);
    return true;
  } catch (_error) {
    setFlash('复制失败，请手动复制。');
    return false;
  }
}

function refreshLanHomeHint() {
  const originEl = document.getElementById('lan-origin-value');
  if (originEl) {
    originEl.textContent = currentOrigin();
  }

  const joinedRoom = (pageParams.get('room') || '').trim();
  if (joinedRoom) {
    const input = document.getElementById('lan-room-input');
    input.value = joinedRoom;
    setLanPanel(true);
    setLanHomeNote(`已识别邀请房间 ${joinedRoom}，点击“加入房间”即可进入。`);
    return;
  }

  if (isLoopbackHost()) {
    setLanHomeNote('你当前打开的是 localhost/127.0.0.1，这个地址只能本机访问。联机前请改用本机局域网 IP 打开本页，再把地址或邀请链接发给对方。');
    return;
  }

  setLanHomeNote('');
}

function copyCurrentAddress() {
  if (isLoopbackHost()) {
    setLanHomeNote('当前地址是 localhost/127.0.0.1，复制后别的设备也打不开。请先改用局域网 IP 打开本页。');
    return;
  }
  copyText(currentOrigin(), '当前地址已复制。');
}

function copyRoomCode() {
  if (!lanSession.active || !lanSession.roomId) {
    setFlash('当前没有可复制的房间号。');
    return;
  }
  copyText(lanSession.roomId, '房间号已复制。');
}

function copyInviteLink() {
  if (!lanSession.active || !lanSession.roomId) {
    setFlash('当前没有可复制的邀请链接。');
    return;
  }
  if (isLoopbackHost()) {
    setFlash('当前页面地址仍是 localhost/127.0.0.1，邀请链接不能给其他设备使用。');
    return;
  }
  copyText(currentRoomInviteLink(lanSession.roomId), '邀请链接已复制。');
}

function updateModeLabel(mode, diff) {
  const key = mode === 'pvp' ? 'pvp' : diff;
  document.getElementById('mode-label').textContent = DISPLAY_MODE_TEXT[key] || key;
}

function showAlgoDetail(mode, diff) {
  document.querySelectorAll('.algo-detail-block').forEach((block) => {
    block.classList.remove('visible');
  });
  const key = mode === 'pvp' ? 'pvp' : diff;
  const target = document.querySelector(`.algo-detail-block[data-diff="${key}"]`);
  if (target) {
    target.classList.add('visible');
  }
}

function prepareGameView(mode, diff) {
  currentMode = mode;
  currentDiff = diff;
  triviaSeed += 1;
  hintPos = null;
  moveHistory = [];
  dropFrames = [];
  pulseFrames = [];
  setDiffPanel(false);
  setLanPanel(false);
  clearResultTimer();
  hideResult();
  closeReview();
  setFlash('', 0);
  showView('view-game');
  updateModeLabel(mode, diff);
  showAlgoDetail(mode, diff);
  updatePredictionPanel(null);
  updateTriviaPanel({ mode, difficulty: diff });
  updateDisciplineOmen({ mode, difficulty: diff });
  if (mode !== 'lan') {
    hideLanRoomPanel();
  }
}

function clearLanSession() {
  lanSession.active = false;
  lanSession.roomId = '';
  lanSession.seat = 0;
}

function stopLanPolling() {
  if (lanSession.pollTimer) {
    clearTimeout(lanSession.pollTimer);
    lanSession.pollTimer = null;
  }
}

function leaveLanRoom(notifyServer = true) {
  if (!lanSession.active || !lanSession.roomId || !lanSession.seat) {
    clearLanSession();
    return;
  }

  if (notifyServer) {
    const url = `/api/lan/leave?room=${encodeURIComponent(lanSession.roomId)}&player=${lanSession.seat}`;
    fetch(url, { keepalive: true }).catch(() => {});
  }

  clearLanSession();
}

function goHome(force = false) {
  if (disciplineState.active && !force) return;
  stopLanPolling();
  leaveLanRoom();
  clearResultTimer();
  hideResult();
  closeReview();
  hideLanRoomPanel();
  setFlash('', 0);
  showView('view-home');
  refreshLanHomeHint();
  applyModeLockUI();
}

async function api(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return response.json();
}

function hasBoardState(data) {
  return !!data && Array.isArray(data.board);
}

function humanizeMessage(message) {
  return FRIENDLY_MESSAGES[message] || '';
}

function handleLanFailureAndReturnHome(message) {
  stopLanPolling();
  hideLanRoomPanel();
  leaveLanRoom(false);
  showView('view-home');
  setLanPanel(true);
  setLanHomeNote(message || DEFAULT_LAN_HOME_NOTE);
}

function activateLanSession(data) {
  lanSession.active = true;
  lanSession.roomId = data.roomId || '';
  lanSession.seat = Number(data.seat || 0);
  updateLanRoomPanel(data);
}

function scheduleLanPoll() {
  stopLanPolling();
  if (!lanSession.active) return;
  lanSession.pollTimer = window.setTimeout(() => {
    pollLanState();
  }, 1000);
}

async function pollLanState() {
  if (!lanSession.active || busy) {
    scheduleLanPoll();
    return;
  }

  try {
    const data = await api(`/api/lan/state?room=${encodeURIComponent(lanSession.roomId)}&player=${lanSession.seat}`);
    if (!data.ok || !hasBoardState(data)) {
      handleLanFailureAndReturnHome(humanizeMessage(data.message) || '房间已不可用。');
      return;
    }
    applyState(data, { action: 'poll' });
  } catch (_error) {
    // Ignore transient network errors and keep polling.
  } finally {
    scheduleLanPoll();
  }
}

async function startGame(mode, diff) {
  if (busy || disciplineState.active) return;
  if (!modeAllowedByDiscipline(mode, diff)) {
    blockLockedMode();
    return;
  }

  stopLanPolling();
  leaveLanRoom();
  prepareGameView(mode, diff);
  resetDisciplineTracking();

  setLoading(true);
  try {
    const data = await api(`/api/new?mode=${mode}&diff=${diff}`);
    applyState(data, { action: 'new' });
  } catch (_error) {
    setFlash('新对局创建失败，请重试。');
  } finally {
    setLoading(false);
  }
}

async function startLanHost() {
  if (busy || disciplineState.active) return;
  if (!modeAllowedByDiscipline('lan', 'lan')) {
    blockLockedMode();
    return;
  }

  stopLanPolling();
  leaveLanRoom();
  setLanHomeNote('');
  prepareGameView('lan', 'lan');

  setLoading(true);
  try {
    const data = await api('/api/lan/create');
    if (!data.ok || !hasBoardState(data)) {
      handleLanFailureAndReturnHome(humanizeMessage(data.message) || '创建房间失败，请重试。');
      return;
    }
    activateLanSession(data);
    applyState(data, { action: 'new' });
    scheduleLanPoll();
  } catch (_error) {
    handleLanFailureAndReturnHome('创建房间失败，请重试。');
  } finally {
    setLoading(false);
  }
}

async function joinLanRoom() {
  if (busy || disciplineState.active) return;
  if (!modeAllowedByDiscipline('lan', 'lan')) {
    blockLockedMode();
    return;
  }

  const input = document.getElementById('lan-room-input');
  const roomId = (input.value || '').trim();
  if (!roomId) {
    setLanPanel(true);
    setLanHomeNote('请先输入房间号。');
    input.focus();
    return;
  }

  stopLanPolling();
  leaveLanRoom();
  setLanHomeNote('');
  prepareGameView('lan', 'lan');

  setLoading(true);
  try {
    const data = await api(`/api/lan/join?room=${encodeURIComponent(roomId)}`);
    if (!data.ok || !hasBoardState(data)) {
      handleLanFailureAndReturnHome(humanizeMessage(data.message) || '加入房间失败，请检查房间号。');
      return;
    }
    input.value = '';
    activateLanSession(data);
    applyState(data, { action: 'new' });
    scheduleLanPoll();
  } catch (_error) {
    handleLanFailureAndReturnHome('加入房间失败，请重试。');
  } finally {
    setLoading(false);
  }
}

async function handleLanReset() {
  if (disciplineState.active || !lanSession.active) return;
  if (lanSession.seat !== 1) {
    setFlash('只有房主可以重新开始本房间。');
    return;
  }

  setLoading(true);
  try {
    const data = await api(`/api/lan/reset?room=${encodeURIComponent(lanSession.roomId)}&player=${lanSession.seat}`);
    if (!data.ok || !hasBoardState(data)) {
      handleLanFailureAndReturnHome(humanizeMessage(data.message) || '房间重开失败，请重试。');
      return;
    }
    applyState(data, { action: 'new' });
  } catch (_error) {
    setFlash('房间重开失败，请重试。');
  } finally {
    setLoading(false);
  }
}

function hideLanRoomPanel() {
  const panel = document.getElementById('lan-room-panel');
  panel.classList.add('hidden');
}

function updateLanRoomPanel(data) {
  const panel = document.getElementById('lan-room-panel');
  const roomIdEl = document.getElementById('lan-room-id');
  const seatEl = document.getElementById('lan-seat-label');
  const noteEl = document.getElementById('lan-room-note');
  const shareEl = document.getElementById('lan-share-link');

  if (!data || data.mode !== 'lan') {
    panel.classList.add('hidden');
    return;
  }

  panel.classList.remove('hidden');
  roomIdEl.textContent = data.roomId || '--';
  shareEl.textContent = data.roomId ? currentRoomInviteLink(data.roomId) : '--';

  if (lanSession.seat === 1) {
    seatEl.textContent = '房主 · 执黑';
  } else if (lanSession.seat === 2) {
    seatEl.textContent = '客方 · 执白';
  } else {
    seatEl.textContent = '--';
  }

  if (!data.roomReady) {
    if (data.moveCount > 0) {
      noteEl.textContent = lanSession.seat === 1 ? '白方已离开房间，等待重新加入。' : '等待房主或另一位玩家就位。';
    } else {
      noteEl.textContent = lanSession.seat === 1 ? '房间已创建，等待白方加入。' : '等待房主准备。';
    }
    return;
  }

  if (data.gameOver) {
    noteEl.textContent = '本局已结束，可复盘或由房主重开。';
    return;
  }

  noteEl.textContent = data.currentPlayer === lanSession.seat ? '轮到你落子。' : '等待对方落子。';
}

async function doMove(row, col) {
  if (disciplineState.active || busy || !state || state.gameOver || reviewState.open) return;

  const pendingResponseMs = measurePendingPlayerResponse();
  setLoading(true);
  try {
    let data;
    if (state.mode === 'lan') {
      data = await api(`/api/lan/move?room=${encodeURIComponent(lanSession.roomId)}&player=${lanSession.seat}&row=${row}&col=${col}`);
      if (!data.ok && !hasBoardState(data)) {
        handleLanFailureAndReturnHome(humanizeMessage(data.message) || '房间已不可用。');
        return;
      }
    } else {
      data = await api(`/api/move?row=${row}&col=${col}`);
    }

    applyState(data, { action: 'move', moveRow: row, moveCol: col });
    if (data.ok) {
      recordPlayerResponse(pendingResponseMs);
    }
  } catch (_error) {
    setFlash('落子失败，请重试。');
  } finally {
    setLoading(false);
  }
}

async function handleUndo() {
  if (disciplineState.active || busy || !state || reviewState.open || state.mode === 'lan') return;

  let recordSuccess = false;
  setLoading(true);
  try {
    const data = await api('/api/undo');
    applyState(data, { action: 'undo' });
    recordSuccess = !!data.ok;
  } catch (_error) {
    setFlash('悔棋失败，请重试。');
  } finally {
    setLoading(false);
  }

  if (recordSuccess) {
    recordUndoSuccess();
  }
}

async function handleHint() {
  if (disciplineState.active || busy || !state || reviewState.open || state.mode === 'lan') return;
  if (!isHumanTurn(state)) return;

  let recordSuccess = false;
  setLoading(true);
  try {
    const data = await api('/api/hint');
    if (data.ok) {
      hintPos = { row: data.row, col: data.col };
      setFlash('建议落点已标出。');
      updateButtons();
      startRaf();
      recordSuccess = true;
    } else {
      setFlash(humanizeMessage(data.message) || '当前不能请求帮助。');
    }
  } catch (_error) {
    setFlash('帮助请求失败，请重试。');
  } finally {
    setLoading(false);
  }

  if (recordSuccess) {
    recordHintSuccess();
  }
}

function openReview() {
  if (disciplineState.active) return;
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

function closeReview(force = false) {
  if (disciplineState.active && !force) return;
  reviewState.open = false;
  document.getElementById('review-panel').classList.add('hidden');
  updateReviewUI();
  updateButtons();
  startRaf();
}

function stepReview(delta) {
  if (disciplineState.active) return;
  if (!reviewState.open) return;
  const next = Math.max(0, Math.min(moveHistory.length - 1, reviewState.index + delta));
  if (next === reviewState.index) return;
  reviewState.index = next;
  updateReviewUI();
  startRaf();
}

function appendMoveSnapshots(prev, data, moveRow, moveCol) {
  const diffs = findDiffs(prev.board, data.board).filter((diff) => diff.value !== 0);
  if (diffs.length === 0) return;

  if (prev.mode === 'ai' && diffs.length === 2 && Number.isInteger(moveRow) && Number.isInteger(moveCol)) {
    const midBoard = cloneBoard(prev.board);
    midBoard[moveRow][moveCol] = prev.currentPlayer;
    pushHistoryBoard(midBoard);
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

function isRemoteLanReset(prev, data, action) {
  return action === 'poll'
    && !!prev
    && prev.mode === 'lan'
    && data.mode === 'lan'
    && prev.moveCount > 0
    && data.moveCount === 0
    && data.lastRow < 0
    && data.lastCol < 0;
}

function applyState(data, options = {}) {
  if (!hasBoardState(data)) return;

  const prev = state;
  const rawAction = options.action || 'state';
  const remoteReset = isRemoteLanReset(prev, data, rawAction);
  const action = remoteReset ? 'new' : rawAction;
  const diffs = prev ? findDiffs(prev.board, data.board) : [];
  const addedDiffs = diffs.filter((diff) => diff.value !== 0);

  state = data;
  currentMode = data.mode;
  currentDiff = data.difficulty;

  if (action === 'new' || !prev) {
    moveHistory = [cloneBoard(data.board)];
    if (data.mode !== 'ai') {
      resetDisciplineTracking();
    }
  } else if ((action === 'move' || action === 'poll') && data.ok && diffs.length > 0) {
    appendMoveSnapshots(prev, data, options.moveRow, options.moveCol);
  } else if (action === 'undo' && data.ok) {
    syncHistoryAfterUndo(data.board, data.moveCount);
  }

  if (action === 'new' || (data.ok && (action === 'move' || action === 'undo'))) {
    hintPos = null;
  }

  if (remoteReset) {
    clearResultTimer();
    hideResult();
    closeReview();
  }

  dropFrames = [];
  if (prev && !reviewState.open) {
    dropFrames = addedDiffs.map((diff) => ({
      row: diff.row,
      col: diff.col,
      stone: diff.value,
      t: 0
    }));
  }

  pulseFrames = [];
  if (!reviewState.open && action !== 'undo' && addedDiffs.length > 0) {
    pulseFrames.push({
      row: data.lastRow,
      col: data.lastCol,
      t: 0
    });
  }

  if (!data.gameOver) {
    clearResultTimer();
    hideResult();
  }

  updateModeLabel(data.mode, data.difficulty);
  showAlgoDetail(data.mode, data.difficulty);
  updateTurnIndicator(data);
  updateButtons();
  updateReviewUI();
  updateLanRoomPanel(data);
  updatePredictionPanel(data);
  updateTriviaPanel(data);
  updateDisciplineOmen(data);
  noteAiResponseReady(data, action);

  if (remoteReset) {
    setFlash('房间已重开。');
  } else if (action === 'new' && data.ok) {
    setFlash(humanizeMessage(data.message) || '新对局已开始。');
  } else if (action === 'undo') {
    setFlash(data.ok ? '已悔棋。' : (humanizeMessage(data.message) || '当前没有可悔棋的步骤。'));
  } else if (!data.ok) {
    setFlash(humanizeMessage(data.message) || '当前不能这样操作。');
  } else {
    setFlash('', 0);
  }

  checkEasyUnlock(data);
  startRaf();
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

  if (data.mode === 'lan' && !data.roomReady) {
    stone.classList.add(lanSession.seat === 1 ? 'black' : 'white');
    text.textContent = lanSession.seat === 1 ? '等待白方加入' : '等待房主开始';
    return;
  }

  if (data.mode === 'lan') {
    stone.classList.add(data.currentPlayer === 1 ? 'black' : 'white');
    text.textContent = data.currentPlayer === lanSession.seat ? '轮到你落子' : '等待对方落子';
    return;
  }

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
  if (disciplineState.active) return;
  if (lanSession.active) {
    handleLanReset();
    return;
  }
  startGame(currentMode, currentDiff);
}

function clearResultTimer() {
  if (resultTimer) {
    clearTimeout(resultTimer);
    resultTimer = null;
  }
}

function busyOverlayText() {
  const mode = state ? state.mode : currentMode;
  if (mode === 'ai') {
    return 'AI 正在计算落点';
  }
  if (mode === 'lan') {
    return '正在同步对局状态';
  }
  return '正在处理当前操作';
}

function setLoading(on) {
  busy = on;
  document.getElementById('thinking-text').textContent = busyOverlayText();
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

  const canUndo = !!state
    && state.mode !== 'lan'
    && !disciplineState.active
    && !busy
    && !reviewState.open
    && !state.gameOver
    && state.histCount > 0;

  const canHint = !!state
    && state.mode !== 'lan'
    && !disciplineState.active
    && !busy
    && !reviewState.open
    && isHumanTurn(state);

  const canReview = !!state
    && !disciplineState.active
    && !busy
    && !reviewState.open
    && state.gameOver
    && moveHistory.length > 1;

  const canPlayBoard = !!state
    && !disciplineState.active
    && !busy
    && !reviewState.open
    && isHumanTurn(state);

  undoBtn.disabled = !canUndo;
  hintBtn.disabled = !canHint;
  reviewBtn.disabled = !canReview;
  canvas.classList.toggle('locked', !canPlayBoard);
}

function formatPositionLabel(positionLabel, blackRate) {
  if (positionLabel === 'black') return '黑优';
  if (positionLabel === 'white') return '白优';
  if (positionLabel === 'even') return '均势';
  if (Math.abs(blackRate - 50) <= 5) return '均势';
  return blackRate > 50 ? '黑优' : '白优';
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
  }

  const blackRate = Number(data.blackWinRate ?? 50);
  const whiteRate = Number(data.whiteWinRate ?? (100 - blackRate));
  blackEl.textContent = `${blackRate}%`;
  whiteEl.textContent = `${whiteRate}%`;
  labelEl.textContent = formatPositionLabel(data.positionLabel, blackRate);
  scoreEl.textContent = `估值 ${data.positionScore ?? 0}`;
  blackBarEl.style.width = `${blackRate}%`;
  whiteBarEl.style.width = `${whiteRate}%`;
}

function updateTriviaPanel(data) {
  const titleEl = document.getElementById('trivia-title');
  const textEl = document.getElementById('trivia-text');

  if (!data) {
    titleEl.textContent = '等待对局开始';
    textEl.textContent = '进入对局后，这里会显示一条和五子棋相关的小知识。';
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
  if (data.mode === 'lan') {
    return !!data.roomReady && lanSession.active && lanSession.seat === data.currentPlayer;
  }
  return data.mode === 'pvp' || data.currentPlayer === 1;
}

function cloneBoard(board) {
  return board.map((row) => row.slice());
}

function boardsEqual(a, b) {
  for (let r = 0; r < SIZE; r += 1) {
    for (let c = 0; c < SIZE; c += 1) {
      if (a[r][c] !== b[r][c]) {
        return false;
      }
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
  if (rafId) {
    cancelAnimationFrame(rafId);
  }
  rafId = requestAnimationFrame(render);
}

canvas.addEventListener('click', (event) => {
  if (disciplineState.active || busy || !state || state.gameOver || reviewState.open) return;
  if (!isHumanTurn(state)) return;

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

document.getElementById('lan-room-input').addEventListener('keydown', (event) => {
  if (event.key === 'Enter') {
    event.preventDefault();
    joinLanRoom();
  }
});

window.addEventListener('beforeunload', () => {
  stopLanPolling();
  leaveLanRoom();
});

drawBoardSurface(ctx);
updateButtons();
updatePredictionPanel(null);
updateTriviaPanel(null);
refreshLanHomeHint();
applyModeLockUI();
resumePendingDisciplineSequence();
