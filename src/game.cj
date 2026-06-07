package Gomoku_narabe

import std.random.*
import std.convert.*

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

    func positionScoreForBlack(): Int64 {
        if (this.gameOver) {
            if (this.winner == 1) { return 1_000_000 }
            if (this.winner == 2) { return -1_000_000 }
            return 0
        }
        return -this.evaluate()
    }

    func clampRate(rate: Int64): Int64 {
        if (rate < 5) { return 5 }
        if (rate > 95) { return 95 }
        return rate
    }

    func blackWinRateEstimate(): Int64 {
        if (this.gameOver) {
            if (this.winner == 1) { return 100 }
            if (this.winner == 2) { return 0 }
            return 50
        }

        let blackAdvantage = this.positionScoreForBlack()
        let blackRate = 50 + 45 * blackAdvantage / (abs64(blackAdvantage) + 4000)
        return this.clampRate(blackRate)
    }

    func positionLabelForRate(blackRate: Int64): String {
        if (abs64(blackRate - 50) <= 5) { return "even" }
        if (blackRate > 55) { return "black" }
        return "white"
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

    // --- Joseki: opening book with symmetry matching, then fall back to hard ---

    func josekiBookLines(): Array<String> {
        // Based on common Renju/Gomoku opening families. One line encodes:
        // black 1; white 2; black 3; white 4; ...
        var lines = Array<String>(30, repeat: "")

        // Direct openings: white answers orthogonally to the center.
        lines[0] = "0,0;-1,0;-2,0;-1,1;-2,1;-1,2"
        lines[1] = "0,0;-1,0;-2,1;-1,-1;-2,-1;-1,-2"
        lines[2] = "0,0;-1,0;-2,2;-1,1"
        lines[3] = "0,0;-1,0;-1,1;0,1"
        lines[4] = "0,0;-1,0;-1,2;-2,1"
        lines[5] = "0,0;-1,0;0,1;-2,1"
        lines[6] = "0,0;-1,0;0,2;-1,1"
        lines[7] = "0,0;-1,0;1,0;0,1"
        lines[8] = "0,0;-1,0;1,1;-1,-1"
        lines[9] = "0,0;-1,0;1,2;0,1"
        lines[10] = "0,0;-1,0;2,0;1,1"
        lines[11] = "0,0;-1,0;2,1;1,0"
        lines[12] = "0,0;-1,0;2,2;1,1"

        // Indirect openings: white answers diagonally to the center.
        lines[13] = "0,0;-1,1;-2,1;-1,0;-2,0;-1,-1"
        lines[14] = "0,0;-1,1;-2,2;0,1"
        lines[15] = "0,0;-1,1;-1,2;0,1"
        lines[16] = "0,0;-1,1;0,2;-1,0"
        lines[17] = "0,0;-1,1;1,2;0,1"
        lines[18] = "0,0;-1,1;0,1;-2,1"
        lines[19] = "0,0;-1,1;1,1;0,2"
        lines[20] = "0,0;-1,1;1,0;-1,-1"
        lines[21] = "0,0;-1,1;2,0;1,1"
        lines[22] = "0,0;-1,1;1,-1;0,1"
        lines[23] = "0,0;-1,1;2,-1;1,0"
        lines[24] = "0,0;-1,1;2,-2;1,-1"
        lines[25] = "0,0;-1,1;1,-2;0,-1"

        // Extra continuations for a few common center-opening lines.
        lines[26] = "0,0;-1,0;-2,0;-1,1;-2,1;-1,2;0,2;-2,2"
        lines[27] = "0,0;-1,0;1,1;-1,-1;0,-1;-2,-1"
        lines[28] = "0,0;-1,1;-2,1;-1,0;-2,0;-1,-1;0,-1;-2,-2"
        lines[29] = "0,0;-1,1;1,0;-1,-1;0,-1;-2,0"
        return lines
    }

    func parseJosekiLine(line: String): Array<Point> {
        let tokens = line.split(";")
        var points = Array<Point>(tokens.size, { _ => Point(0, 0) })
        var i: Int64 = 0
        while (i < tokens.size) {
            let pair = tokens[i].split(",")
            let row = match (Int64.tryParse(pair[0])) {
                case Some(v) => v
                case None => 0
            }
            let col = match (Int64.tryParse(pair[1])) {
                case Some(v) => v
                case None => 0
            }
            points[i] = Point(row, col)
            i += 1
        }
        return points
    }

    func transformJosekiPoint(p: Point, transform: Int64): Point {
        if (transform == 0) { return Point(p.row, p.col) }
        if (transform == 1) { return Point(p.col, -p.row) }
        if (transform == 2) { return Point(-p.row, -p.col) }
        if (transform == 3) { return Point(-p.col, p.row) }
        if (transform == 4) { return Point(p.row, -p.col) }
        if (transform == 5) { return Point(-p.col, -p.row) }
        if (transform == 6) { return Point(-p.row, p.col) }
        return Point(p.col, p.row)
    }

    func josekiPrefixMatches(points: Array<Point>, prefixLen: Int64, transform: Int64): Bool {
        if (points.size < prefixLen) { return false }
        var i: Int64 = 0
        while (i < prefixLen) {
            let rel = this.transformJosekiPoint(points[i], transform)
            let row = CENTER + rel.row
            let col = CENTER + rel.col
            if (!this.isInside(row, col)) { return false }
            let expectedStone = if (i % 2 == 0) { 1 } else { 2 }
            if (this.board[row][col] != expectedStone) { return false }
            i += 1
        }
        return true
    }

    func josekiBookMove(): Point {
        let lines = this.josekiBookLines()
        var rows = Array<Int64>(64, repeat: 0)
        var cols = Array<Int64>(64, repeat: 0)
        var count: Int64 = 0

        for (line in lines) {
            let points = this.parseJosekiLine(line)
            if (points.size <= this.moveCount) { continue }

            for (transform in 0..8) {
                if (!this.josekiPrefixMatches(points, this.moveCount, transform)) { continue }

                let rel = this.transformJosekiPoint(points[this.moveCount], transform)
                let row = CENTER + rel.row
                let col = CENTER + rel.col
                if (!this.isInside(row, col) || this.board[row][col] != 0) { continue }

                var exists = false
                var i: Int64 = 0
                while (i < count) {
                    if (rows[i] == row && cols[i] == col) {
                        exists = true
                        break
                    }
                    i += 1
                }
                if (!exists) {
                    rows[count] = row
                    cols[count] = col
                    count += 1
                }
            }
        }

        if (count == 0) { return Point(-1, -1) }
        let pick = this.rng.nextInt64(count)
        return Point(rows[pick], cols[pick])
    }

    func chooseJoseki(): Point {
        let bookMove = this.josekiBookMove()
        if (bookMove.row >= 0) { return bookMove }
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
        if (this.histCount == 0) { return ApiResult(false, "no_undo") }
        if (this.gameOver) { return ApiResult(false, "game_over_review") }

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
        return ApiResult(true, "undo_ok")
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
        if (this.gameOver) { return ApiResult(false, "game_over") }
        if (!this.isInside(row, col)) { return ApiResult(false, "out_of_range") }
        if (this.board[row][col] != 0) { return ApiResult(false, "occupied") }
        if (this.mode == "ai" && this.currentPlayer != 1) { return ApiResult(false, "wait_ai") }

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
            return ApiResult(true, "move_and_ai")
        }

        return ApiResult(true, "move_ok")
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
        let positionScore = this.positionScoreForBlack()
        let blackWinRate = this.blackWinRateEstimate()
        let whiteWinRate = 100 - blackWinRate
        let positionLabel = this.positionLabelForRate(blackWinRate)
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
            + "\"positionScore\":" + "${positionScore}" + ","
            + "\"blackWinRate\":" + "${blackWinRate}" + ","
            + "\"whiteWinRate\":" + "${whiteWinRate}" + ","
            + "\"positionLabel\":\"" + positionLabel + "\","
            + "\"board\":" + this.boardJson()
            + "}"
    }
}
