package Gomoku_narabe

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
    return Array<Array<Int64>>(BOARD_SIZE, { _ =>
        Array<Int64>(BOARD_SIZE, repeat: 0)
    })
}

func boolJson(v: Bool): String {
    if (v) { return "true" }
    return "false"
}

func otherPlayer(stone: Int64): Int64 {
    if (stone == 1) { return 2 }
    return 1
}

func abs64(x: Int64): Int64 {
    if (x < 0) { return -x }
    return x
}
