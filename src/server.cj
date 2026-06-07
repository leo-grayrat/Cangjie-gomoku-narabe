package Gomoku_narabe

import std.net.*
import std.convert.*

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
    if (count <= 0) { return "" }
    return String.fromUtf8(buf)
}

func queryValue(query: String, key: String): String {
    if (query == "") { return "" }
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
