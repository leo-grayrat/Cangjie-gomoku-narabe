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
    var histBoards: Array<Array<Array<Int64>>> = Array<Array<Array<Int64>>>(226, { _ => emptyBoard() })
    var histPlayers: Array<Int64> = Array<Int64>(226, repeat: 0)
    var histCount: Int64 = 0

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
        this.histCount = 0
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
        if (length >= 5) { return 100000 }
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
        if (this.openEnd(row, col, dr, dc, right)) { openEnds += 1 }
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

    func copyBoard(): Array<Array<Int64>> {
        return Array<Array<Int64>>(BOARD_SIZE, { r =>
            Array<Int64>(BOARD_SIZE, { c => this.board[r][c] })
        })
    }

    func swapBoardStones() {
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] == 1) {
                    this.board[row][col] = 2
                } else if (this.board[row][col] == 2) {
                    this.board[row][col] = 1
                }
            }
        }
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

        var cRows = Array<Int64>(BOARD_SIZE * BOARD_SIZE, repeat: 0)
        var cCols = Array<Int64>(BOARD_SIZE * BOARD_SIZE, repeat: 0)
        var cScores = Array<Int64>(BOARD_SIZE * BOARD_SIZE, repeat: 0)
        var count: Int64 = 0

        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) { continue }
                if (!this.hasNearbyStone(row, col, 2)) { continue }

                let attack = this.pointScore(row, col, 2)
                let defend = this.pointScore(row, col, 1)
                var score: Int64 = attack * 2 + defend
                if (attack >= 100000) {
                    score = 2_000_000
                } else if (defend >= 100000) {
                    score = 1_500_000
                }

                cRows[count] = row
                cCols[count] = col
                cScores[count] = score
                count += 1
            }
        }

        var i: Int64 = 1
        while (i < count) {
            let keyRow = cRows[i]
            let keyCol = cCols[i]
            let keyScore = cScores[i]
            var j = i - 1
            while (j >= 0 && cScores[j] < keyScore) {
                cRows[j + 1] = cRows[j]
                cCols[j + 1] = cCols[j]
                cScores[j + 1] = cScores[j]
                j -= 1
            }
            cRows[j + 1] = keyRow
            cCols[j + 1] = keyCol
            cScores[j + 1] = keyScore
            i += 1
        }

        let n = if (count < maxCands) { count } else { maxCands }
        var result = Array<Point>(n, { _ => Point(0, 0) })
        var k: Int64 = 0
        while (k < n) {
            result[k] = Point(cRows[k], cCols[k])
            k += 1
        }
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

    // --- Easy: forced moves + greedy + some randomness ---

    func chooseEasy(): Point {
        if (this.board[CENTER][CENTER] == 0) { return Point(CENTER, CENTER) }

        let win = this.findWinningMove(2)
        if (win >= 0) { return Point(win / BOARD_SIZE, win % BOARD_SIZE) }

        let block = this.findWinningMove(1)
        if (block >= 0) { return Point(block / BOARD_SIZE, block % BOARD_SIZE) }

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

        var bestRow: Int64 = -1
        var bestCol: Int64 = -1
        var bestScore: Int64 = -1
        var bestBias: Int64 = 1_000_000
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                if (this.board[row][col] != 0) { continue }
                if (!this.hasNearbyStone(row, col, 2)) { continue }
                let attack = this.pointScore(row, col, 2)
                let defend = this.pointScore(row, col, 1)
                let score = attack * 2 + defend
                let bias = this.centerBias(row, col)
                if (score > bestScore || (score == bestScore && bias < bestBias)) {
                    bestScore = score
                    bestBias = bias
                    bestRow = row
                    bestCol = col
                }
            }
        }
        if (bestRow >= 0) { return Point(bestRow, bestCol) }
        return Point(0, 0)
    }

    // --- Medium: minimax (no pruning) ---

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
                let prevOver = this.gameOver
                let prevWinner = this.winner
                let prevPlayer = this.currentPlayer
                this.moveCount += 1
                if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
                this.currentPlayer = 1
                let value = this.minimax(depth - 1, false)
                this.board[p.row][p.col] = 0
                this.gameOver = prevOver
                this.winner = prevWinner
                this.currentPlayer = prevPlayer
                this.moveCount -= 1
                if (value > best) { best = value }
            }
            return best
        }

        var best: Int64 = 2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 1
            let prevOver = this.gameOver
            let prevWinner = this.winner
            let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 1)) { this.gameOver = true; this.winner = 1 }
            this.currentPlayer = 2
            let value = this.minimax(depth - 1, true)
            this.board[p.row][p.col] = 0
            this.gameOver = prevOver
            this.winner = prevWinner
            this.currentPlayer = prevPlayer
            this.moveCount -= 1
            if (value < best) { best = value }
        }
        return best
    }

    func chooseMinimax(): Point {
        let pts = this.candidatesN(10)
        var bestRow: Int64 = pts[0].row
        var bestCol: Int64 = pts[0].col
        var best: Int64 = -2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 2
            let prevOver = this.gameOver
            let prevWinner = this.winner
            let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
            this.currentPlayer = 1
            let value = this.minimax(3, false)
            this.board[p.row][p.col] = 0
            this.gameOver = prevOver
            this.winner = prevWinner
            this.currentPlayer = prevPlayer
            this.moveCount -= 1
            if (value > best) {
                best = value
                bestRow = p.row
                bestCol = p.col
            }
        }
        return Point(bestRow, bestCol)
    }

    // --- Hard / Expert: alpha-beta ---

    func alphaBeta(depth: Int64, alpha: Int64, beta: Int64, isMax: Bool, maxCands: Int64): Int64 {
        if (this.gameOver) {
            if (this.winner == 2) { return 1_000_000 + depth }
            if (this.winner == 1) { return -1_000_000 - depth }
            return 0
        }
        if (depth == 0) { return this.evaluate() }

        let pts = this.candidatesN(maxCands)
        if (pts.size == 0) { return this.evaluate() }

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
                if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
                this.currentPlayer = 1
                let value = this.alphaBeta(depth - 1, a, b, false, maxCands)
                this.board[p.row][p.col] = 0
                this.gameOver = prevOver
                this.winner = prevWinner
                this.currentPlayer = prevPlayer
                this.moveCount -= 1
                if (value > best) { best = value }
                if (value > a) { a = value }
                if (a >= b) { return best }
            }
            return best
        }

        var best: Int64 = 2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 1
            let prevOver = this.gameOver
            let prevWinner = this.winner
            let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 1)) { this.gameOver = true; this.winner = 1 }
            this.currentPlayer = 2
            let value = this.alphaBeta(depth - 1, a, b, true, maxCands)
            this.board[p.row][p.col] = 0
            this.gameOver = prevOver
            this.winner = prevWinner
            this.currentPlayer = prevPlayer
            this.moveCount -= 1
            if (value < best) { best = value }
            if (value < b) { b = value }
            if (a >= b) { return best }
        }
        return best
    }

    func chooseAlphaBetaN(depth: Int64, maxCands: Int64): Point {
        let pts = this.candidatesN(maxCands)
        var bestRow: Int64 = pts[0].row
        var bestCol: Int64 = pts[0].col
        var best: Int64 = -2_000_000
        for (p in pts) {
            this.board[p.row][p.col] = 2
            let prevOver = this.gameOver
            let prevWinner = this.winner
            let prevPlayer = this.currentPlayer
            this.moveCount += 1
            if (this.hasFive(p.row, p.col, 2)) { this.gameOver = true; this.winner = 2 }
            this.currentPlayer = 1
            let value = this.alphaBeta(depth, -2_000_000, 2_000_000, false, maxCands)
            this.board[p.row][p.col] = 0
            this.gameOver = prevOver
            this.winner = prevWinner
            this.currentPlayer = prevPlayer
            this.moveCount -= 1
            if (value > best) {
                best = value
                bestRow = p.row
                bestCol = p.col
            }
        }
        return Point(bestRow, bestCol)
    }

    // --- Expert: forced win / forced defense + alpha-beta ---

    func chooseExpert(): Point {
        let win = this.findWinningMove(2)
        if (win >= 0) { return Point(win / BOARD_SIZE, win % BOARD_SIZE) }
        let block = this.findWinningMove(1)
        if (block >= 0) { return Point(block / BOARD_SIZE, block % BOARD_SIZE) }
        return this.chooseAlphaBetaN(4, 20)
    }

    // --- Joseki: center opening book, then fall back to hard ---

    func josekiBlackAt(dr: Int64, dc: Int64): Bool {
        let row = CENTER + dr
        let col = CENTER + dc
        return this.isInside(row, col) && this.board[row][col] == 1
    }

    func josekiEmptyAt(dr: Int64, dc: Int64): Bool {
        let row = CENTER + dr
        let col = CENTER + dc
        return this.isInside(row, col) && this.board[row][col] == 0
    }

    func lookupJoseki(): Int64 {
        let mc = this.moveCount
        if (!this.josekiBlackAt(0, 0)) { return -999 }

        if (mc == 1) {
            if (this.josekiEmptyAt(0, 2)) { return 2 }
            return -999
        }

        if (mc == 3) {
            if (this.josekiBlackAt(0, -1) && this.board[CENTER][CENTER + 2] == 2 && this.josekiEmptyAt(0, -2)) {
                return -200
            }
            if (this.josekiBlackAt(1, 0) && this.board[CENTER][CENTER + 2] == 2 && this.josekiEmptyAt(2, 0)) {
                return 200
            }
            if (this.josekiBlackAt(1, 1) && this.board[CENTER][CENTER + 2] == 2 && this.josekiEmptyAt(-1, -1)) {
                return -101
            }
        }

        if (mc == 5) {
            if (this.josekiBlackAt(0, -1) && this.josekiBlackAt(0, -2)
                && this.board[CENTER][CENTER + 2] == 2
                && this.board[CENTER][CENTER + 3] == 2
                && this.josekiEmptyAt(0, 4)) {
                return 4
            }
            if (this.josekiBlackAt(1, 1) && this.josekiBlackAt(2, 2)
                && this.board[CENTER - 1][CENTER - 1] == 2
                && this.board[CENTER - 2][CENTER - 2] == 2
                && this.josekiEmptyAt(3, 3)) {
                return 303
            }
        }

        return -999
    }

    func chooseJoseki(): Point {
        let code = this.lookupJoseki()
        if (code != -999) {
            var dr: Int64 = code / 100
            var dc: Int64 = code % 100
            if (code < 0) {
                dr = -((-code) / 100)
                dc = -((-code) % 100)
                if (code == -101) { dr = -1; dc = -1 }
                else if (code == -200) { dr = -2; dc = 0 }
            }
            if (code == 2) { dr = 0; dc = 2 }
            if (code == 4) { dr = 0; dc = 4 }
            if (code == 200) { dr = 2; dc = 0 }
            if (code == 303) { dr = 3; dc = 3 }
            let row = CENTER + dr
            let col = CENTER + dc
            if (this.isInside(row, col) && this.board[row][col] == 0) {
                return Point(row, col)
            }
        }
        return this.chooseAlphaBetaN(4, 15)
    }

    func chooseAiMove(): Point {
        if (this.difficulty == "medium") { return this.chooseMinimax() }
        if (this.difficulty == "hard") { return this.chooseAlphaBetaN(4, 15) }
        if (this.difficulty == "expert") { return this.chooseExpert() }
        if (this.difficulty == "joseki") { return this.chooseJoseki() }
        return this.chooseEasy()
    }

    // --- Player API ---

    func undo(): ApiResult {
        if (this.histCount == 0) { return ApiResult(false, "没有可悔棋的步骤") }
        if (this.gameOver) { return ApiResult(false, "对局已结束，请通过复盘查看") }

        let stepsToUndo = if (this.mode == "ai" && this.histCount >= 2) { 2 } else { 1 }
        let target = this.histCount - stepsToUndo
        let savedBoard = this.histBoards[target]
        for (row in 0..BOARD_SIZE) {
            for (col in 0..BOARD_SIZE) {
                this.board[row][col] = savedBoard[row][col]
            }
        }

        this.currentPlayer = this.histPlayers[target]
        this.histCount = target
        this.moveCount = target
        this.lastRow = -1
        this.lastCol = -1
        this.gameOver = false
        this.winner = 0
        return ApiResult(true, "悔棋成功")
    }

    func hint(): Point {
        let win = this.findWinningMove(this.currentPlayer)
        if (win >= 0) { return Point(win / BOARD_SIZE, win % BOARD_SIZE) }

        let block = this.findWinningMove(otherPlayer(this.currentPlayer))
        if (block >= 0) { return Point(block / BOARD_SIZE, block % BOARD_SIZE) }

        if (this.currentPlayer == 2) { return this.chooseAlphaBetaN(4, 15) }

        let prevPlayer = this.currentPlayer
        this.swapBoardStones()
        this.currentPlayer = 2
        let point = this.chooseAlphaBetaN(4, 15)
        this.swapBoardStones()
        this.currentPlayer = prevPlayer
        return point
    }

    func playerMove(row: Int64, col: Int64): ApiResult {
        if (this.gameOver) { return ApiResult(false, "游戏已经结束，请重新开始") }
        if (!this.isInside(row, col)) { return ApiResult(false, "坐标越界") }
        if (this.board[row][col] != 0) { return ApiResult(false, "该位置已有棋子") }
        if (this.mode == "ai" && this.currentPlayer != 1) { return ApiResult(false, "请等待 AI 落子") }

        this.histBoards[this.histCount] = this.copyBoard()
        this.histPlayers[this.histCount] = this.currentPlayer
        this.histCount += 1

        this.placeCurrentStone(row, col)
        if (this.mode == "ai" && !this.gameOver && this.currentPlayer == 2) {
            this.histBoards[this.histCount] = this.copyBoard()
            this.histPlayers[this.histCount] = 2
            this.histCount += 1
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
            + "\"histCount\":" + "${this.histCount}" + ","
            + "\"board\":" + this.boardJson()
            + "}"
    }
}
