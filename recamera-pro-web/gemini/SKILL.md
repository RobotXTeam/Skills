---
name: recamera-pro-web
description: 为 reCamera Pro（RV1126B）WebUI 制作「可双击打开的 UI 原型演示」，供产品经理拿给研发看——让研发照着这个界面和逻辑去改代码。当用户要求「做个 UI 给研发看」「加个按钮/弹窗/页面」「我有个新 UI 需求」「做个界面演示/原型/效果图」，且对象是 reCamera Pro 的 Web 管理界面时使用。产出为单个离线 HTML（完全复刻现有界面外观）+ 交付目录 ~/固件/reCamera Pro/<日期>_<主题>/。注意：只针对 reCamera Pro 的 WebUI（仓库 linux-app-web-recamera_web_react），不是 reCamera 2002，也不是 sscma-example-sg200x 的 Studio/Node-RED 项目。
---

# reCamera Pro WebUI 原型（给研发看的 UI 演示）

## 一、这个 skill 的定位（先读，别搞错）

使用者是**产品经理**，不是开发。目标是：

> 把「界面应该长什么样、交互逻辑怎么走」做成能直接打开点给研发看的东西，
> 研发照着实现。**怎么改代码是研发的事，产品不管。**

因此：

- **产出 = 可双击打开的单个 HTML 演示**，不是代码补丁包、不是测试、不是部署脚本。
- **演示必须完全保留现有界面的样子**。在原有 UI 上"加东西、改东西"，
  绝不能另起一套设计——否则研发看到的是假界面，会被误导。
- **打开方式必须极简**：双击 → 浏览器打开 → 能点。不要求装环境、起服务、敲命令。
- 演示是**纯界面**，不连设备；点击只在浏览器内生效。

反过来说，**不要**交付这些东西作为主体：git 补丁、单元测试、启动脚本、部署说明。

## 二、产品边界（最常搞错的地方）

| 是 | 不是 |
|---|---|
| **reCamera Pro**（RV1126B） | reCamera 2002 / reCamera 2003 等其它型号 |
| Web 管理界面仓库 `linux-app-web-recamera_web_react` | `sscma-example-sg200x` 的 Supervisor Studio（Node-RED 项目，见 `reweb` skill） |
| 交付到 `~/固件/reCamera Pro/` | 其它产品目录 |

**判定方法**：先确认仓库路径。只有
`/home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react`
（或其等价的 RV1126B 检出）才是本 skill 的对象。

如果用户说的是 reCamera Studio、Node-RED、Supervisor、Vite 预览，那是 `reweb` skill，
不是这个。**不确定就先问，别猜。**

## 三、固定路径

```
前端仓库（UI 的真实来源）
  /home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react

后端仓库（内置 Mock 后端在此仓库的 backend/ 子目录）
  /home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_backend

交付目录（命名规则固定）
  ~/固件/reCamera Pro/<YYYY.M.D>_<主题>/
    例：~/固件/reCamera Pro/2026.9.20_3a/

交付内容
  <主题>配置UI演示.html      ← 主角：双击打开，完全离线
  README.md                  ← 极简：怎么打开 + 怎么看 + 要跟研发说明什么
  files/                     ← 实现参考（给研发，产品不用管）
```

用 `scripts/new_delivery.sh` 建交付目录骨架。

## 四、技术栈与现有约定（改动要跟着走）

- React 18 + Create React App，样式是**普通 CSS 文件**（不是 CSS-in-JS、不是 Tailwind）
- 主题色变量挂在 **`body[data-theme="light"|"dark"]`** 上（**不是 `:root`**），
  明亮/暗色两套都要照顾
- 所有用户可见文案走 i18n：`src/i18n/translations.js` 或独立的
  `src/i18n/xxxMessages.js`（新模块在 `translations.js` 里注册）
- 可复用组件在 `src/components/common/`（`Modal`/`ModalHeader`/`ModalBody`/`ModalFooter`、
  `Button`、`Select`、`Tooltip`）；弹窗尺寸 `size="sm|md|lg|xl|full"`
- 设备接口路径集中在 `src/contexts/urls.js`，请求封装在 `src/contexts/API.js`
- 已有"简单/高级"分层先例，**新功能沿用同一范式**：
  可视化 ↔ 高级 JSON（`SchemaForm.js`）、`simpleImport`/`advancedImport`、
  `outputSettings.advanced`
- 前端改动完成后要 `npm run build` 能过（见该仓库 `AGENTS.md`：
  响应式三档、明暗主题、i18n、复用现有组件、不硬编码颜色）

## 五、工作流

### Step 0 — 先定"改什么"，再动手

跟用户确认三件事（缺一不可）：

1. **放在哪个位置**（哪个页面、哪个区块、哪个按钮旁边）
2. **暴露到什么深度**（普通用户看到什么、研发/专家看到什么）
3. **这是新功能还是改现有功能**（改现有的要指出原来长什么样）

如果用户已经在对话里说清楚了，直接做，别反复问。**不确定的默认按"两层"设计**：
普通用户看到结果化的开关与预设，专家/研发才看到原始参数。

### Step 1 — 在临时工作树里实现（绝不弄脏仓库）

**铁律：主仓库保持干净。** 用户可能刚拉过代码，不要把 WIP 留在里面。

```bash
REPO=/home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react
SCRATCH=/home/steven/work/RV1126B/仓库/完整的/rockchip/.ui-prototype-<主题>

git -C "$REPO" worktree add --detach "$SCRATCH" HEAD
ln -s "$REPO/node_modules" "$SCRATCH/node_modules"     # 复用依赖
# 在 $SCRATCH 里改代码实现设计
cd "$SCRATCH" && CI=false npx --no-install react-scripts build
```

改完必须构建成功。**构建成功才可能抓到真实界面。**

### Step 2 — 起预览服务，抓真实的 DOM 与 CSS

用 `scripts/serve_preview.py` 把「构建产物 + Mock 后端」挂到同一端口
（该仓库 `package.json` **没有配 dev proxy**，所以 `npm start` 够不到后端）：

```bash
# 后台起服务（受管后台任务，不要用 setsid/nohup）
python3 <skill>/scripts/serve_preview.py --repo "$SCRATCH" --port 8097
# 打开 http://127.0.0.1:8097/enter  （免登录直达 /live-view）
```

抓四样东西（详细配方见 `references/capture-recipe.md`）：

1. **真实打包 CSS**：`$SCRATCH/build/static/css/main.*.css`（含全站样式，直接内联）
2. **页面 DOM**：浏览器里取 `document.getElementById('root').outerHTML`
3. **弹窗外壳**：整个 `.ui-modal-overlay`
4. **另一个模式的内容区**：切换模式后取 `.audio-3a-advanced` 之类的子树

> 抓取一律用**同步返回字符串**的 `browser_evaluate`。
> **不要用 `async` 函数**——写文件会在 Promise 完成前发生，结果文件是空的。

### Step 3 — 组装单文件 HTML

```bash
python3 <skill>/scripts/build_demo.py \
  --scratch "$SCRATCH" \
  --captures <抓取文件目录> \
  --out "$HOME/固件/reCamera Pro/<日期>_<主题>/<主题>配置UI演示.html" \
  --interactions <交互脚本.js>
```

它做四件事：

1. 内联真实打包 CSS（外观与线上一致的根本保证）
2. **字体子集化后 base64 内嵌**——思源黑体每个字重 11MB，不子集化文件会是 47MB；
   按实际用到的字符子集化后约 400KB，且离线可用、字体不退化成系统默认
3. 拼上抓来的页面 DOM + 弹窗 DOM
4. 注入交互 JS

抓取的静态 DOM 不会自己动，**需要用原生 JS 重实现交互**
（打开/关闭、模式切换、场景联动、开关、档位、保存/重置的视觉反馈）。
参考 `scripts/` 里的实现，或直接写一段 vanilla JS 传进去。

### Step 4 — 验证：和真实界面对照

**必须做视觉对照**，否则"看起来不一样"是最大的失败模式：

```bash
# 真实界面（Step 2 的服务）截图
# 演示文件截图
# 两张图放一起看：标题/间距/颜色/控件形态/字体是否一致
```

用 `read_image` 亲眼比对，不要只看 DOM 断言。同时跑一遍交互验收（见第七节）。

### Step 5 — 交付并还原

```bash
bash <skill>/scripts/new_delivery.sh "<主题>"       # 建目录骨架
cp <组装好的.html> "$HOME/固件/reCamera Pro/<日期>_<主题>/"
# 写极简 README（模板见 references/delivery-readme-template.md）
# 需要给研发参考的实现代码放 files/
```

**然后把仓库还原干净**：

```bash
git -C "$REPO" worktree remove --force "$SCRATCH"
git -C "$REPO" status --porcelain          # 应当只剩用户自己原有的改动
```

## 六、坑（都是踩过的）

| 坑 | 现象 | 处理 |
|---|---|---|
| 写文件不落盘 | `/tmp`、`~/.cache` 下用 write 工具或 heredoc 写的文件消失 | 写到**仓库相邻目录**或 `~/dsh-artifacts`；脚本内文件用 `pathlib` 写 |
| `async` 抓取 | `browser_evaluate` 存文件为空 | 用**同步**函数返回字符串 |
| `hidden` 失效 | 弹窗设了 `hidden` 仍挡住点击 | 目标站点 `.ui-modal-overlay` 有 `display:flex`，需补 `[hidden]{display:none!important}` |
| CSS 特异性 | 选中态按钮悬停变灰 | `:hover`(0,2,0) 压过单类(0,1,0)；补 `--active:hover` 规则 |
| 弹窗抓两份 | 表头/底部按钮重复、选中态落在隐藏那份 | **一个外壳 + 只切换内容区**，用 `merge_panes.py` 合并 |
| 字体太大 | 单文件 47MB | **必须字体子集化**（`build_demo.py` 已内置） |
| 主题变量取不到 | 颜色诡异 | 变量在 `body[data-theme]`，确保 `<body>` 带该属性 |
| `npm start` 连不上后端 | 请求全 404 | 该仓库无 dev proxy，必须用 `serve_preview.py` 同端口方案 |
| 后台进程自杀 | `pkill -f` 把自己 shell 也杀了 | 用**受管后台任务**；杀进程用 `ps` 取 PID 精确 kill |
| 端口占用 | 新服务起不来，抓的还是旧界面 | 换端口，或先确认旧进程已停 |

## 七、验收清单（交付前逐条过）

**外观**
- [ ] 侧边栏、页面标题、标签栏与真实界面一致（不是自己画的）
- [ ] 字体是真实的（页面元素 `font-family` 含 `Montserrat` / `Source Han Sans SC`）
- [ ] 主色是 `#8fc31f`
- [ ] 明暗主题都正常

**功能**
- [ ] 双击（或本地打开）即用，无外部网络依赖
- [ ] 目标按钮出现在正确位置（与原有按钮的相对位置对）
- [ ] 弹窗能开、能关（关闭按钮 / 取消 / Esc / 点遮罩）
- [ ] 模式切换正常，且**模式按钮只有一组**
- [ ] 预设/场景联动：切换后下面的开关与档位跟着变
- [ ] 底部按钮齐全、状态提示正确
- [ ] 窄屏（~400px）不横向溢出

**交付**
- [ ] 文件在 `~/固件/reCamera Pro/<日期>_<主题>/`
- [ ] README 里只有「怎么打开、怎么看、要跟研发说明什么」
- [ ] 主仓库 `git status` 干净（只剩用户原有改动）

## 八、给研发说明什么（README 必写）

产品最需要在 README 里讲清的三点：

1. **沿用现有样式与组件，没有另起设计**——新增的只是 X、Y、Z
2. **分层是有意的**：普通用户层给什么、专家层给什么，以及为什么
3. **已知的限制**，例如按钮只在某开关打开时出现、参数默认值待算法确认、
   设备端接口尚未实现等

## 九、参考文件

- `references/product-boundaries.md` — reCamera Pro 与其它项目的区分（**先读这个**）
- `references/capture-recipe.md` — 抓取真实 DOM/CSS 的完整命令与配方
- `references/pitfalls.md` — 环境与技术的坑（更详细）
- `references/delivery-readme-template.md` — 交付 README 模板
- `scripts/serve_preview.py` — 起「构建产物 + Mock 后端」同端口预览
- `scripts/build_demo.py` — 组装单文件 HTML（内联 CSS + 字体子集化）
- `scripts/merge_panes.py` — 把两个模式的内容区合并进一个弹窗外壳
- `scripts/new_delivery.sh` — 建交付目录骨架