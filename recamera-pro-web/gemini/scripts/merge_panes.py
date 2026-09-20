#!/usr/bin/env python3
"""把两个模式的内容区合并进同一个弹窗外壳。

问题：如果简单/高级两个模式各抓了一份完整弹窗，叠在一起就会表头重复、
底部按钮两组、选中态落在隐藏的那份上。

做法：以外壳那份为基准，把另一个模式的子树提取出来，作为隐藏兄弟节点
插到基准内容区之后，形成「一个外壳 + 两个内容区」。

用法：
    python3 merge_panes.py \
        --shell  cap_modal_simple.decoded.html \
        --pane   cap_modal_adv.decoded.html \
        --pane-class audio-3a-advanced \
        --pane-id  demo-adv-body \
        --out    merged_modal.html

可选：
    --shell-class   基准内容区的 class（默认自动探测 .X-simple / 第一个内容区）
    --pretty        输出统计信息
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys


def load_maybe_json(path: pathlib.Path) -> str:
    """抓取结果可能是 JSON 字符串（带引号转义），也可能已是原始 HTML。"""
    raw = path.read_text(encoding="utf-8")
    try:
        value = json.loads(raw)
        return value if isinstance(value, str) else raw
    except Exception:
        return raw


def find_element(html: str, cls: str) -> tuple[str | None, int, int]:
    """按 class 定位第一个元素，返回 (outerHTML, start, end)。

    用平衡标签扫描，能正确处理嵌套的同名标签。
    """
    m = re.search(
        r'<div[^>]*class="[^"]*(?<![\w-])' + re.escape(cls) + r'(?![\w-])[^"]*"[^>]*>',
        html,
    )
    if not m:
        return None, -1, -1

    start = m.start()
    i = m.end()
    depth = 1
    tag_re = re.compile(r"<(/?)div\b[^>]*?(/?)>")
    while depth > 0:
        t = tag_re.search(html, i)
        if not t:
            return None, -1, -1
        if t.group(2) == "/":          # 自闭合 <div/>
            pass
        elif t.group(1) == "/":        # </div>
            depth -= 1
        else:                          # <div>
            depth += 1
        i = t.end()
    return html[start:i], start, i


def detect_content_pane(shell: str, exclude: str | None = None) -> str | None:
    """自动探测基准内容区：找形如 .x-simple 或第一个 .x-* 直接子区块。"""
    for pattern in (r"audio-3a-simple", r"[\w-]+-simple", r"[\w-]+-basic"):
        for m in re.finditer(r'<div[^>]*class="([^"]*)"', shell):
            classes = m.group(1).split()
            for c in classes:
                if re.fullmatch(pattern.replace(r"[\w-]+", r"[a-z0-9-]+"), c):
                    if exclude and c == exclude:
                        continue
                    return c
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shell", required=True, help="含弹窗外壳的抓取文件")
    ap.add_argument("--pane", required=True, help="含另一个模式内容区的抓取文件")
    ap.add_argument("--pane-class", required=True, help="要提取的内容区 class")
    ap.add_argument("--pane-id", default="demo-alt-pane", help="插入后的 wrapper id")
    ap.add_argument("--shell-class", default=None, help="基准内容区 class（默认自动探测）")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    shell_path = pathlib.Path(args.shell).expanduser()
    pane_path = pathlib.Path(args.pane).expanduser()
    out_path = pathlib.Path(args.out).expanduser()

    shell = load_maybe_json(shell_path)
    pane_src = load_maybe_json(pane_path)

    pane, _, _ = find_element(pane_src, args.pane_class)
    if not pane:
        print(f"✗ 在 {pane_path.name} 里找不到 .{args.pane_class}", file=sys.stderr)
        return 1

    base_class = args.shell_class or detect_content_pane(shell, exclude=args.pane_class)
    if not base_class:
        print("✗ 无法探测基准内容区，请用 --shell-class 指定", file=sys.stderr)
        return 1

    base, _, base_end = find_element(shell, base_class)
    if not base:
        print(f"✗ 在 {shell_path.name} 里找不到 .{base_class}", file=sys.stderr)
        return 1

    wrapped = f'<div id="{args.pane_id}" hidden>{pane}</div>'
    merged = shell[:base_end] + wrapped + shell[base_end:]
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(merged, encoding="utf-8")

    print(f"基准内容区 : .{base_class}  ({len(base)} 字符)")
    print(f"并入内容区 : .{args.pane_class}  ({len(pane)} 字符) -> #{args.pane_id}")
    print(f"输出       : {out_path}  ({len(merged)} 字符)")
    print(f"  ui-modal-overlay 出现次数 : {merged.count('ui-modal-overlay')}")
    print(f"  内容区 wrapper 出现次数   : {merged.count(args.pane_id)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())