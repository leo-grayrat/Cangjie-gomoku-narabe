package Gomoku_narabe

import std.net.*
import std.convert.*
import std.random.*
import std.sync.*

let BOARD_SIZE: Int64 = 15
let CENTER: Int64 = BOARD_SIZE / 2
let SERVER_PORT: UInt16 = 8080

class Point {
    var row: Int64
    var col: Int64

    init(row: Int64, col: Int64) {
        this.row = row
        this.col = col
    }
}

class ApiResult {
    var ok: Bool
    var message: String

    init(ok: Bool, message: String) {
        this.ok = ok
        this.message = message
    }
}

func emptyBoard(): Array<Array<Int64>> {
    return Array<Array<Int64>>(BOARD_SIZE, { i =>
        Array<Int64>(BOARD_SIZE, repeat: 0)
    })
}

func boolJson(v: Bool): String {
    if (v) {
        return "true"
    }
    return "false"
}

func otherPlayer(stone: Int64): Int64 {
    if (stone == 1) {
        return 2
    }
    return 1
}

func abs64(x: Int64): Int64 {
    if (x < 0) {
        return -x
    }
    return x
}

class GameState {
    var board: Array<Array<Int64>> = emptyBoard()
    var currentPlayer: Int64 = 1
    var gameOver: Bool = false
    var winner: Int64 = 0
    var mode: String = "pvp"
    var difficulty: String = "greedy"
    var moveCount: Int64 = 0
    var lastRow: Int64 = -1
    var lastCol: Int64 = -1
    var rng: Random = Random()

    func reset(newMode: String, newDiff: String) {
        this.board = emptyBoard()
        this.currentPlayer = 1
        this.gameOver = false
        this.winner = 0
        this.moveCount = 0
        this.lastRow = -1
        this.lastCol = -1
        this.mode = "pvp"
        if (newMode == "ai") {
            this.mode = "ai"
        }
        this.difficulty = newDiff
    }

    func isInside(row: Int64, col: Int64): Bool {
        return row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE
    }

    func countDirection(row: Int64, col: Int64, dr: Int64, dc: Int64, stone: Int64): Int64 {
        var r = row + dr
        var c = col + dc
        var count: Int64 = 0

        while (this.isInside(r, c) && this.board[r][c] == stone) {
            count += 1
            r += dr
            c += dc
        }

        return count
    }

    func lineCount(row: Int64, col: Int64, dr: Int64, dc: Int64, stone: Int64): Int64 {
        return 1 +
            this.countDirection(row, col, dr, dc, stone) +
            this.countDirection(row, col, -dr, -dc, stone)
    }

    func hasFive(row: Int64, col: Int64, stone: Int64): Bool {
        if (this.lineCount(row, col, 1, 0, stone) >= 5) {
            return true
        }
        if (this.lineCount(row, col, 0, 1, stone) >= 5) {
            return true
        }
        if (this.lineCount(row, col, 1, 1, stone) >= 5) {
            return true
        }
        if (this.lineCount(row, col, 1, -1, stone) >= 5) {
            return true
        }
        return false
    }

    func placeCurrentStone(row: Int64, col: Int64) {
        let stone = this.currentPlayer
        this.board[row][col] = stone
        this.lastRow = row
        this.lastCol = col
        this.moveCount += 1

        if (this.hasFive(row, col, stone)) {
            this.gameOver = true
            this.winner = stone
            return
        }

        if (this.moveCount >= BOARD_SIZE * BOARD_SIZE) {
            this.gameOver = true
            this.winner = 0
            return
        }

        this.currentPlayer = otherPlayer(stone)
    }

    func openEnd(row: Int64, col: Int64, dr: Int64, dc: Int64, sameCount: Int64): Bool {
        let r = row + dr * (sameCount + 1)
        let c = col + dc * (sameCount + 1)
        if (!this.isInside(r, c)) {
            return false
        }
        return this.board[r][c] == 0
    }

    func patternScore(length: Int64, openEnds: Int64): Int64 {
        if (length >= 5) {
            return 100000
        }
        if (length == 4 && openEnds == 2) {
            return 10000
        }
        if (length == 4 && openEnds == 1) {
            return 4000
        }
        if (length == 3 && openEnds == 2) {
            return 1500
        }
        if (length == 3 && openEnds == 1) {
            return 400
        }
        if (length == 2 && openEnds == 2) {
            return 120
        }
        if (length == 2 && openEnds == 1) {
            return 40
        }
        if (length == 1 && openEnds == 2) {
            return 10
        }
        return 1
    }

    func directionScore(row: Int64, col: Int64, dr: Int64, dc: Int64, stone: Int64): Int64 {
        let left = this.countDirection(row, col, -dr, -dc, stone)
        let right = this.countDirection(row, col, dr, dc, stone)
        let length = left + right + 1

        var openEnds: Int64 = 0
        if (this.openEnd(row, col, -dr, -dc, left)) {
            openEnds += 1
        }
        if (this.openEnd(row, col, dr, dc, right)) {
            openEnds += 1
        }

        return this.patternScore(length, openEnds)
    }

    func pointScore(row: Int64, col: Int64, stone: Int64): Int64 {
        if (!this.isInside(row, col) || this.board[row][col] != 0) {
            return -1
        }

        return this.directionScore(row, col, 1, 0, stone) +
            this.directionScore(row, col, 0, 1, stone) +
            this.directionScore(row, col, 1, 1, stone) +
            this.directionScore(row, col, 1, -1, stone)
    }

    func hasNearbyStone(row: Int64, col: Int64, dist: Int64): Bool {
        var dr = -dist
        while (dr <= dist) {
            var dc = -dist
            while (dc <= dist) {
                if (!(dr == 0 && dc == 0)) {
                    let nr = row + dr
                    let nc = col + dc
                    if (this.isInside(nr, nc) && this.board[nr][nc] != 0) {
                        return true
                    }
                }
                dc += 1
            }
            dr += 1
        }
        return false
    }

    func centerBias(row: Int64, col: Int64): Int64 {
        return abs64(row - CENTER) + abs64(col - CENTER)
    }

    func chooseGreedy(): Point {
        if (this.board[CENTER][CENTER] == 0) {
            return Point(CENTER, CENTER)
        }

        var bestRow: Int64 = -1
        var bestCol: Int64 = -1
        var bestScore: Int64 = -1
        var bestBias: Int64 = 1_000_000

        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) {
                    continue
                }

                if (this.moveCount > 1 && !this.hasNearbyStone(row, col, 2)) {
                    continue
                }

                let attack = this.pointScore(row, col, 2)
                let defend = this.pointScore(row, col, 1)

                var score = attack * 2 + defend

                if (attack >= 100000) {
                    score = 2_000_000
                } else if (defend >= 100000) {
                    score = 1_500_000
                }

                let bias = this.centerBias(row, col)

                if (score > bestScore || (score == bestScore && bias < bestBias)) {
                    bestScore = score
                    bestBias = bias
                    bestRow = row
                    bestCol = col
                }
            }
        }

        if (bestRow >= 0) {
            return Point(bestRow, bestCol)
        }

        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] == 0) {
                    return Point(row, col)
                }
            }
        }

        return Point(0, 0)
    }

    func evaluate(): Int64 {
        var score: Int64 = 0
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                let v = this.board[row][col]
                if (v == 2) {
                    score += this.pointScore(row, col, 2)
                } else if (v == 1) {
                    score -= this.pointScore(row, col, 1)
                }
            }
        }
        return score
    }

    func candidates(): Array<Point> {
        if (this.moveCount == 0) {
            let only = Array<Point>(1, { _ => Point(CENTER, CENTER) })
            return only
        }
        var result = Array<Point>(BOARD_SIZE * BOARD_SIZE, { _ => Point(0, 0) })
        var count: Int64 = 0
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) {
                    continue
                }
                if (!this.hasNearbyStone(row, col, 2)) {
                    continue
                }
                result[count] = Point(row, col)
                count += 1
            }
        }
        return result[0..count]
    }

    func minimax(depth: Int64, isMax: Bool): Int64 {
        if (this.gameOver) {
            if (this.winner == 2) { return 1_000_000 + depth }
            if (this.winner == 1) { return -1_000_000 - depth }
            return 0
        }
        if (depth == 0) {
            return this.evaluate()
        }
        let pts = this.candidates()
        if (pts.size == 0) {
            return this.evaluate()
        }
        if (isMax) {
            var best: Int64 = -2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 2
                let prevOver = this.gameOver
                let prevWinner = this.winner
                let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 2)) {
                    this.gameOver = true
                    this.winner = 2
                }
                this.currentPlayer = 1
                let v = this.minimax(depth - 1, false)
                this.board[p.row][p.col] = 0
                this.gameOver = prevOver
                this.winner = prevWinner
                this.currentPlayer = prevPlayer
                this.moveCount -= 1
                if (v > best) { best = v }
            }
            return best
        } else {
            var best: Int64 = 2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 1
                let prevOver = this.gameOver
                let prevWinner = this.winner
                let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 1)) {
                    this.gameOver = true
                    this.winner = 1
                }
                this.currentPlayer = 2
                let v = this.minimax(depth - 1, true)
                this.board[p.row][p.col] = 0
                this.gameOver = prevOver
                this.winner = prevWinner
                this.currentPlayer = prevPlayer
                this.moveCount -= 1
                if (v < best) { best = v }
            }
            return best
        }
    }

    func chooseMinimax(): Point {
        let pts = this.candidates()
        var bestRow: Int64 = pts[0].row
        var bestCol: Int64 = pts[0].col
        var best: Int64 = -2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 2
            let prevOver = this.gameOver
            let prevWinner = this.winner
            let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 2)) {
                this.gameOver = true
                this.winner = 2
            }
            this.currentPlayer = 1
            let v = this.minimax(2, false)
            this.board[p.row][p.col] = 0
            this.gameOver = prevOver
            this.winner = prevWinner
            this.currentPlayer = prevPlayer
            this.moveCount -= 1
            if (v > best) {
                best = v
                bestRow = p.row
                bestCol = p.col
            }
        }
        return Point(bestRow, bestCol)
    }

    func alphaBeta(depth: Int64, alpha: Int64, beta: Int64, isMax: Bool): Int64 {
        if (this.gameOver) {
            if (this.winner == 2) { return 1_000_000 + depth }
            if (this.winner == 1) { return -1_000_000 - depth }
            return 0
        }
        if (depth == 0) {
            return this.evaluate()
        }
        let pts = this.candidates()
        if (pts.size == 0) {
            return this.evaluate()
        }
        var a = alpha
        var b = beta
        if (isMax) {
            var best: Int64 = -2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 2
                let prevOver = this.gameOver
                let prevWinner = this.winner
                let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 2)) {
                    this.gameOver = true
                    this.winner = 2
                }
                this.currentPlayer = 1
                let v = this.alphaBeta(depth - 1, a, b, false)
                this.board[p.row][p.col] = 0
                this.gameOver = prevOver
                this.winner = prevWinner
                this.currentPlayer = prevPlayer
                this.moveCount -= 1
                if (v > best) { best = v }
                if (v > a) { a = v }
                if (a >= b) { return best }
            }
            return best
        } else {
            var best: Int64 = 2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 1
                let prevOver = this.gameOver
                let prevWinner = this.winner
                let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 1)) {
                    this.gameOver = true
                    this.winner = 1
                }
                this.currentPlayer = 2
                let v = this.alphaBeta(depth - 1, a, b, true)
                this.board[p.row][p.col] = 0
                this.gameOver = prevOver
                this.winner = prevWinner
                this.currentPlayer = prevPlayer
                this.moveCount -= 1
                if (v < best) { best = v }
                if (v < b) { b = v }
                if (a >= b) { return best }
            }
            return best
        }
    }

    func chooseAlphaBeta(): Point {
        let pts = this.candidates()
        var bestRow: Int64 = pts[0].row
        var bestCol: Int64 = pts[0].col
        var best: Int64 = -2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 2
            let prevOver = this.gameOver
            let prevWinner = this.winner
            let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 2)) {
                this.gameOver = true
                this.winner = 2
            }
            this.currentPlayer = 1
            let v = this.alphaBeta(4, -2_000_000, 2_000_000, false)
            this.board[p.row][p.col] = 0
            this.gameOver = prevOver
            this.winner = prevWinner
            this.currentPlayer = prevPlayer
            this.moveCount -= 1
            if (v > best) {
                best = v
                bestRow = p.row
                bestCol = p.col
            }
        }
        return Point(bestRow, bestCol)
    }

    func findWinningMove(stone: Int64): Int64 {
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] == 0 && this.pointScore(row, col, stone) >= 100000) {
                    return row * BOARD_SIZE + col
                }
            }
        }
        return -1
    }

    func chooseSolver(): Point {
        let win = this.findWinningMove(2)
        if (win >= 0) {
            return Point(win / BOARD_SIZE, win % BOARD_SIZE)
        }
        let block = this.findWinningMove(1)
        if (block >= 0) {
            return Point(block / BOARD_SIZE, block % BOARD_SIZE)
        }
        return this.chooseAlphaBeta()
    }

    func chooseAiMove(): Point {
        if (this.difficulty == "minimax") {
            return this.chooseMinimax()
        }
        if (this.difficulty == "alphabeta") {
            return this.chooseAlphaBeta()
        }
        if (this.difficulty == "solver") {
            return this.chooseSolver()
        }
        return this.chooseGreedy()
    }

    func playerMove(row: Int64, col: Int64): ApiResult {
        if (this.gameOver) {
            return ApiResult(false, "游戏已经结束，请重新开始")
        }

        if (!this.isInside(row, col)) {
            return ApiResult(false, "坐标越界")
        }

        if (this.board[row][col] != 0) {
            return ApiResult(false, "该位置已有棋子")
        }

        if (this.mode == "ai" && this.currentPlayer != 1) {
            return ApiResult(false, "请等待 AI 落子")
        }

        this.placeCurrentStone(row, col)

        if (this.mode == "ai" && !this.gameOver && this.currentPlayer == 2) {
            let ai = this.chooseAiMove()
            this.placeCurrentStone(ai.row, ai.col)
            return ApiResult(true, "你已落子，AI 已应手")
        }

        return ApiResult(true, "落子成功")
    }

    func boardJson(): String {
        var s = "["
        for (row in 0..BOARD_SIZE) {
            if (row > 0) {
                s += ","
            }
            s += "["
            for (col in 0..BOARD_SIZE) {
                if (col > 0) {
                    s += ","
                }
                s += "${this.board[row][col]}"
            }
            s += "]"
        }
        s += "]"
        return s
    }

    func stateJson(ok: Bool, message: String): String {
        return "{"
            + "\"ok\":" + boolJson(ok) + ","
            + "\"message\":\"" + message + "\","
            + "\"size\":" + "${BOARD_SIZE}" + ","
            + "\"mode\":\"" + this.mode + "\","
            + "\"difficulty\":\"" + this.difficulty + "\","
            + "\"currentPlayer\":" + "${this.currentPlayer}" + ","
            + "\"gameOver\":" + boolJson(this.gameOver) + ","
            + "\"winner\":" + "${this.winner}" + ","
            + "\"moveCount\":" + "${this.moveCount}" + ","
            + "\"lastRow\":" + "${this.lastRow}" + ","
            + "\"lastCol\":" + "${this.lastCol}" + ","
            + "\"board\":" + this.boardJson()
            + "}"
    }
}

let game = GameState()
let gameMutex = Mutex()

func httpResponse(status: String, contentType: String, body: String): Array<Byte> {
    let bodyBytes = body.toArray()
    let header =
        "HTTP/1.1 ${status}\r\n"
        + "Content-Type: ${contentType}; charset=utf-8\r\n"
        + "Cache-Control: no-store\r\n"
        + "Content-Length: ${bodyBytes.size}\r\n"
        + "Connection: close\r\n"
        + "\r\n"
    return (header + body).toArray()
}

func htmlResponse(body: String): Array<Byte> {
    return httpResponse("200 OK", "text/html", body)
}

func jsonResponse(body: String): Array<Byte> {
    return httpResponse("200 OK", "application/json", body)
}

func textResponse(status: String, body: String): Array<Byte> {
    return httpResponse(status, "text/plain", body)
}

func readRequest(client: TcpSocket): String {
    let buf = Array<Byte>(8192, repeat: 0)
    let count = client.read(buf)
    if (count <= 0) {
        return ""
    }
    return String.fromUtf8(buf)
}

func queryValue(query: String, key: String): String {
    if (query == "") {
        return ""
    }

    let parts = query.split("&")
    for (part in parts) {
        let kv = part.split("=")
        if (kv.size >= 2 && kv[0] == key) {
            return kv[1]
        }
    }

    return ""
}

func parseIntOrMinusOne(text: String): Int64 {
    match (Int64.tryParse(text)) {
        case Some(v) => return v
        case None => return -1
    }
}

func indexPage(): String {
    return """
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>仓颉五子棋</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'PingFang SC','Microsoft YaHei',sans-serif;background:#1a1a2e;color:#e0e0e0;min-height:100vh;display:flex;align-items:flex-start;justify-content:center;padding:24px 16px}
.wrap{width:100%;max-width:600px}
h1{font-size:1.5rem;font-weight:600;letter-spacing:.05em;margin-bottom:16px;color:#f0c87a}
.controls{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.ctrl{padding:7px 12px;border:1px solid #444;background:#2a2a3e;color:#ccc;border-radius:6px;cursor:pointer;font-size:13px;transition:background .15s,color .15s}
.ctrl:hover{background:#3a3a5e;color:#fff}
.ctrl.active{background:#f0c87a;color:#1a1a2e;border-color:#f0c87a;font-weight:600}
#status{margin-bottom:12px;padding:9px 12px;background:#2a2a3e;border-radius:6px;font-size:14px;min-height:36px;border-left:3px solid #f0c87a}
#status.loading{border-left-color:#888;color:#888}
.board-wrap{position:relative;width:fit-content}
#board{
  display:grid;
  grid-template-columns:repeat(${BOARD_SIZE},36px);
  background:#c8933a;
  padding:10px;
  border-radius:8px;
  gap:0;
  box-shadow:0 8px 24px rgba(0,0,0,.5);
  user-select:none
}
#board.locked{pointer-events:none;opacity:.7}
.cell{
  width:36px;height:36px;
  border:none;
  background:transparent;
  cursor:pointer;
  position:relative;
  display:flex;align-items:center;justify-content:center
}
.cell::before,.cell::after{content:'';position:absolute;background:#7a5c20;pointer-events:none}
.cell::before{width:100%;height:1px;top:50%;transform:translateY(-50%)}
.cell::after{width:1px;height:100%;left:50%;transform:translateX(-50%)}
.cell:first-child::before,.cell:nth-child(${BOARD_SIZE})::before{width:50%}
.cell:first-child::before{left:50%}
.stone{
  width:28px;height:28px;
  border-radius:50%;
  position:relative;z-index:1;
  box-shadow:1px 2px 4px rgba(0,0,0,.5)
}
.stone.black{background:radial-gradient(circle at 35% 35%,#666,#111)}
.stone.white{background:radial-gradient(circle at 35% 35%,#fff,#ccc)}
.stone.last{box-shadow:0 0 0 2px #f0c87a,1px 2px 4px rgba(0,0,0,.5)}
.note{margin-top:12px;color:#666;font-size:12px}
</style>
</head>
<body>
<div class="wrap">
  <h1>仓颉五子棋</h1>
  <div class="controls">
    <button class="ctrl" id="btn-pvp"       onclick="newGame('pvp','greedy')">本地双人</button>
    <button class="ctrl" id="btn-greedy"    onclick="newGame('ai','greedy')">人机·贪心</button>
    <button class="ctrl" id="btn-minimax"   onclick="newGame('ai','minimax')">人机·Minimax</button>
    <button class="ctrl" id="btn-alphabeta" onclick="newGame('ai','alphabeta')">人机·Alpha-Beta</button>
    <button class="ctrl" id="btn-solver"    onclick="newGame('ai','solver')">人机·必胜</button>
  </div>
  <div id="status">加载中...</div>
  <div class="board-wrap"><div id="board"></div></div>
  <div class="note">15×15，仓颉后端。难度：贪心 &lt; Minimax &lt; Alpha-Beta &lt; 必胜</div>
</div>

<script>
const SIZE = ${BOARD_SIZE};
let busy = false;
let lastData = null;

function stoneName(v){return v===1?'黑子':v===2?'白子':'无'}

function setLoading(on){
  busy = on;
  const b = document.getElementById('board');
  const s = document.getElementById('status');
  if(on){b.classList.add('locked');s.classList.add('loading')}
  else{b.classList.remove('locked');s.classList.remove('loading')}
}

async function getJson(url){
  const res = await fetch(url);
  return res.json();
}

async function newGame(mode, diff){
  if(busy) return;
  setLoading(true);
  try{
    const data = await getJson('/api/new?mode='+mode+'&diff='+diff);
    render(data);
    highlightBtn(mode, diff);
  }finally{setLoading(false)}
}

async function doMove(row, col){
  if(busy) return;
  setLoading(true);
  try{
    const data = await getJson('/api/move?row='+row+'&col='+col);
    render(data);
  }finally{setLoading(false)}
}

function highlightBtn(mode, diff){
  document.querySelectorAll('.ctrl').forEach(b=>b.classList.remove('active'));
  const id = mode==='pvp'?'btn-pvp':'btn-'+diff;
  const el = document.getElementById(id);
  if(el) el.classList.add('active');
}

function render(data){
  lastData = data;
  const diffName={greedy:'贪心',minimax:'Minimax',alphabeta:'Alpha-Beta',solver:'必胜'}[data.difficulty]||data.difficulty;
  const s = document.getElementById('status');
  s.classList.remove('loading');
  let text = data.mode==='ai'?('人机对战·'+diffName):'本地双人';
  if(data.gameOver){
    text += data.winner===0?' ｜ 平局':' ｜ 获胜：'+stoneName(data.winner);
  }else{
    text += ' ｜ 当前：'+stoneName(data.currentPlayer);
    if(data.mode==='ai'&&data.currentPlayer===2) text += '（AI 思考中…）';
  }
  if(data.message) text += ' ｜ '+data.message;
  s.textContent = text;

  const canClick = !data.gameOver && !(data.mode==='ai' && data.currentPlayer===2);

  const board = document.getElementById('board');
  board.innerHTML='';
  for(let r=0;r<SIZE;r++){
    for(let c=0;c<SIZE;c++){
      const cell = document.createElement('div');
      cell.className='cell';
      const v = data.board[r][c];
      if(v){
        const stone=document.createElement('div');
        stone.className='stone '+(v===1?'black':'white');
        if(r===data.lastRow&&c===data.lastCol) stone.classList.add('last');
        cell.appendChild(stone);
      }else if(canClick){
        cell.style.cursor='pointer';
        cell.onclick=()=>doMove(r,c);
      }else{
        cell.style.cursor='default';
      }
      board.appendChild(cell);
    }
  }
}

(async()=>{
  try{
    const data=await getJson('/api/state');
    render(data);
    highlightBtn(data.mode, data.difficulty);
  }catch(e){
    document.getElementById('status').textContent='请点击上方按钮开始游戏';
  }
})();
</script>
</body>
</html>
"""
}

func handleRequest(request: String): Array<Byte> {
    if (request == "") {
        return textResponse("400 Bad Request", "empty request")
    }

    let lines = request.split("\r\n")
    if (lines.size == 0) {
        return textResponse("400 Bad Request", "bad request")
    }

    let firstLine = lines[0]
    let parts = firstLine.split(" ")
    if (parts.size < 2) {
        return textResponse("400 Bad Request", "bad request line")
    }

    let method = parts[0]
    let target = parts[1]

    if (method != "GET") {
        return textResponse("405 Method Not Allowed", "only GET is supported in this basic version")
    }

    let pair = target.split("?")
    let path = pair[0]
    var query = ""
    if (pair.size > 1) {
        query = pair[1]
    }

    if (path == "/") {
        return htmlResponse(indexPage())
    }

    if (path == "/api/state") {
        synchronized(gameMutex) {
            return jsonResponse(game.stateJson(true, ""))
        }
    }

    if (path == "/api/new") {
        let mode = queryValue(query, "mode")
        let diff = queryValue(query, "diff")
        synchronized(gameMutex) {
            game.reset(mode, diff)
            return jsonResponse(game.stateJson(true, "新对局已创建"))
        }
    }

    if (path == "/api/move") {
        let row = parseIntOrMinusOne(queryValue(query, "row"))
        let col = parseIntOrMinusOne(queryValue(query, "col"))

        if (row < 0 || col < 0) {
            synchronized(gameMutex) {
                return jsonResponse(game.stateJson(false, "参数错误"))
            }
        }

        synchronized(gameMutex) {
            let result = game.playerMove(row, col)
            return jsonResponse(game.stateJson(result.ok, result.message))
        }
    }

    if (path == "/favicon.ico") {
        return textResponse("404 Not Found", "")
    }

    return textResponse("404 Not Found", "not found")
}

func handleClient(client: TcpSocket) {
    let request = readRequest(client)
    let response = handleRequest(request)
    client.write(response)
}

main(): Int64 {
    game.reset("pvp", "greedy")
    println("Gomoku server started at http://127.0.0.1:${SERVER_PORT}/")

    try (server = TcpServerSocket(bindAt: SERVER_PORT)) {
        server.bind()

        while (true) {
            let client = server.accept()
            spawn {
                try (c = client) {
                    handleClient(c)
                }
            }
        }
    }

    return 0
}