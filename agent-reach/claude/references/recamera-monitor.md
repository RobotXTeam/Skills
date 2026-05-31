# reCamera 舆情监控

产品：Seeed Studio reCamera（RISC-V 边缘 AI 摄像头）
Owner：steven（产品负责人）

## 默认行为

当 `/agent-reach` 无参数调用时，自动执行以下流程：

### 1. 时间范围

默认拉取**最近 2 个月**的数据。用户可指定时间范围如「最近 1 个月」「4-5 月」。

### 2. 数据源

按平台分别拉取，每个平台都需要设置代理：
```bash
export https_proxy=http://127.0.0.1:7897
export http_proxy=http://127.0.0.1:7897
```

### 3. Twitter/X 拉取

```bash
# 官方推文（from seeedstudio）
twitter search "reCamera" --from seeedstudio --since YYYY-MM-01 --until YYYY-MM-DD --full-text -n 50

# 非官方推文（排除转推）
twitter search "reCamera" --since YYYY-MM-01 --until YYYY-MM-DD --exclude retweets --full-text -n 50

# 对每条官方推文，拉取回复
twitter tweet TWEET_ID
```

### 4. Reddit 拉取

```bash
# 搜索 reCamera 相关帖子
rdt search "reCamera OR recamera OR re-camera" -t year --full-text -c -n 50

# 查看 Seeed_Studio subreddit
rdt sub Seeed_Studio --limit 30 -c
```

### 5. Exa 补充搜索

当 CLI 工具网络不通时，用 Exa 兜底：
```bash
mcporter call 'exa.web_search_exa(query: "seeed reCamera site:twitter.com OR site:x.com", numResults: 10)'
mcporter call 'exa.web_search_exa(query: "seeed reCamera site:reddit.com", numResults: 10)'
mcporter call 'exa.web_search_exa(query: "seeed reCamera review discussion", numResults: 10)'
```

## 输出格式

按以下结构输出，Markdown 格式：

```
# reCamera 舆情月报（YYYY年M月-N月）

## 🐦 Twitter/X

### 一、Seeed 官方 @seeedstudio（N条）

| # | 日期 | 内容摘要 | 互动数据 |
|---|------|---------|---------|
| 1 | MM月DD日 | 推文内容要点 | ❤️X 🔄X 💬X 🔖X 👁️X |

**官方回复用户问题：**
- MM月DD日回复 @用户：「回复内容」

### 二、用户讨论（非官方）

| # | 日期 | 用户 | 内容摘要 | 互动 |
|---|------|------|---------|------|
| 1 | MM月DD日 | @username | 内容要点 | ❤️X 👁️X |

### 三、用户回复官方推文

**回复 MM月DD日「推文主题」推文：**
- @用户: 回复内容

## 📖 Reddit

### 一、reCamera 相关帖子

| # | 日期 | 标题 | subreddit | 作者 | 热度 | 评论 |
|---|------|------|-----------|------|------|------|
| 1 | YYYY-MM-DD | 标题 | r/xxx | author | X⬆ | X |

### 二、关键帖子详情

**① 帖子标题**（日期，subreddit）— N条评论
> 帖子要点摘要
> 用户评论要点

## 📊 总结

| 维度 | Twitter | Reddit |
|------|---------|--------|
| 官方发布 | N条 | N条 |
| 最热内容 | 描述 | 描述 |
| 主要反馈 | 正面/负面要点 | 正面/负面要点 |
| 社区活跃度 | 高/中/低 | 高/中/低 |
```

## 数据过滤

- **噪音过滤**：Twitter 搜索 "reCamera" 会匹配到无关内容（如西班牙语 "recámara"、日语用户名含 "Recamera"、加泰罗尼亚语等），需过滤掉非产品相关推文
- **官方识别**：Seeed Studio 官方账号 @seeedstudio（verified）
- **社区成员**：关注 @kinofumi、@norwaydsk、@gnz3_3 等活跃日本开发者
