#!/usr/bin/env python3
"""给 reCamera Pro WebUI 起一个「构建产物 + Mock 后端」同端口的预览服务。

为什么需要它：该前端仓库的 package.json 没有配 dev proxy，所以 `npm start`
起的开发服务器（:3000）访问不到 Mock 后端（:8000）。本脚本把两者挂到同一端口，
从而不必修改仓库配置。

用法：
    python3 serve_preview.py --repo /path/to/linux-app-web-recamera_web_react [--port 8097]

    # 不带 --repo 时使用默认仓库路径
    python3 serve_preview.py

启动后：
    http://127.0.0.1:<port>/enter    ← 免登录直达 /live-view（写 localStorage 后跳转）
    http://127.0.0.1:<port>/         ← 正常入口（会走登录页）

注意：
- 仅用于本地预览/抓取真实界面，会跳过鉴权，不要用于任何真实环境。
- 请用「受管后台任务」启动，不要用 setsid/nohup（本环境下会被回收）。
"""

from __future__ import annotations

import argparse
import pathlib
import sys

DEFAULT_REPO = (
    "/home/steven/work/RV1126B/仓库/完整的/rockchip/linux-app-web-recamera_web_react"
)

ENTER_HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>进入 reCamera WebUI…</title>
<style>
body{font-family:system-ui,-apple-system,"Noto Sans CJK SC",sans-serif;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0;
background:#1a1a1a;color:#e0e0e0}
a{color:#8fc31f}
</style></head><body>
<div>正在进入… 若无自动跳转，请点 <a href="/live-view">这里</a></div>
<script>
localStorage.setItem('isAuthenticated','true');
localStorage.setItem('username','preview');
localStorage.setItem('token','preview');
localStorage.setItem('language','zh');
location.replace('/live-view');
</script></body></html>
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=DEFAULT_REPO, help="前端仓库路径（需已构建）")
    ap.add_argument("--port", type=int, default=8097)
    ap.add_argument("--host", default="127.0.0.1")
    args = ap.parse_args()

    repo = pathlib.Path(args.repo).expanduser().resolve()
    build = repo / "build"

    if not (repo / "backend" / "app" / "main.py").is_file():
        sys.exit(f"找不到 Mock 后端：{repo}/backend/app/main.py")
    if not (build / "index.html").is_file():
        sys.exit(
            f"找不到构建产物：{build}/index.html\n"
            f"请先构建：cd {repo} && CI=false npx --no-install react-scripts build"
        )

    sys.path.insert(0, str(repo / "backend"))

    import uvicorn
    from fastapi.responses import FileResponse, HTMLResponse
    from fastapi.staticfiles import StaticFiles

    from app.dependencies import require_auth
    from app.main import app

    app.dependency_overrides[require_auth] = lambda: "preview"

    static_dir = build / "static"
    if static_dir.is_dir():
        app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

    @app.get("/enter")
    def enter() -> HTMLResponse:
        return HTMLResponse(ENTER_HTML)

    @app.get("/{full_path:path}")
    def spa_fallback(full_path: str):
        candidate = build / full_path
        if full_path and candidate.is_file():
            return FileResponse(str(candidate))
        return FileResponse(str(build / "index.html"))

    print(f"仓库：{repo}")
    print(f"打开：http://{args.host}:{args.port}/enter")
    uvicorn.run(app, host=args.host, port=args.port, log_level="warning")


if __name__ == "__main__":
    main()