# 前端重写计划

## Context

当前前端是塞在 `src/frontend.cj` 里的一个嵌入式 HTML 字符串，难以维护、无法热更新、设计受限。用户要求：推倒重来，用独立前端文件，更丰富的动效，减少图标和 AI 感。

Hallmark skill 已安装但运行时无响应，跳过，直接手写设计。

---

## 架构方案

不引入构建工具（无 Vite/React），保持课程项目的简洁性：
- 新建 `frontend/index.html` + `frontend/style.css` + `frontend/app.js`
- 仓颉后端新增静态文件服务：`GET /` → 读 `frontend/index.html`，`GET /style.css` → 读 `frontend/style.css`，`GET /app.js` → 读 `frontend/app.js`
- 删除 `src/frontend.cj`，删除 `indexPage()` 函数调用

## 页面结构（两个视图，单页切换）

### 视图 1：首页（`#view-home`）
- 全屏深色背景，居中显示标题「仓颉五子棋」+ 副标题（简短一行）
- 五个难度按钮竖排或横排，点击任一按钮 → 进入游戏视图并开始该难度的对局
- 底部有算法简介区域（四个难度各一小段，不用卡片，就是分组文字）
- 进入游戏时有页面滑入过渡动效（CSS translate）

### 视图 2：游戏视图（`#view-game`）
- 顶部一行：返回首页按钮（文字「← 返回」）+ 当前难度名 + 状态文字
- 主体：Canvas 棋盘居中
- 棋盘下方：当前难度算法的一句话简介（从首页内容复用）

## 设计方向（Anti-AI-slop）

**结构**：单页两视图，无路由库，JS 切换 display。不用卡片堆叠，不用大圆角。

**色调**：深背景（#0f0f14），棋盘木色（#c19a49），文字 #e8e0d0，强调色 #d4a843。

**动效**（CSS only）：
- 视图切换：`transform: translateY` 滑入/出
- 落子：canvas 绘制时附带 scale 弹入（JS requestAnimationFrame，~200ms）
- 最后落子：canvas 上绘制脉冲光圈（requestAnimationFrame 循环）
- AI 思考：棋盘半透明 + 纯 CSS spinner 覆盖层
- 按钮 hover：`::after` 下划线从左向右展开

**棋盘**：Canvas，绘制网格线、天元/星位点（实心小圆）、黑白棋子（径向渐变圆）。

---

## 文件改动

### 新建文件

- `frontend/index.html` — 骨架：canvas + 控制栏 + 状态行
- `frontend/style.css` — 所有样式和 keyframes
- `frontend/app.js` — canvas 渲染、API 调用、动效逻辑

### 修改 src/server.cj

新增静态文件读取函数 `serveFile(path: String)`，用 `std.fs.*` + `File.readFrom(path)` 读文件并返回正确 content-type。API 已验证可用（`import std.fs.*`，`File.readFrom(path)` 返回 `Array<Byte>`）。

### 修改 src/main.cj

路由新增：
- `GET /` → serveFile("frontend/index.html")
- `GET /style.css` → serveFile("frontend/style.css")  
- `GET /app.js` → serveFile("frontend/app.js")

删除对 `indexPage()` 的调用。

### 删除 src/frontend.cj

不再需要。

---

## 验证

```
cjpm build
target/release/bin/main.exe
# Playwright: 打开 http://127.0.0.1:8080/，确认棋盘渲染正常、落子动效、AI 思考 spinner
```
