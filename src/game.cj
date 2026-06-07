package Gomoku_narabe

import std.random.*

class GameState {
    var board: Array<Array<Int64>> = emptyBoard()
    var currentPlayer: Int64 = 1
    var gameOver: Bool = false
    var winner: Int64 = 0
    var mode: String = "pvp"
    var difficulty: String = "easy"
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
        this.mode = if (newMode == "ai") { "ai" } else { "pvp" }
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
        return 1 + this.countDirection(row, col, dr, dc, stone) + this.countDirection(row, col, -dr, -dc, stone)
    }

    func hasFive(row: Int64, col: Int64, stone: Int64): Bool {
        return this.lineCount(row, col, 1, 0, stone) >= 5
            || this.lineCount(row, col, 0, 1, stone) >= 5
            || this.lineCount(row, col, 1, 1, stone) >= 5
            || this.lineCount(row, col, 1, -1, stone) >= 5
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
        if (!this.isInside(r, c)) { return false }
        return this.board[r][c] == 0
    }

    func patternScore(length: Int64, openEnds: Int64): Int64 {
        if (length >= 5)              { return 100000 }
        if (length == 4 && openEnds == 2) { return 10000 }
        if (length == 4 && openEnds == 1) { return 4000 }
        if (length == 3 && openEnds == 2) { return 1500 }
        if (length == 3 && openEnds == 1) { return 400 }
        if (length == 2 && openEnds == 2) { return 120 }
        if (length == 2 && openEnds == 1) { return 40 }
        if (length == 1 && openEnds == 2) { return 10 }
        return 1
    }

    func directionScore(row: Int64, col: Int64, dr: Int64, dc: Int64, stone: Int64): Int64 {
        let left = this.countDirection(row, col, -dr, -dc, stone)
        let right = this.countDirection(row, col, dr, dc, stone)
        let length = left + right + 1
        var openEnds: Int64 = 0
        if (this.openEnd(row, col, -dr, -dc, left)) { openEnds += 1 }
        if (this.openEnd(row, col, dr, dc, right))  { openEnds += 1 }
        return this.patternScore(length, openEnds)
    }

    func pointScore(row: Int64, col: Int64, stone: Int64): Int64 {
        if (!this.isInside(row, col) || this.board[row][col] != 0) { return -1 }
        return this.directionScore(row, col, 1, 0, stone)
            + this.directionScore(row, col, 0, 1, stone)
            + this.directionScore(row, col, 1, 1, stone)
            + this.directionScore(row, col, 1, -1, stone)
    }

    func hasNearbyStone(row: Int64, col: Int64, dist: Int64): Bool {
        var dr = -dist
        while (dr <= dist) {
            var dc = -dist
            while (dc <= dist) {
                if (!(dr == 0 && dc == 0)) {
                    let nr = row + dr
                    let nc = col + dc
                    if (this.isInside(nr, nc) && this.board[nr][nc] != 0) { return true }
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

    // --- AI core ---

    func evaluate(): Int64 {
        var score: Int64 = 0
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                let v = this.board[row][col]
                if (v == 0) { continue }
                this.board[row][col] = 0
                let s = this.pointScore(row, col, v)
                this.board[row][col] = v
                if (v == 2) { score += s } else { score -= s }
            }
        }
        return score
    }

    func candidatesN(maxCands: Int64): Array<Point> {
        if (this.moveCount == 0) {
            return Array<Point>(1, { _ => Point(CENTER, CENTER) })
        }
        var cRows   = Array<Int64>(BOARD_SIZE * BOARD_SIZE, repeat: 0)
        var cCols   = Array<Int64>(BOARD_SIZE * BOARD_SIZE, repeat: 0)
        var cScores = Array<Int64>(BOARD_SIZE * BOARD_SIZE, repeat: 0)
        var count: Int64 = 0
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) { continue }
                if (!this.hasNearbyStone(row, col, 2)) { continue }
                let a = this.pointScore(row, col, 2)
                let d = this.pointScore(row, col, 1)
                var s: Int64 = a * 2 + d
                if (a >= 100000)      { s = 2_000_000 }
                else if (d >= 100000) { s = 1_500_000 }
                cRows[count] = row; cCols[count] = col; cScores[count] = s
                count += 1
            }
        }
        // 插入排序（降序），让 alpha-beta 从最优候选开始搜索
        var i: Int64 = 1
        while (i < count) {
            let kr = cRows[i]; let kc = cCols[i]; let ks = cScores[i]
            var j = i - 1
            while (j >= 0 && cScores[j] < ks) {
                cRows[j + 1] = cRows[j]; cCols[j + 1] = cCols[j]; cScores[j + 1] = cScores[j]
                j -= 1
            }
            cRows[j + 1] = kr; cCols[j + 1] = kc; cScores[j + 1] = ks
            i += 1
        }
        let n = if (count < maxCands) { count } else { maxCands }
        var result = Array<Point>(n, { _ => Point(0, 0) })
        var k: Int64 = 0
        while (k < n) { result[k] = Point(cRows[k], cCols[k]); k += 1 }
        return result
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

    // --- Easy: 防必输 + 70%贪心 + 30%随机邻近 ---

    func chooseEasy(): Point {
        if (this.board[CENTER][CENTER] == 0) { return Point(CENTER, CENTER) }
        // 必须防守或能赢时直接走
        let win = this.findWinningMove(2)
        if (win >= 0) { return Point(win / BOARD_SIZE, win % BOARD_SIZE) }
        let block = this.findWinningMove(1)
        if (block >= 0) { return Point(block / BOARD_SIZE, block % BOARD_SIZE) }
        // 30% 概率从邻近空格随机选
        if (this.rng.nextInt64(10) < 3) {
            var pool = Array<Point>(BOARD_SIZE * BOARD_SIZE, { _ => Point(0, 0) })
            var poolSize: Int64 = 0
            for (row in 0..BOARD_SIZE) {
                for (col in 0..BOARD_SIZE) {
                    if (this.board[row][col] == 0 && this.hasNearbyStone(row, col, 2)) {
                        pool[poolSize] = Point(row, col)
                        poolSize += 1
                    }
                }
            }
            if (poolSize > 0) {
                return pool[this.rng.nextInt64(poolSize)]
            }
        }
        // 贪心最优
        var bestRow: Int64 = -1; var bestCol: Int64 = -1
        var bestScore: Int64 = -1; var bestBias: Int64 = 1_000_000
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) { continue }
                if (!this.hasNearbyStone(row, col, 2)) { continue }
                let a = this.pointScore(row, col, 2)
                let d = this.pointScore(row, col, 1)
                let score = a * 2 + d
                let bias = this.centerBias(row, col)
                if (score > bestScore || (score == bestScore && bias < bestBias)) {
                    bestScore = score; bestBias = bias; bestRow = row; bestCol = col
                }
            }
        }
        if (bestRow >= 0) { return Point(bestRow, bestCol) }
        return Point(0, 0)
    }

    // --- Medium: Minimax 深度3，候选10 ---

    func minimax(depth: Int64, isMax: Bool): Int64 {
        if (this.gameOver) {
            if (this.winner == 2) { return 1_000_000 + depth }
            if (this.winner == 1) { return -1_000_000 - depth }
            return 0
        }
        if (depth == 0) { return this.evaluate() }
        let pts = this.candidatesN(10)
        if (pts.size == 0) { return this.evaluate() }
        if (isMax) {
            var best: Int64 = -2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 2
                let prevOver = this.gameOver; let prevWinner = this.winner; let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
                this.currentPlayer = 1
                let v = this.minimax(depth - 1, false)
                this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
                this.currentPlayer = prevPlayer; this.moveCount -= 1
                if (v > best) { best = v }
            }
            return best
        } else {
            var best: Int64 = 2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 1
                let prevOver = this.gameOver; let prevWinner = this.winner; let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 1)) { this.gameOver = true; this.winner = 1 }
                this.currentPlayer = 2
                let v = this.minimax(depth - 1, true)
                this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
                this.currentPlayer = prevPlayer; this.moveCount -= 1
                if (v < best) { best = v }
            }
            return best
        }
    }

    func chooseMinimax(): Point {
        let pts = this.candidatesN(10)
        var bestRow: Int64 = pts[0].row; var bestCol: Int64 = pts[0].col; var best: Int64 = -2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 2
            let prevOver = this.gameOver; let prevWinner = this.winner; let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
            this.currentPlayer = 1
            let v = this.minimax(3, false)
            this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
            this.currentPlayer = prevPlayer; this.moveCount -= 1
            if (v > best) { best = v; bestRow = p.row; bestCol = p.col }
        }
        return Point(bestRow, bestCol)
    }

    // --- Hard/Expert: Alpha-Beta ---

    func alphaBeta(depth: Int64, alpha: Int64, beta: Int64, isMax: Bool, maxCands: Int64): Int64 {
        if (this.gameOver) {
            if (this.winner == 2) { return 1_000_000 + depth }
            if (this.winner == 1) { return -1_000_000 - depth }
            return 0
        }
        if (depth == 0) { return this.evaluate() }
        let pts = this.candidatesN(maxCands)
        if (pts.size == 0) { return this.evaluate() }
        var a = alpha; var b = beta
        if (isMax) {
            var best: Int64 = -2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 2
                let prevOver = this.gameOver; let prevWinner = this.winner; let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
                this.currentPlayer = 1
                let v = this.alphaBeta(depth - 1, a, b, false, maxCands)
                this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
                this.currentPlayer = prevPlayer; this.moveCount -= 1
                if (v > best) { best = v }
                if (v > a) { a = v }
                if (a >= b) { return best }
            }
            return best
        } else {
            var best: Int64 = 2_000_000
            for (p in pts) {
                this.board[p.row][p.col] = 1
                let prevOver = this.gameOver; let prevWinner = this.winner; let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 1)) { this.gameOver = true; this.winner = 1 }
                this.currentPlayer = 2
                let v = this.alphaBeta(depth - 1, a, b, true, maxCands)
                this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
                this.currentPlayer = prevPlayer; this.moveCount -= 1
                if (v < best) { best = v }
                if (v < b) { b = v }
                if (a >= b) { return best }
            }
            return best
        }
    }

    func chooseAlphaBetaN(depth: Int64, maxCands: Int64): Point {
        let pts = this.candidatesN(maxCands)
        var bestRow: Int64 = pts[0].row; var bestCol: Int64 = pts[0].col; var best: Int64 = -2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 2
            let prevOver = this.gameOver; let prevWinner = this.winner; let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
            this.currentPlayer = 1
            let v = this.alphaBeta(depth, -2_000_000, 2_000_000, false, maxCands)
            this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
            this.currentPlayer = prevPlayer; this.moveCount -= 1
            if (v > best) { best = v; bestRow = p.row; bestCol = p.col }
        }
        return Point(bestRow, bestCol)
    }

    // --- Expert: 预检必胜/防守 + Alpha-Beta ---

    func chooseExpert(): Point {
        let win = this.findWinningMove(2)
        if (win >= 0) { return Point(win / BOARD_SIZE, win % BOARD_SIZE) }
        let block = this.findWinningMove(1)
        if (block >= 0) { return Point(block / BOARD_SIZE, block % BOARD_SIZE) }
        return this.chooseAlphaBetaN(4, 20)
    }

    // --- Joseki: 硬编码天元开局定式，出库后用 hard ---
    // 定式以相对天元坐标存储，每条是黑白交替的落子序列（从黑棋第一手开始）
    // 棋盘坐标 = CENTER + 相对坐标
    // AI 执白（player=2），读取定式中白棋落点（奇数位 0-indexed: 1,3,5,...）

    func josekiBlackAt(dr: Int64, dc: Int64): Bool {
        let r = CENTER + dr; let c = CENTER + dc
        return this.isInside(r, c) && this.board[r][c] == 1
    }

    func josekiEmptyAt(dr: Int64, dc: Int64): Bool {
        let r = CENTER + dr; let c = CENTER + dc
        return this.isInside(r, c) && this.board[r][c] == 0
    }

    // 返回白棋应走的相对坐标 (dr*100+dc)，-999 表示不在定式中
    func lookupJoseki(): Int64 {
        let mc = this.moveCount
        // 定式：黑首着天元 (0,0) 是前提
        if (!this.josekiBlackAt(0, 0)) { return -999 }

        // === 2手：黑天元，白的第一手（共8对称，取白棋常见应对位置）===
        if (mc == 1) {
            // 白棋走 (0,2)：直线型开局
            if (this.josekiEmptyAt(0, 2)) { return 2 }  // dr=0, dc=2
            return -999
        }

        // 以下匹配黑2手后的应对
        // 变化A：黑(0,0)→黑(0,-1)，白应(0,2)→白(0,3) 直三变化
        if (mc == 3) {
            if (this.josekiBlackAt(0, 0) && this.josekiBlackAt(0, -1) && this.josekiBlackAt(0, 2) == false) {
                // 找白第一子位置
                if (this.board[CENTER][CENTER + 2] == 2) {
                    // 黑在(0,-1)方向扩展，白应堵(0,-2)
                    if (this.josekiBlackAt(0, -1) && this.josekiEmptyAt(0, -2)) { return -200 + 0 } // dc=-2
                }
            }
            if (this.josekiBlackAt(0, 0) && this.josekiBlackAt(1, 0) && this.board[CENTER][CENTER + 2] == 2) {
                // 黑竖向扩展(1,0)，白应(2,0)堵
                if (this.josekiEmptyAt(2, 0)) { return 200 } // dr=2,dc=0
            }
            // 斜三变化：黑(1,1)，白应(-1,-1)
            if (this.josekiBlackAt(1, 1) && this.board[CENTER][CENTER + 2] == 2 && this.josekiEmptyAt(-1, -1)) {
                return -100 + (-1) // dr=-1,dc=-1 → 编码为 -1*100+(-1) = -101
            }
        }

        if (mc == 5) {
            // 直三：黑(0,0),(0,-1),(0,-2)，白(0,2),(0,3)，白应走(0,4)堵死
            if (this.josekiBlackAt(0, 0) && this.josekiBlackAt(0, -1) && this.josekiBlackAt(0, -2)
                && this.board[CENTER][CENTER + 2] == 2 && this.board[CENTER][CENTER + 3] == 2
                && this.josekiEmptyAt(0, 4)) {
                return 4  // dr=0,dc=4
            }
            // 斜三延伸：黑(0,0),(1,1),(2,2)，白(-1,-1),(-2,-2)，白应走(3,3)
            if (this.josekiBlackAt(0, 0) && this.josekiBlackAt(1, 1) && this.josekiBlackAt(2, 2)
                && this.board[CENTER - 1][CENTER - 1] == 2 && this.board[CENTER - 2][CENTER - 2] == 2
                && this.josekiEmptyAt(3, 3)) {
                return 303  // dr=3,dc=3
            }
        }

        return -999
    }

    func chooseJoseki(): Point {
        let code = this.lookupJoseki()
        if (code != -999) {
            var dr: Int64 = code / 100
            var dc: Int64 = code % 100
            // 修正负数编码（仓颉整除向零截断）
            if (code < 0 && code != -999) {
                dr = -((-code) / 100)
                dc = -((-code) % 100)
                // 重新解码: -101 → dr=-1,dc=-1; -200 → dr=-2,dc=0
                if (code == -101) { dr = -1; dc = -1 }
                else if (code == -200) { dr = -2; dc = 0 }
                else if (code == -100) { dr = -1; dc = 0 }
            }
            // code=2 时 dr=0,dc=2
            if (code == 2)   { dr = 0; dc = 2 }
            if (code == 4)   { dr = 0; dc = 4 }
            if (code == 200) { dr = 2; dc = 0 }
            if (code == 303) { dr = 3; dc = 3 }
            let row = CENTER + dr
            let col = CENTER + dc
            if (this.isInside(row, col) && this.board[row][col] == 0) {
                return Point(row, col)
            }
        }
        // 出库：用 hard 强度
        return this.chooseAlphaBetaN(4, 15)
    }

    func chooseAiMove(): Point {
        if (this.difficulty == "medium") { return this.chooseMinimax() }
        if (this.difficulty == "hard")   { return this.chooseAlphaBetaN(4, 15) }
        if (this.difficulty == "expert") { return this.chooseExpert() }
        if (this.difficulty == "joseki") { return this.chooseJoseki() }
        return this.chooseEasy()
    }

    // --- Player API ---

    func playerMove(row: Int64, col: Int64): ApiResult {
        if (this.gameOver)              { return ApiResult(false, "游戏已经结束，请重新开始") }
        if (!this.isInside(row, col))   { return ApiResult(false, "坐标越界") }
        if (this.board[row][col] != 0)  { return ApiResult(false, "该位置已有棋子") }
        if (this.mode == "ai" && this.currentPlayer != 1) { return ApiResult(false, "请等待 AI 落子") }
        this.placeCurrentStone(row, col)
        if (this.mode == "ai" && !this.gameOver && this.currentPlayer == 2) {
            let ai = this.chooseAiMove()
            this.placeCurrentStone(ai.row, ai.col)
            return ApiResult(true, "你已落子，AI 已应手")
        }
        return ApiResult(true, "落子成功")
    }

    // --- Serialization ---

    func boardJson(): String {
        var s = "["
        for (row in 0..BOARD_SIZE) {
            if (row > 0) { s += "," }
            s += "["
            for (col in 0..BOARD_SIZE) {
                if (col > 0) { s += "," }
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
