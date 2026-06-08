package Gomoku_narabe

func musicTrackJson(
    key: String,
    route: String,
    title: String,
    artist: String,
    sourceLabel: String,
    neteaseUrl: String,
    qqMusicUrl: String
): String {
    return "{"
        + "\"key\":\"" + key + "\","
        + "\"route\":\"" + route + "\","
        + "\"title\":\"" + title + "\","
        + "\"artist\":\"" + artist + "\","
        + "\"sourceLabel\":\"" + sourceLabel + "\","
        + "\"neteaseUrl\":\"" + neteaseUrl + "\","
        + "\"qqMusicUrl\":\"" + qqMusicUrl + "\""
        + "}"
}

func musicManifestJson(): String {
    return "{"
        + "\"tracks\":["
        + musicTrackJson(
            "main",
            "/music/main.mp3",
            "群青レイン (群青Rain) (Re Ver.)",
            "IA",
            "Main",
            "https://music.163.com/#/search/m/?s=IA%20%E7%BE%A4%E9%9D%92%E3%83%AC%E3%82%A4%E3%83%B3&type=1",
            "https://y.qq.com/n/ryqq/search?w=IA%20%E7%BE%A4%E9%9D%92%E3%83%AC%E3%82%A4%E3%83%B3"
        ) + ","
        + musicTrackJson(
            "offline",
            "/music/offline.mp3",
            "Wind's Anthem",
            "Eve / suis",
            "Offline",
            "https://music.163.com/#/search/m/?s=Eve%20suis%20Wind%27s%20Anthem&type=1",
            "https://y.qq.com/n/ryqq/search?w=Eve%20suis%20Wind%27s%20Anthem"
        ) + ","
        + musicTrackJson(
            "online",
            "/music/online.mp3",
            "忘れられないの",
            "サカナクション",
            "Online",
            "https://music.163.com/#/search/m/?s=%E3%82%B5%E3%82%AB%E3%83%8A%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3%20%E5%BF%98%E3%82%8C%E3%82%89%E3%82%8C%E3%81%AA%E3%81%84%E3%81%AE&type=1",
            "https://y.qq.com/n/ryqq/search?w=%E3%82%B5%E3%82%AB%E3%83%8A%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3%20%E5%BF%98%E3%82%8C%E3%82%89%E3%82%8C%E3%81%AA%E3%81%84%E3%81%AE"
        ) + ","
        + musicTrackJson(
            "easy",
            "/music/easy.mp3",
            "芽吹くとき (Blooming With you)",
            "yonige",
            "Easy",
            "https://music.163.com/#/search/m/?s=yonige%20%E8%8A%BD%E5%90%B9%E3%81%8F%E3%81%A8%E3%81%8D&type=1",
            "https://y.qq.com/n/ryqq/search?w=yonige%20%E8%8A%BD%E5%90%B9%E3%81%8F%E3%81%A8%E3%81%8D"
        ) + ","
        + musicTrackJson(
            "medium",
            "/music/medium.mp3",
            "言伝",
            "Bialystocks",
            "Medium",
            "https://music.163.com/#/search/m/?s=Bialystocks%20%E8%A8%80%E4%BC%9D&type=1",
            "https://y.qq.com/n/ryqq/search?w=Bialystocks%20%E8%A8%80%E4%BC%9D"
        ) + ","
        + musicTrackJson(
            "hard",
            "/music/hard.mp3",
            "AIZO",
            "King Gnu",
            "Hard",
            "https://music.163.com/#/search/m/?s=King%20Gnu%20AIZO&type=1",
            "https://y.qq.com/n/ryqq/search?w=King%20Gnu%20AIZO"
        ) + ","
        + musicTrackJson(
            "expert",
            "/music/expert.mp3",
            "名前のない怪物",
            "EGOIST",
            "Expert",
            "https://music.163.com/#/search/m/?s=EGOIST%20%E5%90%8D%E5%89%8D%E3%81%AE%E3%81%AA%E3%81%84%E6%80%AA%E7%89%A9&type=1",
            "https://y.qq.com/n/ryqq/search?w=EGOIST%20%E5%90%8D%E5%89%8D%E3%81%AE%E3%81%AA%E3%81%84%E6%80%AA%E7%89%A9"
        ) + ","
        + musicTrackJson(
            "joseki",
            "/music/joseki.mp3",
            "DYE Reflection+",
            "ELECTROCUTICA",
            "Joseki",
            "https://music.163.com/#/search/m/?s=ELECTROCUTICA%20DYE%20Reflection%2B&type=1",
            "https://y.qq.com/n/ryqq/search?w=ELECTROCUTICA%20DYE%20Reflection%2B"
        ) + ","
        + musicTrackJson(
            "sp",
            "/music/sp.mp3",
            "Old Stories",
            "Kevin Penkin",
            "SP",
            "https://music.163.com/#/search/m/?s=Kevin%20Penkin%20Old%20Stories&type=1",
            "https://y.qq.com/n/ryqq/search?w=Kevin%20Penkin%20Old%20Stories"
        )
        + "]"
        + "}"
}

func musicFileResponse(path: String): Option<Array<Byte>> {
    if (path == "/music/main.mp3" || path == "/music/main.ogg") {
        return Some(serveFile("music/web/main.mp3", "audio/mpeg"))
    }
    if (path == "/music/offline.mp3" || path == "/music/offline.flac") {
        return Some(serveFile("music/web/offline.mp3", "audio/mpeg"))
    }
    if (path == "/music/online.mp3" || path == "/music/online.flac") {
        return Some(serveFile("music/web/online.mp3", "audio/mpeg"))
    }
    if (path == "/music/easy.mp3" || path == "/music/easy.flac") {
        return Some(serveFile("music/web/easy.mp3", "audio/mpeg"))
    }
    if (path == "/music/medium.mp3" || path == "/music/medium.flac") {
        return Some(serveFile("music/web/medium.mp3", "audio/mpeg"))
    }
    if (path == "/music/hard.mp3") {
        return Some(serveFile("music/web/hard.mp3", "audio/mpeg"))
    }
    if (path == "/music/expert.mp3" || path == "/music/expert.flac") {
        return Some(serveFile("music/web/expert.mp3", "audio/mpeg"))
    }
    if (path == "/music/joseki.mp3" || path == "/music/joseki.flac") {
        return Some(serveFile("music/web/joseki.mp3", "audio/mpeg"))
    }
    if (path == "/music/sp.mp3" || path == "/music/sp.flac") {
        return Some(serveFile("music/web/sp.mp3", "audio/mpeg"))
    }
    return None
}
