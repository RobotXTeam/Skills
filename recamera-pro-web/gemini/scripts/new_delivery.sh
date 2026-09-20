#!/usr/bin/env bash
# 建 reCamera Pro UI 演示的交付目录骨架。
#
# 用法：
#   bash new_delivery.sh "3a"                  # -> ~/固件/reCamera Pro/2026.9.20_3a/
#   bash new_delivery.sh "应用中心改版" "2026.10.8"
#
# 命名规则固定： <YYYY.M.D>_<主题>
# 目录固定位于： ~/固件/reCamera Pro/
set -euo pipefail

THEME="${1:-}"
DATE="${2:-$(date +%Y.%-m.%-d)}"

if [ -z "$THEME" ]; then
  echo "用法: bash new_delivery.sh <主题> [日期，如 2026.9.20]" >&2
  exit 1
fi

ROOT="$HOME/固件/reCamera Pro"
DEST="$ROOT/${DATE}_${THEME}"

if [ -e "$DEST" ]; then
  echo "已存在：$DEST"
  echo "（如需重建请先自行移走旧目录）"
  exit 0
fi

mkdir -p "$DEST/files"
chmod 775 "$ROOT" 2>/dev/null || true

cat > "$DEST/README.md" <<EOF
${THEME} · UI 演示
=========================

双击打开： ${THEME}配置UI演示.html

就这么简单 —— 双击，浏览器打开，就能点。


怎么看
------

打开后：<填写操作路径，例如：画面设置 → 基础设置 → 音频设置>

<填写新增/改动说明>


要跟研发说明的三点
------------------

1. 界面完全沿用现有 WebUI 的样式和组件，没有另起一套设计。
   新增的只有 <填写>。

2. <填写设计意图>

3. <填写已知限制>


说明
----

- 这是纯界面演示，不连接任何设备，点击只在浏览器里生效。
- 界面、字体、配色都取自真实构建产物，外观与线上一致。
- 单一 HTML 文件，可离线打开、可直接发给别人，无需安装任何东西。


附：研发实现参考
----------------

files/ 目录里是实现所需的代码与接口契约，供研发参考，产品无需关心。
EOF

echo "已创建交付目录："
echo "  $DEST"
echo
echo "接下来："
echo "  1) 把组装好的 HTML 放进去（名字用 <主题>配置UI演示.html）"
echo "  2) 填写 $DEST/README.md 里的 <填写> 占位"
echo "  3) 需要给研发的代码放 $DEST/files/"
echo
ls -la "$DEST"