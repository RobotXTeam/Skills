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

---

## 十三、新建/改名 skill 时：DSH 的命名与 frontmatter 硬规则

**症状**：skill 目录、`SKILL.md` 都放好了，但 `/名字` 不出现，会话 catalog 里也没有。

**原因**：DSH 对不合规的 skill **静默忽略**，只在 logger 里告警，界面上看不到任何提示。

### 硬规则（来自 `@deepseek-ai/dsh-skill`）

```js
const SKILL_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;   // 全小写 kebab-case
```

- **只允许** `a-z` `0-9` 和连字符，且不能连续/首尾连字符
- **不允许**大写字母、下划线、中文、空格
- 例：`reCameraPro_web` ✗ → `recamera-pro-web` ✓

### frontmatter 也是硬门槛

用 YAML 解析，`description` 里的 **ASCII `": "`** 会让纯量解析失败：

```yaml
description: ... Triggers on: reCamera Pro, ...      # ✗ Nested mappings are not allowed
```

**修法**：改用折叠块标量

```yaml
description: >-
  ... Triggers on: reCamera Pro, ...
```

### 自查方法（不要靠猜）

DSH 的 skill 目录都是软链 → `~/.claude/skills/*`。要一次找出**所有**被忽略的 skill，
直接跑它自己的发现实现：

```bash
cat > /tmp/test_discovery.mjs <<'JS'
const APP = "/opt/DeepSeek Harness/resources/app/node_modules/@deepseek-ai";
const { FileSystemSkillProvider } = await import(`${APP}/dsh-skill-filesystem/lib/index.js`);
const warnings = [];
const ctx = { get: () => undefined,
  logger: { warn: (m) => warnings.push(m), info(){}, error(){} } };
const provider = new FileSystemSkillProvider(ctx,
  { invalidate(){}, signal: new AbortController().signal }, {});
const list = await provider.list({ cwd: process.cwd() });
const c = Array.isArray(list) ? list : list.candidates;
console.log("发现:", c.length);
console.log(warnings.map((w) => "  ! " + w).join("\n") || "  （无告警）");
await provider.dispose().catch(() => {});
process.exit(0);
JS
node /tmp/test_discovery.mjs
```

输出里 `ignored: invalid skill name` / `ignored: invalid YAML frontmatter`
就是被静默丢弃的 skill 及原因。

> 注意：必须带 `process.exit(0)`，否则 chokidar 的文件监听会让进程不退出。

### 顺带

`~/.agents/skills/` 里有一批**大写命名**的旧副本（`CloneStore`、`Linkbit`、
`OpenASR`、`Weekly` 等），会被同样拒绝并产生告警噪音。小写版本在
`~/.dsh/skills` 里是好的，所以功能不受影响——但每次扫描都会刷告警。

---

## 十四、最大的坑：手写界面（"看起来差不多"）

**症状**：演示页能打开、能点，但风格、间距、字体、控件形态明显和原版不一样。
产品评审时看得过去，研发照着做就偏了。

**成因**：为了省事，没有走"抓真实构建产物"的路，而是自己写了一版 HTML/CSS。
**这条路是错的**——即使配色和主色都照抄，细节（字体、间距、控件、阴影、圆角、
交互态）也一定对不上，因为真实样式是 371KB 的完整样式表。

**真实发生过的对比**：

| 做法 | 结果 |
|---|---|
| 手写 HTML/CSS | 配色、圆角、控件全是我另设计的，和原版**完全不像** |
| 抓真实 DOM + 内联真实 CSS + 子集化字体 | 与线上**逐像素级接近**（3A 那次） |

**防线**：`scripts/verify_fidelity.py`。它把这件事变成可执行判据——

```
✗ 真实打包 CSS 完整内联   仅覆盖 0.0% —— 样式是手写的，或抓取时漏了真实 CSS
✗ 真实应用结构标记        缺少 ['class="app-container"', ...] —— DOM 不是从真实界面抓的
✗ 字体已内嵌              未内嵌 —— 中文/数字会退化成系统字体
```

**规矩**：

1. 演示页的 `<style>` 必须**完整包含**打包 CSS，不许自己写
2. DOM 必须是浏览器从真实运行界面抓的，不许自己搭
3. 除 `[hidden]{display:none!important}` 和选中态 `:hover` 两条必要修正外，
   **不应有任何自写 CSS**；多出来的自写样式一律删掉
4. 没过 `verify_fidelity.py` 不许交付

**修法是回抓取流程重做，不是在手写的那份上继续调。** 继续调只会越描越偏。
