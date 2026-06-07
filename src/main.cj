package Gomoku_narabe

import std.net.*
import std.sync.*

let game = GameState()
let gameMutex = Mutex()

func hintJson(ok: Bool, message: String, row: Int64, col: Int64): String {
    return "{"
        + "\"ok\":" + boolJson(ok) + ","
        + "\"message\":\"" + message + "\","
        + "\"row\":" + "${row}" + ","
        + "\"col\":" + "${col}"
        + "}"
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

    if (path == "/api/undo") {
        synchronized(gameMutex) {
            let result = game.undo()
            return jsonResponse(game.stateJson(result.ok, result.message))
        }
    }

    if (path == "/api/hint") {
        synchronized(gameMutex) {
            if (game.gameOver) {
                return jsonResponse(hintJson(false, "对局已结束，无法提供帮助", -1, -1))
            }
            if (game.mode == "ai" && game.currentPlayer != 1) {
                return jsonResponse(hintJson(false, "当前不是人类落子回合", -1, -1))
            }
            let point = game.hint()
            return jsonResponse(hintJson(true, "", point.row, point.col))
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
    game.reset("pvp", "easy")
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
