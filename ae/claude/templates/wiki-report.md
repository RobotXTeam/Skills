# Wiki QA 报告模板

```markdown
## Wiki QA Report: <title>

Source:
- Wiki file / URL:
- Tested on:

Result:
- Direct wiki run:
- Final run after fixes:
- Score:

Evidence:
- Logs:
- Video/screenshot/frame:
- Device artifacts:

Direct-run findings:
- ...

Fixes applied:
- ...

What the wiki should change:
- ...

Verdict:
- ...
```

## 评分标准

- 9-10：按原样运行。仅需轻微措辞/润色。
- 7-8：在小的明显修复后运行，如接收器 IP、端口说明或 Linux 接收器命令。
- 5-6：仅在非平凡修复后运行，如缺少 `sudo`、缺少库路径、错误模型头、未文档化资产或 headless 显示解决方案。
- 3-4：部分成功；程序启动但预期输出无法复现或证据薄弱。
- 1-2：失败/糟糕级别的可复现性；合理调试已穷尽或基本资产/硬件/凭据未文档化/不可用。
