---
name: RiceEye
description: Use this skill when working on the RiceEye project, Meta-GPAF thesis, rice seedling missing detection, or defense preparation. Triggers on: RiceEye, 水稻, 缺苗, Meta-GPAF, 毕设, 答辩, 论文, YOLO seedling detection, GPAF algorithm, 随机森林代理模型.
---

# RiceEye Skill

This skill covers the Meta-GPAF rice seedling missing detection project — thesis writing, algorithm understanding, defense Q&A, and codebase navigation.

## Project overview

- **Project**: RobotDetection-RiceEye — 水稻缺苗检测系统
- **Thesis title**: 基于视觉元特征驱动的全局先验自适应水稻缺苗检测方法研究
- **English name**: Meta-GPAF: A Context-Aware Hyperparameter Adaptation Framework for Rice Seedling Detection via Visual Meta-Learning
- **Location**: `/home/steven/桌面/work/vision/RiceEye/` and `/mnt/debian/home/steven/work/vision/RiceEye/`
- **Docs**: `docs/张强毕设（终稿）-2026年.docx` (thesis, latest), `docs/答辩QA准备.md`, `docs/Meta-GPAF答辩问答整理.md`

## Core methodology (Meta-GPAF)

The system detects missing rice seedlings in paddy field images using a hybrid architecture:

```
Image → YOLO (detect seedlings, output center points)
     → Extract 29-dim visual meta-features
     → Random Forest predicts (gap_ratio, bin_width) per image
     → GPAF uses predicted params for row clustering + spacing estimation + gap judgment
     → Output: missing count + location annotations
```

### Four generations of algorithms

| Gen | Name | Key Idea | Result |
|-----|------|----------|--------|
| 1st | Base | Fixed threshold clustering | RS=963, needs manual tuning |
| 2nd | Dual | Dual regression adaptive | RS=559, misses gaps with few samples |
| 3rd | GPAF | Global prior + adaptive fusion | RS=941, close to Base with adaptivity |
| 4th | Meta-GPAF | Meta-features → predicted params | RS=1058, image-level adaptive |

### Key parameters predicted

- **gap_ratio** (1.05~2.0): Multiplier on global spacing to decide "how large a gap counts as missing"
- **bin_width** (20~60): Horizontal clustering width for row assignment

### 29-dim meta-features

Detection stats (det_count, det_density, det_mean_area, etc.), spatial distribution (spatial_x_mean/std/range, etc.), image stats (img_mean_gray, img_mean_h/s/v), row structure (row_count, row_mean_plants, row_mean_spacing), boundary features (boundary_top/bottom_mean).

## Key data points for defense

| Metric | Value |
|--------|-------|
| Dataset size | 201 images |
| Ground truth total missing | 1043 seedlings |
| Meta-features | 29 dims (hand-crafted) |
| Parameter search space | 20 × 9 = 180 combos |
| Offline search alignment rate | 85.6% (172/201) |
| Surrogate model | Random Forest (RF) |
| gap_ratio validation R² | 0.985 |
| bin_width validation R² | 0.970 |
| Average validation R² | 0.978 |
| After iterative feedback | 95.1% alignment |
| Fixed param total error | -80 (underestimation) |
| Meta-GPAF total error | +15 (close to GT 1043) |
| Fixed param exact match | 54.7% |
| Meta-GPAF exact match | 58.2% |
| Meta-GPAF MAE | 0.68 |

## Defense Q&A strategy

Two reference documents in `docs/`:

1. **`答辩QA准备.md`** (detailed, ~390 lines): 7 core questions with full reasoning, follow-up Q&A, data cheat sheet, and "golden sentences" for recitation.
2. **`Meta-GPAF答辩问答整理.md`** (concise, ~130 lines): 6 questions, shorter answers suitable for memorization.

### Core defense narrative (three lines to memorize)

> "传统固定参数法是**人替参数适应环境**，需要飞行前试拍标定；Meta-GPAF 是**参数自己适应环境**，模型已经从历史数据中学到了场景与最优参数的映射关系。"

> "我们的系统不是不用深度学习，而是**检测用深度学习，决策用传统 ML**。检测层是感知问题，用 YOLO 识别秧苗位置；决策层是几何推理问题，用 GPAF+RF 判定缺苗。"

> "训练数据构造方式是**'人工标总数，算法搜参数'**——用低成本的总数标注驱动高成本的参数搜索。"

### Key defense talking points

- **Why not end-to-end deep learning**: Annotation cost (need per-gap bboxes vs just total count), data volume (10k+ vs 201 sufficient), interpretability (black-box vs traceable decisions), deployment (hundreds MB vs hundreds KB).
- **Why 201 images is enough**: Learning 29→2 mapping, not pixels→results. RF is small-sample robust. GBDT overfits, MLP underperforms — RF chosen with evidence.
- **Deployment flow**: Offline (lab): grid search 180 combos per image → train RF. Online (field): single image → YOLO → 29 features → RF predicts params (<1ms) → GPAF counts gaps. No pre-flight calibration needed.
- **"Global prior" meaning**: Within-image statistic (median spacing across all rows), NOT multi-image prior. "Global" is relative to "local" (single-row regression).
- **Acknowledged limitations**: 14.4% images can't achieve zero-error even with optimal params (detector limitations), bin_width harder to predict than gap_ratio, need more cross-field/season/altitude data for production deployment.

## Project file map

### Core algorithm files
- `meta_train.py` — Train RF/GBDT/MLP, iterative feedback loop
- `meta_infer.py` / `meta_infer_optimized.py` — Online inference with Meta-GPAF
- `meta_build_dataset.py` / `meta_build_dataset_fast.py` — Grid search to build training dataset
- `meta_eval.py` — Evaluation and comparison
- `meta_finalize.py` — Final model packaging
- `meta_search_refine.py` — Parameter search refinement
- `meta_label_utils.py` — Label utilities
- `run_meta_pipeline.py` — End-to-end pipeline runner
- `row_label_check.py` / `row_label_utils.py` — Row labeling tools

### Base algorithm files
- `base_infer.py` — 1st gen: fixed threshold
- `dual_reg_infer.py` — 2nd gen: dual regression
- `gpaf_infer.py` — 3rd gen: GPAF
- `gpaf_v31_infer.py` — GPAF v3.1
- `label_infer.py` — Label-based inference
- `train_rice_seedling.py` — YOLO training script
- `tune_binary_search.py` / `tune_gpaf_params.py` — Parameter tuning

### Data
- `rice_seedling_dataset.yaml` — YOLO dataset config
- `test.xlsx` — Human-annotated ground truth (201 images, 1043 total missing)
- `meta_gpaf_output/` — Generated datasets, models, logs

### Key logs
- `META_GPAF_2026-03-24_WORKLOG.md`
- `META_GPAF_DUAL_PARAM_UPGRADE.md`
- `META_GPAF_SESSION_LOG.md`

## User preferences

- The user is a graduating student (毕设) working on this thesis
- Prefers Chinese communication for thesis/defense topics
- Thesis defense is the current priority
- The user has a remote GPU server (seeed@100.108.64.20 via Tailscale, port 10022) for YOLO training
- Local work happens on `/home/steven/桌面/work/vision/` (desktop) which maps to `/mnt/debian/home/steven/work/vision/` (mounted)

---

## 2026/05/05 对话记录：论文结构与章节内容讨论

### 论文整体结构（5章）

用户希望我参考 `/home/steven/桌面/work/vision/参考论文` 目录下的参考论文，设计一个合理的论文结构。最终确定的5章结构如下：

| 章节 | 标题 | 核心内容 |
|------|------|----------|
| 第1章 | 绪论/背景 | （未详细讨论，推测为引言） |
| 第2章 | 水稻缺苗检测总体框架与关键技术基础 | 前端目标感知、后端先验决策、全局情境自适应、系统框图 |
| 第3章 | 基于YOLO26的水稻秧苗前端目标感知 | 数据集构建、模型选择、训练策略、检测结果、误差分析 |
| 第4章 | 后端先验决策的基础方法 | 行列结构划分、株距计算、缺苗判定、静态参数局限 |
| 第5章 | 基于环境元特征的判定参数自适应优化 | 元特征提取、Meta自适应预测、闭环框架、对比分析 |

---

### 第2章结构（用户已确认）

```
2.1 水稻缺苗检测任务剖析与分层解决思路
    讲三点：前端目标感知、后端先验决策、全局情境自适应
2.2 关键技术与理论基础
    2.2.1 前端目标感知
    2.2.2 后端先验决策
    2.2.3 全局情境自适应
2.3 系统框图
2.4 本章小结
```

**要求**：2.2 要与 2.1 严格衔接，各节之间要串联，不是各写各的。要有公式和图片。

---

### 第3章结构（用户确认后已起草）

```
3.1 任务定义与数据集构建
    3.1.1 秧苗检测任务界定与难点分析
    3.1.2 田间原始图像数据采集与预处理
    3.1.3 "单株单框"标注原则与难点样本处理
    3.1.4 实验数据集规模与训练集划分

3.2 秧苗感知网络模型选择与适应性设计
    3.2.1 YOLO 系列算法原理与选型依据
    3.2.2 YOLO26 算法网络结构与小目标适应性优势

3.3 模型训练流程与关键策略
    3.3.1 实验开发环境与超参数配置
    3.3.2 面向行列结构保持的约束性数据增强策略
    3.3.3 损失函数设计与模型训练收敛分析

3.4 前端检测结果与性能评价
    3.4.1 检测性能评价指标定义
    3.4.2 整体检测精度与多场景可视化结果分析

3.5 检测误差分析与几何推断的前置性讨论
    3.5.1 典型漏检与误检场景剖析
    3.5.2 目标检测误差对后续缺苗计数的影响界定

3.6 本章小结
```

**要求**：要有公式和图片。处理方式：复制原文件后生成新文件，不直接修改 `毕设.docx`。

---

### 第4章结构（用户详细确认）

```
第4章 后端先验决策的基础方法
（序言）先交代清楚这一章要讲什么东西，大概做个总结

4.1 离散中心点的行列结构划分
    核心是"连线"，使用固定横向聚类宽度 bin_width
    4.1.1 横向距离聚类与稻行提取
        用 bin_width 把点分成不同的列，利用固定横向距离阈值将YOLO输出的散乱中心点归拢成独立稻行
    4.1.2 纵向序列构建与单列方向拟合
        在每列内沿纵向建立点与点的拓扑顺序，拟合主方向

4.2 融合全局先验与局部的基准株距计算
    第四章的灵魂，专门负责讲"如何把间距算准"，只涉及数学公式，不涉及缺苗判定
    4.2.1 全局先验与局部趋势的特征提取
        搜集全图范围内正常间距，提取中位数作为"全局先验株距(d_g)"，用线性回归计算局部株距渐变趋势(d_l)
    4.2.2 基于样本数量的株距加权融合
        给出融合公式，通过判断当前列秧苗数量(N)分配权重：
        N < 5 时重度依赖全局先验 d_g，N >= 5 时信任局部趋势 d_l
        自适应仅限于纯数学公式上的权重分配，不涉及系统参数改变

4.3 基于静态参数的缺苗判定机制
    负责把算出来的间距投入使用，判定标准是"死"的
    4.3.1 基于纵向间距的缺苗计数逻辑
        拿到融合株距后配合 gap_ratio 算缺了几棵
    4.3.2 基础推断流程与静态参数设定
        用流程图总结第四章执行过程，明确声明 bin_width 和 gap_ratio 均为人工预设的静态超参数

4.4 基础方法的局限性与参数失配问题（引爆第五章）
    全篇"起承转合"的"转"
    4.4.1 常规场景下的判定有效性
        表扬基础方法，在无人机航高稳定、环境标准的田块里算得非常准
    4.4.2 复杂场景下的固定参数失配问题
        一旦航高变化或风吹导致环境改变，写死参数会导致误判，引出第五章
```

**要求**：要有公式和图片。各节之间要串联，4.4 要为第五章做铺垫。处理方式：复制一份再改。

---

### 第5章结构（用户详细确认）

```
第5章 基于环境元特征的判定参数自适应优化

5.1 参数失配困境与元自适应求解思路
    5.1.1 复杂环境下的参数刚性失配回顾（承上）
        简短回顾第四章结论，明确静态 gap_ratio 和 bin_width 无法应对航高波动与风吹形变，引出"参数自适应"
    5.1.2 基于元学习的"场景-参数"映射机制
        将"调参"转化为"场景到参数的映射"，抛出Meta哲学：离线学习映射，在线零成本预测，给出离线/在线架构图，详细介绍Meta概念

5.2 元特征的提取与参数映射（化繁为简，不要写29维了，简化）
    5.2.1 应对航高波动的全局尺度特征提取
        讲均值、中位数等反映大小的特征
    5.2.2 应对大风形变的空间离散特征提取
        讲方差、分布离散度等反映是否整齐的特征
    注：正文里只说"系统综合提取了包含上述物理维度的多维特征向量"，把29这个数字淡化处理

5.3 Meta自适应参数预测模型的构建与推断
    5.3.1 Meta预测网络的轻量化架构设计
        交代用什么模型做预测，为什么选随机森林（对比RF/GBDT/MLP，强调可解释、不易过拟合、边缘端推理极快）
    5.3.2 Meta端到端映射流程
        讲清楚模型如何"特征输入 - 参数输出"，吃进两大类特征，吐出最适合当前图片的 gap_ratio 和 bin_width
    5.3.3 训练数据集的构建与方法（简单写）
    5.3.4 在线推理：输入特征，输出参数，驱动第四章的决策
    5.3.5 全系统闭环框架
        画终极流程图：YOLO提点 → Meta分析全图特征并下发动态参数 → 第四章基础方法利用动态参数完成精准测算

5.4 静态基准与自适应模型的对比分析
    把"第四章的死参数"和"第五章的活参数"放在大风、高空等恶劣数据集里跑，用图表展示第五章的碾压级优势

5.5 本章小结
```

**要求**：要有公式和图片。这一章不删除第四章的内容。处理方式：复制一份再改。

---

### 论文命名讨论

用户询问 "Meta-GPAF" 这个名字是否好，GPAF四个方法论是否能站得住脚。用户表示：
- 可能论文的英文缩写不叫 Meta-GPAF 了
- 但内容几乎没有变
- 这种不用强调 GPAF 这几个缩写

---

### 关键文件路径

- 论文原文：`/home/steven/桌面/work/vision/RiceEye/docs/毕设.docx`
- 参考论文目录：`/home/steven/桌面/work/vision/参考论文`
- 输出目录：`/home/steven/桌面/work/vision/结构`
- 用户桌面路径：`/home/steven/桌面/work/vision/`（对应 `/mnt/debian/home/steven/work/vision/`）

---

### 远程服务器信息

- 地址：`seeed@127.0.0.1`（通过 Tailscale 映射）
- 端口：10022
- 密码：0
- 用途：训练 YOLO 模型

用户询问当前训练的是否是 yolo26x 模型，并要求将之前训练好的 l 模型和数据集传到指定目录。

---

### 论文写作要求总结

1. **要有公式和图片**，不要全部文字
2. **不直接修改** `毕设.docx`，而是**复制一份**再改
3. **章节之间要串联**，不是各写各的
4. **第4章结尾**要为第5章做铺垫（引出参数自适应需求）
5. **淡化29维特征**这个具体数字，着重描述物理含义
6. **简化表述**，不需要过于抽象

---

## 2026/05/07 对话记录：对话恢复与 Skill 补充

### 对话背景

用户因 Claude Code 重启，无法记忆上次（2026-05-05）对话内容，主动询问能否恢复。

### 对话恢复能力确认

我通过读取 `/home/steven/.claude/history.jsonl` 成功恢复了上次完整对话，包括：
- 论文整体5章结构
- 第2、3、4、5章的详细章节安排
- 用户确认的论文写作具体要求
- 关于 Meta-GPAF 命名的讨论
- 关键文件路径和远程服务器信息

### 用户第一次请求

> "对把上面我们的对话全部提取细节出来补充到本skill里"

用户要求将上次（2026-05-05）对话的**全部内容**补充到 RiceEye skill。我执行了：
1. 读取当前 SKILL.md
2. 在文件末尾添加了 `## 2026/05/05 对话记录` 章节
3. 完整记录了5章结构、各章节详细内容（共约180行Markdown）

### 用户第二次请求

> "这几天的都补进去"

用户意思是把**今天这次对话本身**也记录进 skill，不只是操作日志。我补充了今天这段对话的完整内容。

### 对话特点备注

- 用户使用中英文混合沟通（ thesis/defense 话题倾向中文）
- 用户桌面环境路径：`/home/steven/桌面/work/vision/` ↔ `/mnt/debian/home/steven/work/vision/`
- 对话 ID（session）：`ee049f1c-17df-4ada-afd6-b0021850958b`（2026-05-05）、`d41bdc73-8a75-40d9-b7cd-a90c3bde0597`（2026-05-07）

### Skill 更新历史

| 日期 | 操作 | 内容 |
|------|------|------|
| 2026-05-05 | 初始创建 | 论文结构讨论（5章框架、各章节详细内容） |
| 2026-05-07 | 补充更新 | 添加对话恢复记录、本次对话内容 |
