package Gomoku_narabe

import std.random.*

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

    // --- AI ---

    func evaluate(): Int64 {
        var score: Int64 = 0
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                let v = this.board[row][col]
                if (v == 0) { continue }
                // 临时移除棋子，让 pointScore 能统计该位置的棋型价值
                this.board[row][col] = 0
                let s = this.pointScore(row, col, v)
                this.board[row][col] = v
                if (v == 2) { score += s } else { score -= s }
            }
        }
        return score
    }

    func candidates(): Array<Point> {
        if (this.moveCount == 0) {
            return Array<Point>(1, { _ => Point(CENTER, CENTER) })
        }
        var result = Array<Point>(BOARD_SIZE * BOARD_SIZE, { _ => Point(0, 0) })
        var count: Int64 = 0
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) { continue }
                if (!this.hasNearbyStone(row, col, 2)) { continue }
                result[count] = Point(row, col)
                count += 1
            }
        }
        return result[0..count]
    }

    func chooseGreedy(): Point {
        if (this.board[CENTER][CENTER] == 0) { return Point(CENTER, CENTER) }
        var bestRow: Int64 = -1
        var bestCol: Int64 = -1
        var bestScore: Int64 = -1
        var bestBias: Int64 = 1_000_000
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) { continue }
                if (this.moveCount > 1 && !this.hasNearbyStone(row, col, 2)) { continue }
                let attack = this.pointScore(row, col, 2)
                let defend = this.pointScore(row, col, 1)
                var score = attack * 2 + defend
                if (attack >= 100000)      { score = 2_000_000 }
                else if (defend >= 100000) { score = 1_500_000 }
                let bias = this.centerBias(row, col)
                if (score > bestScore || (score == bestScore && bias < bestBias)) {
                    bestScore = score; bestBias = bias; bestRow = row; bestCol = col
                }
            }
        }
        if (bestRow >= 0) { return Point(bestRow, bestCol) }
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] == 0) { return Point(row, col) }
            }
        }
        return Point(0, 0)
    }

    func minimax(depth: Int64, isMax: Bool): Int64 {
        if (this.gameOver) {
            if (this.winner == 2) { return 1_000_000 + depth }
            if (this.winner == 1) { return -1_000_000 - depth }
            return 0
        }
        if (depth == 0) { return this.evaluate() }
        let pts = this.candidates()
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
        let pts = this.candidates()
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

    func alphaBeta(depth: Int64, alpha: Int64, beta: Int64, isMax: Bool): Int64 {
        if (this.gameOver) {
            if (this.winner == 2) { return 1_000_000 + depth }
            if (this.winner == 1) { return -1_000_000 - depth }
            return 0
        }
        if (depth == 0) { return this.evaluate() }
        let pts = this.candidates()
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
                let v = this.alphaBeta(depth - 1, a, b, false)
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
                let v = this.alphaBeta(depth - 1, a, b, true)
                this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
                this.currentPlayer = prevPlayer; this.moveCount -= 1
                if (v < best) { best = v }
                if (v < b) { b = v }
                if (a >= b) { return best }
            }
            return best
        }
    }

    func chooseAlphaBeta(): Point {
        let pts = this.candidates()
        var bestRow: Int64 = pts[0].row; var bestCol: Int64 = pts[0].col; var best: Int64 = -2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 2
            let prevOver = this.gameOver; let prevWinner = this.winner; let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
            this.currentPlayer = 1
            let v = this.alphaBeta(4, -2_000_000, 2_000_000, false)
            this.board[p.row][p.col] = 0; this.gameOver = prevOver; this.winner = prevWinner
            this.currentPlayer = prevPlayer; this.moveCount -= 1
            if (v > best) { best = v; bestRow = p.row; bestCol = p.col }
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
        if (win >= 0) { return Point(win / BOARD_SIZE, win % BOARD_SIZE) }
        let block = this.findWinningMove(1)
        if (block >= 0) { return Point(block / BOARD_SIZE, block % BOARD_SIZE) }
        return this.chooseAlphaBeta()
    }

    func chooseAiMove(): Point {
        if (this.difficulty == "minimax")   { return this.chooseMinimax() }
        if (this.difficulty == "alphabeta") { return this.chooseAlphaBeta() }
        if (this.difficulty == "solver")    { return this.chooseSolver() }
        return this.chooseGreedy()
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
