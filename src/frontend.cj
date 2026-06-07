package Gomoku_narabe

func indexPage(): String {
    return """
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>仓颉五子棋</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'PingFang SC','Microsoft YaHei',sans-serif;background:#1a1a2e;color:#e0e0e0;min-height:100vh;display:flex;align-items:flex-start;justify-content:center;padding:24px 16px}
.wrap{width:100%;max-width:600px}
h1{font-size:1.5rem;font-weight:600;letter-spacing:.05em;margin-bottom:16px;color:#f0c87a}
.controls{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.ctrl{padding:7px 12px;border:1px solid #444;background:#2a2a3e;color:#ccc;border-radius:6px;cursor:pointer;font-size:13px;transition:background .15s,color .15s}
.ctrl:hover{background:#3a3a5e;color:#fff}
.ctrl.active{background:#f0c87a;color:#1a1a2e;border-color:#f0c87a;font-weight:600}
#status{margin-bottom:12px;padding:9px 12px;background:#2a2a3e;border-radius:6px;font-size:14px;min-height:36px;border-left:3px solid #f0c87a}
#status.loading{border-left-color:#888;color:#888}
.board-wrap{position:relative;width:fit-content}
#board{
  display:grid;
  grid-template-columns:repeat(${BOARD_SIZE},36px);
  background:#c8933a;
  padding:10px;
  border-radius:8px;
  gap:0;
  box-shadow:0 8px 24px rgba(0,0,0,.5);
  user-select:none
}
#board.locked{pointer-events:none;opacity:.7}
.cell{
  width:36px;height:36px;
  border:none;
  background:transparent;
  cursor:pointer;
  position:relative;
  display:flex;align-items:center;justify-content:center
}
.cell::before,.cell::after{content:'';position:absolute;background:#7a5c20;pointer-events:none}
.cell::before{width:100%;height:1px;top:50%;transform:translateY(-50%)}
.cell::after{width:1px;height:100%;left:50%;transform:translateX(-50%)}
.cell:first-child::before,.cell:nth-child(${BOARD_SIZE})::before{width:50%}
.cell:first-child::before{left:50%}
.stone{
  width:28px;height:28px;
  border-radius:50%;
  position:relative;z-index:1;
  box-shadow:1px 2px 4px rgba(0,0,0,.5)
}
.stone.black{background:radial-gradient(circle at 35% 35%,#666,#111)}
.stone.white{background:radial-gradient(circle at 35% 35%,#fff,#ccc)}
.stone.last{box-shadow:0 0 0 2px #f0c87a,1px 2px 4px rgba(0,0,0,.5)}
.note{margin-top:12px;color:#666;font-size:12px}
</style>
</head>
<body>
<div class="wrap">
  <h1>仓颉五子棋</h1>
  <div class="controls">
    <button class="ctrl" id="btn-pvp"       onclick="newGame('pvp','greedy')">本地双人</button>
    <button class="ctrl" id="btn-greedy"    onclick="newGame('ai','greedy')">人机·贪心</button>
    <button class="ctrl" id="btn-minimax"   onclick="newGame('ai','minimax')">人机·Minimax</button>
    <button class="ctrl" id="btn-alphabeta" onclick="newGame('ai','alphabeta')">人机·Alpha-Beta</button>
    <button class="ctrl" id="btn-solver"    onclick="newGame('ai','solver')">人机·必胜</button>
  </div>
  <div id="status">加载中...</div>
  <div class="board-wrap"><div id="board"></div></div>
  <div class="note">15×15，仓颉后端。难度：贪心 &lt; Minimax &lt; Alpha-Beta &lt; 必胜</div>
</div>

<script>
const SIZE = ${BOARD_SIZE};
let busy = false;

function stoneName(v){return v===1?'黑子':v===2?'白子':'无'}

function setLoading(on){
  busy = on;
  const b = document.getElementById('board');
  const s = document.getElementById('status');
  if(on){b.classList.add('locked');s.classList.add('loading')}
  else{b.classList.remove('locked');s.classList.remove('loading')}
}

async function getJson(url){
  const res = await fetch(url);
  return res.json();
}

async function newGame(mode, diff){
  if(busy) return;
  setLoading(true);
  try{
    const data = await getJson('/api/new?mode='+mode+'&diff='+diff);
    render(data);
    highlightBtn(mode, diff);
  }finally{setLoading(false)}
}

async function doMove(row, col){
  if(busy) return;
  setLoading(true);
  try{
    const data = await getJson('/api/move?row='+row+'&col='+col);
    render(data);
  }finally{setLoading(false)}
}

function highlightBtn(mode, diff){
  document.querySelectorAll('.ctrl').forEach(b=>b.classList.remove('active'));
  const id = mode==='pvp'?'btn-pvp':'btn-'+diff;
  const el = document.getElementById(id);
  if(el) el.classList.add('active');
}

function render(data){
  const diffName={greedy:'贪心',minimax:'Minimax',alphabeta:'Alpha-Beta',solver:'必胜'}[data.difficulty]||data.difficulty;
  const s = document.getElementById('status');
  s.classList.remove('loading');
  let text = data.mode==='ai'?('人机对战·'+diffName):'本地双人';
  if(data.gameOver){
    text += data.winner===0?' ｜ 平局':' ｜ 获胜：'+stoneName(data.winner);
  }else{
    text += ' ｜ 当前：'+stoneName(data.currentPlayer);
    if(data.mode==='ai'&&data.currentPlayer===2) text += '（AI 思考中…）';
  }
  if(data.message) text += ' ｜ '+data.message;
  s.textContent = text;

  const canClick = !data.gameOver && !(data.mode==='ai' && data.currentPlayer===2);
  const board = document.getElementById('board');
  board.innerHTML='';
  for(let r=0;r<SIZE;r++){
    for(let c=0;c<SIZE;c++){
      const cell = document.createElement('div');
      cell.className='cell';
      const v = data.board[r][c];
      if(v){
        const stone=document.createElement('div');
        stone.className='stone '+(v===1?'black':'white');
        if(r===data.lastRow&&c===data.lastCol) stone.classList.add('last');
        cell.appendChild(stone);
      }else if(canClick){
        cell.style.cursor='pointer';
        cell.onclick=()=>doMove(r,c);
      }else{
        cell.style.cursor='default';
      }
      board.appendChild(cell);
    }
  }
}

(async()=>{
  try{
    const data=await getJson('/api/state');
    render(data);
    highlightBtn(data.mode, data.difficulty);
  }catch(e){
    document.getElementById('status').textContent='请点击上方按钮开始游戏';
  }
})();
</script>
</body>
</html>
"""
}
