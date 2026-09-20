# 抓取真实界面：完整配方

目标：把**真实运行界面**的 DOM 和 CSS 抓下来，装进一个离线 HTML。
这样外观与线上一致，研发不会看到假界面。

---

## 1. 准备临时工作树并构建

```bash
REPO=/home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react
SCRATCH=/home/steven/work/RV1126B/仓库/完整的/rockchip/.ui-prototype-<主题>

git -C "$REPO" worktree add --detach "$SCRATCH" HEAD
ln -s "$REPO/node_modules" "$SCRATCH/node_modules"

# 在 $SCRATCH 里实现设计改动 ...

cd "$SCRATCH" && CI=false npx --no-install react-scripts build
```

构建产物：

```
$SCRATCH/build/static/css/main.<hash>.css    ← 全站样式（371KB 左右），直接内联
$SCRATCH/build/static/js/main.<hash>.js      ← 不需要（演示是静态 DOM + 自写 JS）
$SCRATCH/build/static/media/*.woff2          ← 字体，需要子集化后内嵌
```

**验证构建产物确实含你的改动**（中文会被转义成 `\uXXXX`，所以别用中文搜）：

```bash
JS=$(ls "$SCRATCH/build/static/js/main."*.js | head -1)
CSS=$(ls "$SCRATCH/build/static/css/main."*.css | head -1)
grep -c "你的css类名" "$CSS"      # 例如 audio-3a-modal
grep -c "你的i18n键" "$JS"        # 例如 audio3a
```

---

## 2. 起预览服务

```bash
python3 <skill>/scripts/serve_preview.py --repo "$SCRATCH" --port 8097
```

**用受管后台任务启动**（不要 `setsid nohup ... &`，会被回收）。
启动后访问 `http://127.0.0.1:8097/enter` —— 该路径会写 localStorage 免登录并跳到 `/live-view`。

如果端口被占用（旧服务还在跑，抓到的会是旧界面），换端口。

---

## 3. 抓取（四样东西）

浏览器的 `browser_evaluate` 抓取，**一律用同步函数返回字符串**。

### 3.1 页面 DOM

```js
() => document.getElementById('root').outerHTML
```

先把界面调到**你想展示的状态**（例如打开某个开关，让新按钮出现），再抓。

### 3.2 弹窗外壳 + 另一个模式的内容区

完整弹窗**只抓一次**（否则表头/底部会重复、选中态落在隐藏那份）。

推荐做法：在浏览器里切换模式、把第二个内容区注入成隐藏兄弟节点，然后整个抓。

```js
() => {
  const m = document.querySelector('.your-modal');
  if (!m) return 'MODAL_MISSING';
  const overlay = m.closest('.ui-modal-overlay') || m;
  return overlay.outerHTML;
}
```

另一个模式的子树单独抓（同样同步）：

```js
() => {
  const el = document.querySelector('.your-advanced-pane');
  return el ? el.outerHTML : 'PANE_MISSING';
}
```

> **不要**写 `async () => { await sleep(...) }`：`browser_evaluate` 的存盘发生在
> Promise 完成之前，文件会是空的。需要等 React 重渲染时，
> 用「先点、再单独一次调用抓」的两步法。

### 3.3 保存抓取结果

`browser_evaluate` 的 `filename` 参数**只能写到允许的根目录**
（`~/dsh-artifacts` 等）。写到别处会报 `File access denied`。

抓到的内容是 **JSON 字符串**（带引号和转义），用 Python 解码：

```python
import json, pathlib
raw = pathlib.Path("cap.html").read_text(encoding="utf-8")
try:
    html = json.loads(raw)      # 是 JSON 字符串
except Exception:
    html = raw                  # 已经是原始 HTML
pathlib.Path("cap.decoded.html").write_text(html, encoding="utf-8")
```

---

## 4. 合并两个模式的内容区

用 `scripts/merge_panes.py`（平衡标签扫描，安全提取子树）：

```bash
python3 <skill>/scripts/merge_panes.py \
  --shell  <含弹窗外壳的抓取> \
  --pane   <另一个模式的抓取> \
  --pane-class audio-3a-advanced \
  --pane-id  demo-adv-body \
  --out    merged_modal.html
```

结果：**一个 `.ui-modal-overlay` 外壳 + 两个内容区**（其中一个 `hidden`）。

---

## 5. 组装单文件 HTML

```bash
python3 <skill>/scripts/build_demo.py \
  --scratch "$SCRATCH" \
  --page   page.decoded.html \
  --modal  merged_modal.html \
  --out    "/home/steven/固件/reCamera Pro/<日期>_<主题>/<主题>配置UI演示.html" \
  --title  "reCamera WebUI · <主题>（UI 演示）"
```

脚本会：

1. 读取真实打包 CSS
2. 收集页面 + 弹窗里出现的所有字符，**对 7 个字体做子集化**并 base64 内嵌
3. 拼装成一份自包含 HTML

字体子集化效果（参考）：

| 字体 | 原始 | 子集后 |
|---|---|---|
| Montserrat Regular/Medium/SemiBold/Bold | 各 ~125KB | 各 ~18KB |
| SourceHanSansSC Regular/Medium/Bold | 各 ~11MB | 各 ~120KB |
| **合计** | **~35MB** | **~430KB** |

---

## 6. 交互 JS

抓来的 DOM 是死的，交互要自己写。注意：

- **选择器要按抓取到的真实类名写**，不要猜。先 `grep` 抓取文件确认：
  例如档位按钮可能**没有** `data-*` 属性，只能按文案定位。
- 需要模拟的典型交互：打开/关闭弹窗、模式切换（切两个内容区的 `hidden`）、
  预设联动（改多个开关 + 档位）、单项开关、按钮的启用/禁用与文案。
- 用 `classList.toggle` + `setAttribute('aria-pressed', ...)` 同步视觉状态。

把 JS 写成独立文件传给 `build_demo.py --interactions`，便于复用与调试。

---

## 7. 必做的视觉对照

```bash
# 1) 真实界面（预览服务）截图
# 2) 演示文件截图
# 3) 用 read_image 亲眼比对
```

对照要点：标题字号、区块间距、主色、控件形态（开关/按钮/选中态）、
字体（中文与数字）、弹窗宽度、遮罩深浅。

**只看 DOM 断言不够**——很多问题只有看图才发现
（例如模式按钮有重影、选中态颜色不对、间距错位）。

---

## 8. 清理

```bash
git -C "$REPO" worktree remove --force "$SCRATCH"
git -C "$REPO" status --porcelain        # 应只剩用户原有改动
```

停服务：用受管后台任务的 kill；或用 `ps` 取 PID 精确 kill
（**别用 `pkill -f`，会把当前 shell 一起杀掉**）。