#!/usr/bin/env python3
"""演示页「保真度」硬校验：确认输出确实用了真实界面的 CSS 与 DOM。

为什么需要它
------------
这个 skill 最容易、也最严重的失败方式，是**另起一套设计**——
手写 HTML/CSS 做一个"看起来差不多"的界面。研发看到的是假界面，会被误导，
而产品拿去评审时根本分辨不出来。

"必须保真"如果只写成一句文字要求，是拦不住的。本脚本把它变成可执行的闸门：
**没过就不要交付。**

判定依据是硬事实，不是主观观感：

1. 输出里的样式表必须**完整包含真实打包 CSS**（字体 URL 归一化后逐字比对）
   —— 这是外观与线上一致的根本保证；手写的 CSS 一定过不了
2. 必须包含真实应用的**结构标记**（侧边栏 / 应用容器等）
   —— 证明 DOM 是从真实运行界面抓的，不是自己搭的
3. 字体必须内嵌 —— 否则中文与数字会退化成系统默认字体，观感立刻不同
4. 不得有外部网络依赖 —— 保证离线双击可用
5. 主题变量必须可用（`body[data-theme]`）—— 否则颜色会错

用法
----
    python3 verify_fidelity.py --demo <演示.html> --scratch <已构建的仓库>
    python3 verify_fidelity.py --demo <演示.html> --real-css <打包css路径>
    python3 verify_fidelity.py --demo <演示.html> --scratch <repo> --expect "3A算法配置"

退出码：0 = 通过；1 = 未通过（打印每项的具体原因与差距）
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

DEFAULT_SCRATCH = (
    "/home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react"
)

# 真实应用的结构标记：来自抓取的真实 DOM，手写界面不会带这些
DEFAULT_MARKERS = [
    'class="app-container"',
    'class="sidebar"',
    "sidebar-nav",
]

MIN_COVERAGE = 0.999  # 归一化后真实 CSS 的覆盖率下限


def normalize_css(text: str) -> str:
    """把 url(...) 内容抹平，使内嵌字体后的 CSS 仍可与原 CSS 比对。"""
    return re.sub(r"url\([^)]*\)", "url(*)", text)


def extract_style(html: str) -> str:
    """取第一个 <style> 块的内容。"""
    m = re.search(r"<style[^>]*>(.*?)</style>", html, re.S | re.I)
    return m.group(1) if m else ""


def coverage(needle: str, haystack: str, window: int = 500, step: int = 2000) -> float:
    """真实 CSS 有多少比例出现在输出里（按窗口采样，便于报告差距）。"""
    if not needle:
        return 0.0
    total = hits = 0
    for i in range(0, max(1, len(needle) - window + 1), step):
        total += 1
        if needle[i : i + window] in haystack:
            hits += 1
    return hits / total if total else 0.0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--demo", required=True, help="要校验的演示 HTML")
    ap.add_argument("--scratch", default=DEFAULT_SCRATCH,
                    help="已构建的仓库/工作树（自动取 build/static/css/main.*.css）")
    ap.add_argument("--real-css", default=None, help="直接指定真实打包 CSS")
    ap.add_argument("--expect", action="append", default=[],
                    help="必须出现的内容（可重复，例如新增按钮的文案）")
    ap.add_argument("--markers", default=None,
                    help="真实结构标记，逗号分隔（默认 app-container/sidebar/sidebar-nav）")
    ap.add_argument("--min-coverage", type=float, default=MIN_COVERAGE)
    args = ap.parse_args()

    demo_path = pathlib.Path(args.demo).expanduser()
    if not demo_path.is_file():
        print(f"✗ 找不到演示文件：{demo_path}", file=sys.stderr)
        return 1
    demo = demo_path.read_text(encoding="utf-8")
    style = extract_style(demo)

    # 真实 CSS 来源
    if args.real_css:
        real_css_path = pathlib.Path(args.real_css).expanduser()
    else:
        css_dir = pathlib.Path(args.scratch).expanduser() / "build" / "static" / "css"
        found = sorted(css_dir.glob("main.*.css"))
        if not found:
            print(f"✗ 找不到真实打包 CSS：{css_dir}/main.*.css", file=sys.stderr)
            print("  （请先构建，或用 --real-css 指定）", file=sys.stderr)
            return 1
        real_css_path = found[-1]

    if not real_css_path.is_file():
        print(f"✗ 找不到真实 CSS：{real_css_path}", file=sys.stderr)
        return 1
    real_css = real_css_path.read_text(encoding="utf-8")
    print(f"真实 CSS：{real_css_path.name}  ({len(real_css)} 字符)")
    print(f"演示文件：{demo_path.name}  ({len(demo)} 字符)")
    print(f"样式块  ：{len(style)} 字符")
    print()

    results: list[tuple[bool, bool, str, str]] = []  # (ok, critical, 名称, 详情)

    # 1) 真实 CSS 是否完整内联 —— 最关键的一项
    n_real, n_style = normalize_css(real_css), normalize_css(style)
    contained = n_real in n_style
    cov = coverage(n_real, n_style)
    ok_css = contained or cov >= args.min_coverage
    if contained:
        detail = "逐字包含 ✓"
    elif ok_css:
        detail = f"覆盖 {cov*100:.1f}%（字体 URL 被替换，属预期）✓"
    else:
        detail = (
            f"仅覆盖 {cov*100:.1f}%（要求 ≥{args.min_coverage*100:.1f}%）"
            " —— 样式是手写的，或抓取时漏了真实 CSS"
        )
    results.append((ok_css, True, "真实打包 CSS 完整内联", detail))

    # 2) 真实应用结构标记
    markers = (args.markers.split(",") if args.markers else DEFAULT_MARKERS)
    missing = [m for m in markers if m not in demo]
    results.append((
        not missing, True, "真实应用结构标记",
        f"{len(markers)} 项齐备 ✓" if not missing else f"缺少 {missing} —— DOM 不是从真实界面抓的",
    ))

    # 3) 字体内嵌
    font_count = demo.count("data:font/woff2")
    results.append((
        font_count > 0, True, "字体已内嵌",
        f"{font_count} 个 ✓" if font_count else "未内嵌 —— 中文/数字会退化成系统字体，观感立刻不同",
    ))

    # 4) 无外部依赖
    external = re.findall(r'(?:src|href)="https?://[^"]*"', demo)
    results.append((
        not external, True, "无外部网络依赖",
        "离线可用 ✓" if not external else f"存在 {len(external)} 处外部引用：{external[:2]}",
    ))

    # 5) 主题变量可用
    theme_var = 'body[data-theme=' in style
    theme_attr = re.search(r"<body[^>]*data-theme=", demo) is not None
    results.append((
        theme_var and theme_attr, True, "主题变量可用",
        "✓" if (theme_var and theme_attr)
        else f"body[data-theme] 规则={theme_var} / body 属性={theme_attr} —— 颜色会错",
    ))

    # 6) 指定内容必须出现（例如新增按钮的文案）
    if args.expect:
        miss = [s for s in args.expect if s not in demo]
        results.append((
            not miss, True, "指定内容存在",
            f"{len(args.expect)} 项齐备 ✓" if not miss else f"未找到：{miss}",
        ))

    # 汇总
    width = max(len(r[2]) for r in results)
    failed_critical = 0
    for ok, critical, name, detail in results:
        mark = "✓" if ok else ("✗" if critical else "!")
        if not ok and critical:
            failed_critical += 1
        print(f"  {mark} {name.ljust(width)}  {detail}")

    print()
    if failed_critical:
        print(f"✗ 保真度校验未通过（{failed_critical} 项关键检查失败）")
        print()
        print("最常见的成因是「另起一套设计」——手写 HTML/CSS 做了个相似的界面。")
        print("正确做法（见 SKILL.md 第五节）：")
        print("  1. 在临时工作树里实现改动并构建")
        print("  2. 用 scripts/serve_preview.py 跑起真实界面")
        print("  3. 抓取 document.getElementById('root').outerHTML 与弹窗 DOM")
        print("  4. 用 scripts/build_demo.py 组装（它会内联真实 CSS 并子集化字体）")
        print()
        print("不要为了赶时间改用手写样式：那样研发看到的是假界面。")
        return 1

    print("✓ 保真度校验通过：样式与结构均来自真实界面，可交付")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())