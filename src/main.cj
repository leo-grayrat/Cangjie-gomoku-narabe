package Gomoku_narabe

import std.net.*
import std.sync.*
import std.convert.*

let localGame = GameState()
let stateMutex = Mutex()
let MAX_LAN_ROOMS: Int64 = 24
let lanRooms = Array<LanRoom>(MAX_LAN_ROOMS, { _ => LanRoom() })
var nextLanRoomId: Int64 = 1000

class LanRoom {
    var active: Bool
    var roomId: String
    var game: GameState
    var hostReady: Bool
    var guestReady: Bool

    init() {
        this.active = false
        this.roomId = ""
        this.game = GameState()
        this.hostReady = false
        this.guestReady = false
    }
}

func hintJson(ok: Bool, message: String, row: Int64, col: Int64): String {
    return "{"
        + "\"ok\":" + boolJson(ok) + ","
        + "\"message\":\"" + message + "\","
        + "\"row\":" + "${row}" + ","
        + "\"col\":" + "${col}"
        + "}"
}

func roomStatusJson(ok: Bool, message: String, roomId: String, seat: Int64): String {
    return "{"
        + "\"ok\":" + boolJson(ok) + ","
        + "\"message\":\"" + message + "\","
        + "\"roomId\":\"" + roomId + "\","
        + "\"seat\":" + "${seat}"
        + "}"
}

func lanStateJson(room: LanRoom, ok: Bool, message: String, seat: Int64): String {
    let game = room.game
    let positionScore = game.positionScoreForBlack()
    let blackWinRate = game.blackWinRateEstimate()
    let whiteWinRate = 100 - blackWinRate
    let positionLabel = game.positionLabelForRate(blackWinRate)
    let roomReady = room.hostReady && room.guestReady
    return "{"
        + "\"ok\":" + boolJson(ok) + ","
        + "\"message\":\"" + message + "\","
        + "\"size\":" + "${BOARD_SIZE}" + ","
        + "\"mode\":\"lan\","
        + "\"difficulty\":\"lan\","
        + "\"currentPlayer\":" + "${game.currentPlayer}" + ","
        + "\"gameOver\":" + boolJson(game.gameOver) + ","
        + "\"winner\":" + "${game.winner}" + ","
        + "\"moveCount\":" + "${game.moveCount}" + ","
        + "\"lastRow\":" + "${game.lastRow}" + ","
        + "\"lastCol\":" + "${game.lastCol}" + ","
        + "\"histCount\":" + "${game.histCount}" + ","
        + "\"positionScore\":" + "${positionScore}" + ","
        + "\"blackWinRate\":" + "${blackWinRate}" + ","
        + "\"whiteWinRate\":" + "${whiteWinRate}" + ","
        + "\"positionLabel\":\"" + positionLabel + "\","
        + "\"roomId\":\"" + room.roomId + "\","
        + "\"seat\":" + "${seat}" + ","
        + "\"hostReady\":" + boolJson(room.hostReady) + ","
        + "\"guestReady\":" + boolJson(room.guestReady) + ","
        + "\"roomReady\":" + boolJson(roomReady) + ","
        + "\"board\":" + game.boardJson()
        + "}"
}

func parsePlayerOrZero(text: String): Int64 {
    match (Int64.tryParse(text)) {
        case Some(v) => return v
        case None => return 0
    }
}

func nextRoomCode(): String {
    nextLanRoomId += 1
    return "${nextLanRoomId}"
}

func findLanRoomIndex(roomId: String): Int64 {
    var i: Int64 = 0
    while (i < lanRooms.size) {
        if (lanRooms[i].active && lanRooms[i].roomId == roomId) { return i }
        i += 1
    }
    return -1
}

func allocateLanRoomIndex(): Int64 {
    var i: Int64 = 0
    while (i < lanRooms.size) {
        if (!lanRooms[i].active) { return i }
        i += 1
    }
    return -1
}

func resetLanRoomAt(index: Int64) {
    lanRooms[index].active = false
    lanRooms[index].roomId = ""
    lanRooms[index].hostReady = false
    lanRooms[index].guestReady = false
    lanRooms[index].game.reset("pvp", "easy")
}

func handleRequest(request: String): Array<Byte> {
    if (request == "") { return textResponse("400 Bad Request", "empty request") }

    let lines = request.split("\r\n")
    if (lines.size == 0) { return textResponse("400 Bad Request", "bad request") }

    let firstLine = lines[0]
    let parts = firstLine.split(" ")
    if (parts.size < 2) { return textResponse("400 Bad Request", "bad request line") }

    let method = parts[0]
    let target = parts[1]
    if (method != "GET") {
        return textResponse("405 Method Not Allowed", "only GET is supported")
    }

    let pair = target.split("?")
    let path = pair[0]
    var query = ""
    if (pair.size > 1) { query = pair[1] }

    if (path == "/") {
        return serveFile("frontend/index.html", "text/html; charset=utf-8")
    }
    if (path == "/style.css") {
        return serveFile("frontend/style.css", "text/css; charset=utf-8")
    }
    if (path == "/tokens.css") {
        return serveFile("tokens.css", "text/css; charset=utf-8")
    }
    if (path == "/app.js") {
        return serveFile("frontend/app.js", "application/javascript; charset=utf-8")
    }

    if (path == "/api/state") {
        synchronized(stateMutex) {
            return jsonResponse(localGame.stateJson(true, ""))
        }
    }

    if (path == "/api/new") {
        let mode = queryValue(query, "mode")
        let diff = queryValue(query, "diff")
        synchronized(stateMutex) {
            localGame.reset(mode, diff)
            return jsonResponse(localGame.stateJson(true, "new_game_created"))
        }
    }

    if (path == "/api/move") {
        let row = parseIntOrMinusOne(queryValue(query, "row"))
        let col = parseIntOrMinusOne(queryValue(query, "col"))
        if (row < 0 || col < 0) {
            synchronized(stateMutex) {
                return jsonResponse(localGame.stateJson(false, "bad_params"))
            }
        }
        synchronized(stateMutex) {
            let result = localGame.playerMove(row, col)
            return jsonResponse(localGame.stateJson(result.ok, result.message))
        }
    }

    if (path == "/api/undo") {
        synchronized(stateMutex) {
            let result = localGame.undo()
            return jsonResponse(localGame.stateJson(result.ok, result.message))
        }
    }

    if (path == "/api/hint") {
        synchronized(stateMutex) {
            if (localGame.gameOver) {
                return jsonResponse(hintJson(false, "game_over_hint", -1, -1))
            }
            if (localGame.mode == "ai" && localGame.currentPlayer != 1) {
                return jsonResponse(hintJson(false, "not_human_turn", -1, -1))
            }
            let point = localGame.hint()
            return jsonResponse(hintJson(true, "", point.row, point.col))
        }
    }

    if (path == "/api/lan/create") {
        synchronized(stateMutex) {
            let index = allocateLanRoomIndex()
            if (index < 0) {
                return jsonResponse(roomStatusJson(false, "room_limit_reached", "", 0))
            }

            let roomId = nextRoomCode()
            lanRooms[index].active = true
            lanRooms[index].roomId = roomId
            lanRooms[index].hostReady = true
            lanRooms[index].guestReady = false
            lanRooms[index].game.reset("lan", "lan")
            return jsonResponse(lanStateJson(lanRooms[index], true, "room_created", 1))
        }
    }

    if (path == "/api/lan/join") {
        let roomId = queryValue(query, "room")
        synchronized(stateMutex) {
            let index = findLanRoomIndex(roomId)
            if (index < 0) {
                return jsonResponse(roomStatusJson(false, "room_not_found", roomId, 0))
            }
            if (lanRooms[index].guestReady) {
                return jsonResponse(roomStatusJson(false, "room_full", roomId, 0))
            }
            lanRooms[index].guestReady = true
            return jsonResponse(lanStateJson(lanRooms[index], true, "room_joined", 2))
        }
    }

    if (path == "/api/lan/state") {
        let roomId = queryValue(query, "room")
        let seat = parsePlayerOrZero(queryValue(query, "player"))
        synchronized(stateMutex) {
            let index = findLanRoomIndex(roomId)
            if (index < 0) {
                return jsonResponse(roomStatusJson(false, "room_not_found", roomId, seat))
            }
            return jsonResponse(lanStateJson(lanRooms[index], true, "", seat))
        }
    }

    if (path == "/api/lan/move") {
        let roomId = queryValue(query, "room")
        let seat = parsePlayerOrZero(queryValue(query, "player"))
        let row = parseIntOrMinusOne(queryValue(query, "row"))
        let col = parseIntOrMinusOne(queryValue(query, "col"))
        synchronized(stateMutex) {
            let index = findLanRoomIndex(roomId)
            if (index < 0) {
                return jsonResponse(roomStatusJson(false, "room_not_found", roomId, seat))
            }
            if (!(seat == 1 || seat == 2)) {
                return jsonResponse(lanStateJson(lanRooms[index], false, "bad_player", seat))
            }
            if (!(lanRooms[index].hostReady && lanRooms[index].guestReady)) {
                return jsonResponse(lanStateJson(lanRooms[index], false, "wait_opponent", seat))
            }
            if (row < 0 || col < 0) {
                return jsonResponse(lanStateJson(lanRooms[index], false, "bad_params", seat))
            }

            let result = lanRooms[index].game.playerMoveAs(seat, row, col)
            return jsonResponse(lanStateJson(lanRooms[index], result.ok, result.message, seat))
        }
    }

    if (path == "/api/lan/reset") {
        let roomId = queryValue(query, "room")
        let seat = parsePlayerOrZero(queryValue(query, "player"))
        synchronized(stateMutex) {
            let index = findLanRoomIndex(roomId)
            if (index < 0) {
                return jsonResponse(roomStatusJson(false, "room_not_found", roomId, seat))
            }
            if (seat != 1) {
                return jsonResponse(lanStateJson(lanRooms[index], false, "host_only_reset", seat))
            }
            lanRooms[index].game.reset("lan", "lan")
            return jsonResponse(lanStateJson(lanRooms[index], true, "room_reset", seat))
        }
    }

    if (path == "/api/lan/leave") {
        let roomId = queryValue(query, "room")
        let seat = parsePlayerOrZero(queryValue(query, "player"))
        synchronized(stateMutex) {
            let index = findLanRoomIndex(roomId)
            if (index < 0) {
                return jsonResponse(roomStatusJson(false, "room_not_found", roomId, seat))
            }

            if (seat == 1) {
                resetLanRoomAt(index)
                return jsonResponse(roomStatusJson(true, "room_closed", roomId, seat))
            }

            if (seat == 2) {
                lanRooms[index].guestReady = false
                return jsonResponse(lanStateJson(lanRooms[index], true, "guest_left", seat))
            }

            return jsonResponse(roomStatusJson(false, "bad_player", roomId, seat))
        }
    }

    if (path == "/favicon.ico") { return textResponse("404 Not Found", "") }
    return textResponse("404 Not Found", "not found")
}

func handleClient(client: TcpSocket) {
    let request = readRequest(client)
    let response = handleRequest(request)
    client.write(response)
}

main(): Int64 {
    localGame.reset("pvp", "easy")
    println("Gomoku server started at http://127.0.0.1:${SERVER_PORT}/")

    try (server = TcpServerSocket(bindAt: SERVER_PORT)) {
        server.bind()
        while (true) {
            let client = server.accept()
            spawn {
                try (c = client) { handleClient(c) }
            }
        }
    }

    return 0
}
