package Gomoku_narabe

import std.net.*
import std.convert.*
import std.fs.*

func httpResponseBytes(status: String, contentType: String, body: Array<Byte>): Array<Byte> {
    let header = "HTTP/1.1 ${status}\r\n"
        + "Content-Type: ${contentType}\r\n"
        + "Cache-Control: no-store\r\n"
        + "Content-Length: ${body.size}\r\n"
        + "Connection: close\r\n"
        + "\r\n"
    let hb = header.toArray()
    var result = Array<Byte>(hb.size + body.size, repeat: 0)
    var i: Int64 = 0
    while (i < hb.size)   { result[i] = hb[i]; i += 1 }
    while (i < hb.size + body.size) { result[i] = body[i - hb.size]; i += 1 }
    return result
}

func httpResponse(status: String, contentType: String, body: String): Array<Byte> {
    return httpResponseBytes(status, contentType + "; charset=utf-8", body.toArray())
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

func serveFile(filePath: String, contentType: String): Array<Byte> {
    try {
        let bytes = File.readFrom(filePath)
        return httpResponseBytes("200 OK", contentType, bytes)
    } catch (_: Exception) {
        return textResponse("404 Not Found", "file not found")
    }
}

func readRequest(client: TcpSocket): String {
    let buf = Array<Byte>(8192, repeat: 0)
    let count = client.read(buf)
    if (count <= 0) { return "" }
    return String.fromUtf8(buf)
}

func queryValue(query: String, key: String): String {
    if (query == "") { return "" }
    let parts = query.split("&")
    for (part in parts) {
        let kv = part.split("=")
        if (kv.size >= 2 && kv[0] == key) { return kv[1] }
    }
    return ""
}

func parseIntOrMinusOne(text: String): Int64 {
    match (Int64.tryParse(text)) {
        case Some(v) => return v
        case None => return -1
    }
}

