#!/usr/bin/env python3
"""把抓来的真实 DOM 与真实打包 CSS 组装成一个可双击打开的单文件 HTML。

做四件事：
1. 读取真实打包 CSS（build/static/css/main.*.css），保证外观与线上一致
2. 字体按实际用到的字符子集化后 base64 内嵌（35MB -> ~430KB，且可离线）
3. 拼上抓来的页面 DOM 与弹窗 DOM
4. 注入交互 JS（可选）

用法：
    python3 build_demo.py \
        --scratch  /path/to/.ui-prototype-xxx \
        --page     cap_page.decoded.html \
        --modal    merged_modal.html \
        --out      "$HOME/固件/reCamera Pro/2026.9.20_3a/3A配置UI演示.html" \
        --title    "reCamera WebUI · 3A 音频算法配置（UI 演示）" \
        --interactions demo.js

需要：fontTools（含 brotli，用于输出 woff2）。
"""

from __future__ import annotations

import argparse
import base64
import pathlib
import re
import sys

DEFAULT_SCRATCH = (
    "/home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react"
)

# 演示自身需要的样式修正（真实 CSS 里没有、但静态演示必需）
DEMO_CSS_FIXES = """
/* 演示用修正 —— 静态 DOM 打开时必须的几条 */
[hidden]{display:none !important}            /* .ui-modal-overlay 的 display:flex 会盖掉 hidden */
.audio-3a-mode__btn--active:hover,
.audio-3a-level--active:hover,
.audio-3a-scene--active:hover{
  background:var(--btn-selected-bg);
  border-color:var(--btn-selected-border);
}
"""


def load_capture(path: pathlib.Path) -> str:
    """抓取文件可能是 JSON 字符串，也可能是原始 HTML。"""
    raw = path.read_text(encoding="utf-8")
    import json

    try:
        value = json.loads(raw)
        return value if isinstance(value, str) else raw
    except Exception:
        return raw


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scratch", default=DEFAULT_SCRATCH, help="已构建的仓库/工作树路径")
    ap.add_argument("--page", required=True, help="页面 DOM 抓取文件")
    ap.add_argument("--modal", default=None, help="弹窗 DOM 抓取文件（可省略）")
    ap.add_argument("--out", required=True, help="输出的单文件 HTML")
    ap.add_argument("--title", default="reCamera WebUI · UI 演示")
    ap.add_argument("--interactions", default=None, help="交互 JS 文件")
    ap.add_argument("--overlay-id", default="demo-overlay", help="给弹窗遮罩加的 id")
    ap.add_argument("--extra-text", default="", help="额外需要纳入字体子集的文字")
    ap.add_argument("--no-font-subset", action="store_true",
                    help="不做字体子集化（文件会很大，仅调试用）")
    args = ap.parse_args()

    try:
        from fontTools import subset
    except ImportError:
        sys.exit("缺少 fontTools：pip install fonttools brotli")

    scratch = pathlib.Path(args.scratch).expanduser().resolve()
    media = scratch / "build" / "static" / "media"
    css_dir = scratch / "build" / "static" / "css"

    css_candidates = sorted(css_dir.glob("main.*.css"))
    if not css_candidates:
        sys.exit(f"找不到打包 CSS：{css_dir}/main.*.css（请先 build）")
    css = css_candidates[-1].read_text(encoding="utf-8")

    page_html = load_capture(pathlib.Path(args.page).expanduser())
    modal_html = (
        load_capture(pathlib.Path(args.modal).expanduser()) if args.modal else ""
    )
    js = (
        pathlib.Path(args.interactions).expanduser().read_text(encoding="utf-8")
        if args.interactions
        else ""
    )

    # ---------------------------------------------------------- 字体子集化
    extra = (
        "正在进入 若无自动跳转请点这里 关闭 取消 确定 保存 已保存 恢复默认 "
        "当前 演示 未连接设备 " + args.extra_text
    )
    charset = set(page_html) | set(modal_html) | set(js) | set(extra)
    charset = {c for c in charset if c.strip()}
    text = "".join(sorted(charset))
    print(f"字体子集字符数：{len(text)}")

    cache: dict[str, str] = {}
    total_before = total_after = 0

    def embed_font(filename: str) -> str | None:
        nonlocal total_before, total_after
        if filename in cache:
            return cache[filename]
        src = media / filename
        if not src.is_file():
            return None
        data_bytes = src.read_bytes()
        if args.no_font_subset:
            data = base64.b64encode(data_bytes).decode("ascii")
        else:
            opts = subset.Options()
            opts.flavor = "woff2"
            opts.layout_features = ["*"]
            opts.notdef_outline = True
            font = subset.load_font(str(src), opts)
            sub = subset.Subsetter(options=opts)
            sub.populate(text=text)
            sub.subset(font)
            tmp = media / f".subset_{filename}"
            subset.save_font(font, str(tmp), opts)
            data = base64.b64encode(tmp.read_bytes()).decode("ascii")
            tmp.unlink(missing_ok=True)
        total_before += len(data_bytes)
        total_after += len(data) * 3 // 4
        cache[filename] = data
        return data

    print("字体内嵌：")

    def repl_url(m: re.Match) -> str:
        name = m.group(1).rsplit("/", 1)[-1]
        if not name.endswith(".woff2"):
            return "none"                       # 登录页 svg 等，演示用不到
        data = embed_font(name)
        if data is None:
            print(f"  ! 缺字体 {name}（跳过）")
            return "none"
        size = len(data) * 3 // 4
        print(f"  {name[:52]:54s} -> {size/1024:7.1f} KB")
        return f'url(data:font/woff2;base64,{data}) format("woff2")'

    css = re.sub(
        r'url\((/static/media/[^)]+\.woff2)\)\s*format\("woff2"\)', repl_url, css
    )
    css = re.sub(r"url\(/static/media/[^)]+\)", "none", css)

    # ---------------------------------------------------------- 组装
    overlay_attr = f'id="{args.overlay_id}" class="ui-modal-overlay" hidden'
    if modal_html:
        modal_html = modal_html.replace('class="ui-modal-overlay"', overlay_attr, 1)

    html = (
        "<!doctype html>\n"
        '<html lang="zh-CN">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{args.title}</title>\n<style>\n"
        + DEMO_CSS_FIXES
        + "\n"
        + css
        + "\n</style>\n</head>\n"
        '<body data-theme="light">\n'
        + page_html
        + "\n"
        + modal_html
        + ("\n<script>\n" + js + "\n</script>\n" if js else "")
        + "</body>\n</html>\n"
    )

    out = pathlib.Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(html, encoding="utf-8")

    print()
    print(f"已生成：{out}")
    print(f"大小  ：{out.stat().st_size/1024:.0f} KB")
    if total_before:
        print(f"字体  ：{total_before/1024/1024:.1f} MB -> {total_after/1024:.0f} KB")

    # 自检
    problems = []
    for pat in (r'src="https?://', r'href="https?://'):
        if re.search(pat, html):
            problems.append(f"存在外部引用：{pat}")
    if "[hidden]{display:none" not in html:
        problems.append("缺少 [hidden] 修正")
    if problems:
        print("\n⚠ 自检问题：")
        for p in problems:
            print("  -", p)
        return 2

    print("自检：无外部依赖，可离线打开 ✓")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())