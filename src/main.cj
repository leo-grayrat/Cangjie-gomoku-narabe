package Gomoku_narabe

import std.net.*
import std.convert.*
import std.random.*

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
    var moveCount: Int64 = 0
    var lastRow: Int64 = -1
    var lastCol: Int64 = -1
    var rng: Random = Random()

    func reset(newMode: String) {
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

    func chooseAiMove(): Point {
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
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>仓颉五子棋</title>
<style>
body {
  margin: 0;
  font-family: sans-serif;
  background: #f5f1e8;
  color: #222;
}
.wrap {
  max-width: 900px;
  margin: 24px auto;
  padding: 16px;
}
h1 {
  margin-bottom: 12px;
}
.controls {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 12px;
}
button.ctrl {
  padding: 10px 14px;
  border: none;
  background: #333;
  color: #fff;
  border-radius: 8px;
  cursor: pointer;
}
#status {
  margin-bottom: 14px;
  padding: 10px 12px;
  background: #fff;
  border-radius: 8px;
  border: 1px solid #ddd;
}
#board {
  display: grid;
  grid-template-columns: repeat(${BOARD_SIZE}, 34px);
  gap: 2px;
  background: #b88b4a;
  padding: 8px;
  width: fit-content;
  border-radius: 10px;
  box-shadow: 0 6px 18px rgba(0,0,0,0.12);
}
.cell {
  width: 34px;
  height: 34px;
  border: none;
  background: #ddb66d;
  font-size: 22px;
  line-height: 34px;
  text-align: center;
  cursor: pointer;
}
.cell.black {
  color: #111;
}
.cell.white {
  color: #fafafa;
  text-shadow: 0 0 1px #000;
}
.note {
  margin-top: 14px;
  color: #555;
  font-size: 14px;
}
</style>
</head>
<body>
<div class="wrap">
  <h1>仓颉五子棋（基础版）</h1>
  <div class="controls">
    <button class="ctrl" onclick="newGame('pvp')">本地双人</button>
    <button class="ctrl" onclick="newGame('ai')">人机对战</button>
    <button class="ctrl" onclick="refreshState()">刷新状态</button>
  </div>
  <div id="status">加载中...</div>
  <div id="board"></div>
  <div class="note">
    当前基础版：15x15 棋盘，本地双人 + 基础 AI，后端状态全部在仓颉服务端维护。
  </div>
</div>

<script>
const SIZE = ${BOARD_SIZE};

function stoneName(v) {
  if (v === 1) return '黑子';
  if (v === 2) return '白子';
  return '无';
}

async function getJson(url) {
  const res = await fetch(url);
  return await res.json();
}

async function newGame(mode) {
  const data = await getJson('/api/new?mode=' + mode);
  render(data);
}

async function move(row, col) {
  const data = await getJson('/api/move?row=' + row + '&col=' + col);
  render(data);
}

async function refreshState() {
  const data = await getJson('/api/state');
  render(data);
}

function render(data) {
  const status = document.getElementById('status');
  let text = '模式：' + (data.mode === 'ai' ? '人机对战' : '本地双人');

  if (data.gameOver) {
    if (data.winner === 0) {
      text += ' ｜ 结果：平局';
    } else {
      text += ' ｜ 获胜：' + stoneName(data.winner);
    }
  } else {
    text += ' ｜ 当前：' + stoneName(data.currentPlayer);
  }

  if (data.message) {
    text += ' ｜ 提示：' + data.message;
  }

  status.textContent = text;

  const board = document.getElementById('board');
  board.innerHTML = '';

  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) {
      const cell = document.createElement('button');
      cell.className = 'cell';
      const v = data.board[r][c];

      if (v === 1) {
        cell.textContent = '●';
        cell.classList.add('black');
      } else if (v === 2) {
        cell.textContent = '○';
        cell.classList.add('white');
      } else {
        cell.textContent = '';
      }

      cell.onclick = () => move(r, c);
      board.appendChild(cell);
    }
  }
}

refreshState();
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
        return jsonResponse(game.stateJson(true, ""))
    }

    if (path == "/api/new") {
        let mode = queryValue(query, "mode")
        game.reset(mode)
        return jsonResponse(game.stateJson(true, "新对局已创建"))
    }

    if (path == "/api/move") {
        let row = parseIntOrMinusOne(queryValue(query, "row"))
        let col = parseIntOrMinusOne(queryValue(query, "col"))

        if (row < 0 || col < 0) {
            return jsonResponse(game.stateJson(false, "参数错误"))
        }

        let result = game.playerMove(row, col)
        return jsonResponse(game.stateJson(result.ok, result.message))
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
    game.reset("pvp")
    println("Gomoku server started at http://127.0.0.1:${SERVER_PORT}/")

    try (server = TcpServerSocket(bindAt: SERVER_PORT)) {
        server.bind()

        while (true) {
            try (client = server.accept()) {
                handleClient(client)
            }
        }
    }

    return 0
}