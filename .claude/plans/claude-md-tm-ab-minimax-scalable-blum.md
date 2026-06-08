# 新功能实现计划：悔棋、复盘、帮助

## Context

在现有五子棋项目基础上新增三个实用功能：
- **悔棋**：人机模式同时撤销玩家+AI各1步；PVP模式撤销1步
- **复盘**：前端记录每步落子，对局结束后可逐步回放
- **帮助**：后端新增 `/api/hint` 端点，前端棋盘高亮显示推荐落点

## 修改文件

- `src/game.cj` — 新增历史栈字段、undo逻辑、hint端点处理
- `src/main.cj` — 新增 `/api/undo`、`/api/hint` 路由
- `frontend/index.html` — 新增游戏区按钮（悔棋、帮助、复盘）和复盘UI
- `frontend/style.css` — 新增按钮/复盘UI样式
- `frontend/app.js` — 新增悔棋/帮助/复盘逻辑

---

## 1. 后端：game.cj 修改

### 新增字段（GameState class）

```cangjie
var history: Array<Array<Array<Int64>>> = Array<Array<Array<Int64>>>(0, { _ => emptyBoard() })
var historyPlayer: Array<Int64> = Array<Int64>(0, repeat: 0)
// 使用动态增长的简单实现：记录每步落子前的棋盘快照
```

仓颉没有内置动态数组，用固定容量 225（15×15）数组模拟栈：

```cangjie
var histBoards: Array<Array<Array<Int64>>> = Array<Array<Array<Int64>>>(226, { _ => emptyBoard() })
var histPlayers: Array<Int64> = Array<Int64>(226, repeat: 0)
var histCount: Int64 = 0
```

### reset() 中清空历史

```cangjie
this.histCount = 0
```

### placeCurrentStone() 前记录快照

在 `playerMove` 调用 `placeCurrentStone` 前记录快照（而不是在 placeCurrentStone 内，避免AI内部搜索时误记录）。

### 新增 undo() 方法

```cangjie
func undo(): ApiResult {
    if (this.histCount == 0) { return ApiResult(false, "没有可悔棋的步骤") }
    if (this.gameOver) { return ApiResult(false, "对局已结束，请通过复盘查看") }
    // PVP: 撤销1步；AI模式: 撤销2步（玩家+AI），但如果只有1步也只撤销1步
    let stepsToUndo = if (this.mode == "ai" && this.histCount >= 2) { 2 } else { 1 }
    let target = this.histCount - stepsToUndo
    // 恢复到目标快照
    let savedBoard = this.histBoards[target]
    for (r in 0..BOARD_SIZE) {
        for (c in 0..BOARD_SIZE) {
            this.board[r][c] = savedBoard[r][c]
        }
    }
    this.currentPlayer = this.histPlayers[target]
    this.histCount = target
    this.moveCount -= stepsToUndo
    this.lastRow = -1
    this.lastCol = -1
    this.gameOver = false
    this.winner = 0
    return ApiResult(true, "悔棋成功")
}
```

### playerMove() 中保存快照

在 `placeCurrentStone` 调用前插入：

```cangjie
// 保存当前棋盘快照
let snap = Array<Array<Int64>>(BOARD_SIZE, { r => Array<Int64>(BOARD_SIZE, { c => this.board[r][c] }) })
this.histBoards[this.histCount] = snap
this.histPlayers[this.histCount] = this.currentPlayer
this.histCount += 1
```

对 AI 落子也同样记录（在 AI placeCurrentStone 前）。

### 新增 hint() 方法

```cangjie
func hint(): Point {
    // 直接复用 AI 决策，但强制用 hard 强度（不依赖当前difficulty）
    let win = this.findWinningMove(this.currentPlayer)
    if (win >= 0) { return Point(win / BOARD_SIZE, win % BOARD_SIZE) }
    let block = this.findWinningMove(otherPlayer(this.currentPlayer))
    if (block >= 0) { return Point(block / BOARD_SIZE, block % BOARD_SIZE) }
    return this.chooseAlphaBetaN(4, 15)
}
```

hint 返回 JSON：`{"ok":true,"row":7,"col":8}`

### stateJson 新增 histCount 字段

便于前端判断是否可悔棋：
```
"histCount":" + "${this.histCount}" + ","
```

---

## 2. 后端：main.cj 新增路由

```cangjie
} else if (path == "/api/undo") {
    let result = gs.undo()
    send(client, jsonResponse(gs.stateJson(result.ok, result.message)))
} else if (path == "/api/hint") {
    if (gs.gameOver || (gs.mode == "ai" && gs.currentPlayer != 1)) {
        send(client, jsonResponse("{\"ok\":false,\"row\":-1,\"col\":-1}"))
    } else {
        let p = gs.hint()
        send(client, jsonResponse("{\"ok\":true,\"row\":" + "${p.row}" + ",\"col\":" + "${p.col}" + "}"))
    }
}
```

---

## 3. 前端：index.html 修改

### 游戏区按钮栏（新增在 board-container 后）

```html
<div class="game-actions">
  <button class="action-btn" id="btn-undo" onclick="doUndo()">悔棋</button>
  <button class="action-btn" id="btn-hint" onclick="doHint()">帮助</button>
  <button class="action-btn" id="btn-review" onclick="startReview()">复盘</button>
</div>
```

### 复盘UI（覆盖在游戏视图内，默认hidden）

```html
<div id="review-overlay" class="review-overlay hidden">
  <div class="review-header">
    <span id="review-step">第 0 / 0 步</span>
    <div class="review-controls">
      <button onclick="reviewStep(-1)">‹ 上一步</button>
      <button onclick="reviewStep(1)">下一步 ›</button>
      <button onclick="closeReview()">退出复盘</button>
    </div>
  </div>
  <canvas id="board-review" width="560" height="560"></canvas>
</div>
```

---

## 4. 前端：app.js 新增逻辑

### 悔棋

```js
async function doUndo() {
  if (busy) return;
  setLoading(true);
  try {
    const data = await api('/api/undo');
    if (data.ok) { hintPos = null; applyState(data); }
    else alert(data.message);
  } finally { setLoading(false); }
}
```

### 帮助（棋盘高亮）

```js
let hintPos = null; // {row, col}

async function doHint() {
  if (busy || !state || state.gameOver) return;
  if (state.mode === 'ai' && state.currentPlayer !== 1) return;
  setLoading(true);
  try {
    const data = await fetch('/api/hint').then(r => r.json());
    if (data.ok) { hintPos = {row: data.row, col: data.col}; startRaf(); }
  } finally { setLoading(false); }
}

// render() 中在静态棋子绘制后添加：
function drawHint(row, col) {
  const x = cx(col), y = cy(row);
  ctx.beginPath(); ctx.arc(x, y, RADIUS * 0.55, 0, Math.PI*2);
  ctx.fillStyle = 'rgba(80,180,120,0.7)'; ctx.fill();
  ctx.strokeStyle = '#50b478'; ctx.lineWidth = 2; ctx.stroke();
}
// in render(): if (hintPos) drawHint(hintPos.row, hintPos.col);
// 落子时清除 hint：hintPos = null;
```

### 复盘

```js
// moveHistory 记录每次成功落子后的完整棋盘快照
let moveHistory = []; // [{board, lastRow, lastCol}]
let reviewIdx = 0;
const reviewCanvas = document.getElementById('board-review');
const reviewCtx = reviewCanvas.getContext('2d');
reviewCanvas.width = BOARD_PX; reviewCanvas.height = BOARD_PX;

// applyState() 中追加记录
// 在 new game 时清空：moveHistory = [];

function startReview() {
  if (!state || moveHistory.length === 0) return;
  reviewIdx = moveHistory.length; // 从最终局面开始
  renderReview();
  document.getElementById('review-overlay').classList.remove('hidden');
}
function closeReview() { document.getElementById('review-overlay').classList.add('hidden'); }
function reviewStep(delta) {
  reviewIdx = Math.max(0, Math.min(moveHistory.length, reviewIdx + delta));
  renderReview();
}
function renderReview() {
  // 用 reviewCtx 绘制 moveHistory[reviewIdx-1] 的棋盘
  document.getElementById('review-step').textContent = `第 ${reviewIdx} / ${moveHistory.length} 步`;
  // 复用 drawBoard/drawStone 但绘制到 reviewCtx
}
```

---

## 按钮状态联动

- 悔棋：`histCount === 0` 或 `gameOver` 时 disabled
- 帮助：`gameOver` 或 AI回合时 disabled  
- 复盘：`moveHistory.length === 0` 时 disabled

---

## 验证

1. `cjpm build` 编译通过
2. 启动服务器
3. 下几步 → 点悔棋 → 确认棋盘回退
4. 点帮助 → 棋盘上出现绿色推荐标记
5. 对局结束 → 点复盘 → 能逐步前进/后退回放全程
