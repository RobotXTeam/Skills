# 坑：这个环境踩过的都在这

每条都实际发生过，附现象与处理。

---

## 一、文件写入不落盘

**现象**：用 write 工具或 `cat > file <<EOF` 写到 `/tmp`、`~/.cache`，
命令报成功，`ls` 却找不到文件。有时过一会儿才消失。

**处理**：

- 需要持久保存的中间产物，写到**仓库相邻的可控目录**或 `~/dsh-artifacts`
- 脚本内部生成文件用 Python `pathlib.write_text()`，比 shell 重定向稳
- **写完立刻 `ls` 验证**，别假设成功

**可靠位置**：仓库目录、`~/固件/`、`~/dsh-artifacts/`
**不可靠**：`/tmp/`、`~/.cache/`

---

## 二、`browser_evaluate` 用 `async` 会存出空文件

**现象**：`async () => { await sleep(300); return html; }`
配合 `filename` 参数 → 文件不存在或为空（报 `Resulting promise was garbage collected`）。

**原因**：存盘发生在 Promise resolve 之前。

**处理**：只用**同步**函数返回字符串。需要等 React 重渲染就分两次调用：
先点、再抓。

---

## 三、`hidden` 属性被 CSS 盖掉

**现象**：弹窗设了 `hidden`，仍然拦截鼠标点击
（Playwright 报 `... intercepts pointer events`）。

**原因**：`.ui-modal-overlay` 自带 `display:flex`，优先级高于
`hidden` 属性默认的 `display:none`。

**处理**：在演示自己的 `<style>` 里补：

```css
[hidden]{display:none !important}
```

---

## 四、CSS 特异性：`:hover` 压过选中态

**现象**：选中态按钮鼠标移上去变成灰色（`--button-secondary-hover`），
看起来像没选中。

**原因**：`.x:hover` 特异性 (0,2,0) > `.x--active` (0,1,0)。

**处理**：显式补一条

```css
.x--active:hover{background:var(--btn-selected-bg);border-color:var(--btn-selected-border)}
```

> 这其实也可能是**真实产品里的缺陷**。修完提醒用户：研发那边也该修。

---

## 五、弹窗抓两份 → 结构重复

**现象**：演示里表头出现两次、底部按钮两组、模式选中态落在隐藏的那份上。

**原因**：把两个模式各抓了一份完整弹窗，叠在一起。

**处理**：**一个外壳 + 只切换内容区**。
用 `scripts/merge_panes.py` 把第二个模式的子树合并进同一个外壳。

---

## 六、字体太大 / 字体退化

**现象 A**：全量内嵌字体 → 单文件 47MB，没法发。
**现象 B**：不内嵌 → 退回系统默认字体，中文和数字观感与线上不同。

**处理**：**按实际用到的字符做子集化**（`pyftsubset` / fontTools），
7 个字重合计 35MB → 约 430KB。`build_demo.py` 已内置。

需要 `brotli` 才能输出 woff2（本机已有）。

字符集要包含**动态写入的文字**（JS 里拼的提示语、按钮文案），
否则那些字会掉回系统字体。

---

## 七、主题变量取不到

**现象**：演示颜色奇怪（例如面板变成橄榄绿、选中态是深绿）。

**原因**：该项目的主题变量挂在 **`body[data-theme=...]`**，不是 `:root`。
`<body>` 没带 `data-theme` 就没有任何变量。

**处理**：`<body data-theme="light">`，并且改用**语义化变量**
（`--bg-secondary`、`--text-primary`）而不是品牌强调色变量
（`--info-box-bg` 是绿色，用作中性面板背景会很难看）。

---

## 八、`npm start` 连不到 Mock 后端

**现象**：开发服务器下所有接口 404。

**原因**：该仓库 `package.json` **没有 `proxy` 字段**，
开发服务器（:3000）不会把 `/cgi-bin/...` 转发到后端（:8000）。

**处理**：用 `scripts/serve_preview.py`，把构建产物与 Mock 后端挂同一端口。
**不要为了本地预览去改仓库的 `package.json`。**

---

## 九、后台进程与杀进程

**现象**：`setsid nohup cmd &` 起的服务没起来，或起完就没了。
`pkill -f "关键字"` 把自己所在的 shell 也杀了（shell 命令行里含该关键字）。

**处理**：

- 起服务用**受管后台任务**（工具的 background 模式）
- 杀进程：先 `ps -eo pid,args` 取 PID，再 `kill <PID>`
- 需要按行筛选时用 `awk 'index($0,"关键字") && !/awk/'`，
  并排除 `grep -v "ps -eo"` 这类自匹配

---

## 十、端口占用导致抓到旧界面

**现象**：明明重建了，截图还是旧的。

**原因**：旧服务仍占着端口，新服务 `bind` 失败但没注意，浏览器连到旧进程。

**处理**：起服务后**确认监听**（`curl` 探一下），
并核对 `index.html` 引用的 JS hash 是否是新构建的：

```bash
curl -s http://127.0.0.1:PORT/ | grep -o 'main\.[a-z0-9]*\.js'
ls "$SCRATCH/build/static/js/" | head
```

---

## 十一、`git worktree` 的收尾

**现象**：临时工作树残留，`git worktree list` 里多出一条；
或 `node_modules` 软链被 `rsync --delete` 之类误删。

**处理**：收尾固定做

```bash
rm -f "$SCRATCH/node_modules"          # 只删软链
git -C "$REPO" worktree remove --force "$SCRATCH"
git -C "$REPO" worktree list           # 应只剩主仓库
```

---

## 十二、`find`/`grep` 在超大 SDK 上很慢

**现象**：在 RV1126B 整个目录树上跑 `grep -r` 要很久。

**处理**：限定到具体仓库、限定 `--include`，并加 `timeout`：

```bash
timeout 120 grep -rl "关键字" --include=*.c --include=*.h ./某个仓库
```

优先用 `grep` 工具并限定 `path`。