---
name: RiceEyse
description: Use this skill for Steven's RiceEye vision project, rice seedling YOLO datasets, Meta-GPAF graduation thesis defense Q&A, and related files under /home/steven/work/vision or /mnt/debian/home/steven/work/vision. Trigger when the user mentions RiceEye, Meta-GPAF, GPAF, rice seedling detection, rice missing-seedling detection, YOLO dataset conversion/merge, 毕设, 毕业论文, 答辩, 水稻数据集, or the misspelled project skill name RiceEyse.
metadata:
  short-description: RiceEye project, datasets, and thesis context
---

# RiceEyse

## Core Context

This skill records the current RiceEye project context from the May 2026 sessions.

Primary workspace aliases may both point to the same tree:

- `/home/steven/桌面/work/vision/RiceEye`
- `/mnt/debian/home/steven/work/vision/RiceEye`
- `/home/steven/桌面/work/vision/bk/水稻数据集`
- `/mnt/debian/home/steven/work/vision/bk/水稻数据集`

When paths differ only by `/home/steven/桌面/work` vs `/mnt/debian/home/steven/work`, verify the real path with `readlink -f`, `ls`, or `test -e` before acting.

## When Working Here

- The user prefers direct execution. Inspect files and produce concrete artifacts rather than giving only instructions.
- Do not overwrite original datasets. Create new output folders for conversions, previews, and merges.
- For dataset work, always verify image/label pairing, class ids, file counts, and a few visual samples before declaring success.
- For thesis/defense work, answer in practical Chinese that the user can directly paste into a document or rehearse in defense.

## Project Facts To Reuse

- The thesis/project method is Meta-GPAF for rice missing-seedling detection.
- Current Meta-GPAF is not a support-image/few-shot workflow where the UAV first takes several photos before normal operation.
- Deployment logic: YOLO detects seedlings in each image, 29 visual meta-features are extracted from that same image, a trained random forest proxy predicts `gap_ratio` and `bin_width`, then GPAF performs row clustering, global spacing prior estimation, local fusion, and missing-seedling counting.
- The GPAF "global prior" means an image-level seedling spacing baseline estimated from valid spacing inside the current image, not a separate field-level prior collected before flight.
- For defense, contrast fixed-parameter GPAF with Meta-GPAF as: fixed parameters are manually chosen and reused; Meta-GPAF predicts image-adaptive backend parameters.
- Dataset defense answer: the method learns low-dimensional structured meta-features to two backend parameters, not raw pixels to missing counts, so 201 evaluation images can support a graduation-design feasibility validation with a random forest proxy, while broader engineering deployment still needs more cross-field/cross-height/cross-light data.

## Known Dataset Outcomes

- COCO file `instances_train2017.json` under `bk/水稻数据集` was verified to match 1510 `train/*.tif` images, but its category is `plot`, with large plot/region boxes. It is not the user's desired rice seedling small-object label source.
- Converted COCO YOLO labels were generated once under `labels/train`, with previews under `yolo_preview`, but the user judged them wrong because the source annotation target was wrong.
- Manual labels under `bk/水稻数据集/lab_1/dataset/labels` are the trusted approximate rice seedling labels. These are YOLO-style small-object labels, class `rice`.
- A merged retraining dataset was created at:
  `/mnt/debian/home/steven/work/vision/bk/水稻数据集/lab_1/rice_merged_yolo_20260503`
- That merged dataset uses YOLO structure with `data.yaml`, `images/train|val|test`, and `labels/train|val|test`.
- Merged split at creation time: total 594 images/labels; train 475, val 59, test 60; sources were 393 `lab1` images and 201 `riceeye` images; class id `0`, class name `rice`.

## Current Thesis Artifact State

Continue thesis work from this current main document unless the user names another file:

- `/home/steven/桌面/work/vision/RiceEye/docs/张强毕设（终稿）-2026年.docx`

The following older integrated document is historical context only. Do not use it as the default target:

- `/home/steven/桌面/work/vision/RiceEye/docs/毕设-摘要第三章第六章数据更新整合版-空白修正版-图5修正版.docx`

If the user says “论文”, “毕设”, “格式”, “图表”, “三线表”, or “学校规范” without naming another file, operate on `张强毕设（终稿）-2026年.docx`.

Important intermediate files:

- `毕设-摘要第三章第六章数据更新整合版.docx` had severe blank-page issues.
- `毕设-摘要第三章第六章数据更新整合版-空白修正版.docx` fixed forced page breaks.
- `毕设-摘要第三章第六章数据更新整合版-空白修正版-图5修正版.docx` also replaces Fig. 5-2 and Fig. 5-3 with clean high-resolution versions.

Key local scripts in `/home/steven/桌面/work/vision`:

- `rewrite_chapter4_docx.py` and `rewrite_chapter5_docx.py`: chapter-specific formula/figure versions.
- `fix_thesis_alignment.py`: fixes body/formula/picture/caption alignment.
- `build_integrated_thesis_update.py`: rebuilds the integrated abstract + Ch.3 + Ch.6 document.
- `fix_ch5_figures.py`: redraws and replaces Ch.5 Fig. 5-2 and Fig. 5-3.

When changing thesis `.docx`, use `python-docx`, create a copy, export to PDF with LibreOffice, and inspect the PDF. Do not trust XML checks alone.

## Thesis Framing

The current writing direction is grounded and should not over-abstract `Meta-GPAF`.

- Ch.3: `基于YOLO26的水稻秧苗前端目标感知`.
- Ch.4: `后端先验决策的基础方法`.
- Ch.5 preferred title: `基于环境元特征的判定参数自适应优化`.
- Ch.6: `系统综合实验与结果分析`.

Use these conceptual boundaries:

- YOLO26 is the front-end perception module. It detects existing seedlings and converts rice-field images into a clean 2D center-point set. It does not directly detect missing seedlings.
- Ch.4 is the fixed-parameter geometry baseline. `bin_width` and `gap_ratio` are manually preset static hyperparameters.
- Ch.5 solves Ch.4 parameter mismatch by predicting dynamic `bin_width` and `gap_ratio` from current-image environment meta-features.
- In this thesis, `Meta` means scene/meta-feature driven parameter prediction, not support/query few-shot learning.
- Prefer terms like `环境元特征`, `参数自适应`, `静态参数 vs 动态参数`, and `场景-参数映射`.

## Current Dataset and Experiment Numbers

Latest training data roots:

- `/home/steven/桌面/work/vision/训练和推理/train`
- `/home/steven/桌面/work/vision/训练和推理/train2`

Verified training-set stats:

- `train`: 201 images, 202 label files, 201 paired images, 5089 boxes, class id `0`.
- `train2`: 393 images, 393 label files, 393 paired images, 35586 boxes, class id `0`.
- Combined: 594 images, 595 label files, 594 paired images, 40675 boxes.

Comprehensive experiment/visualization image roots:

- `/home/steven/桌面/work/vision/bk/水稻数据集/train_jpg`: 1510 images.
- `/home/steven/桌面/work/vision/训练和推理/train/images`: 201 images.
- Combined candidate image pool: 1711 images.

Height folders exist but may not contain directly usable image files in the local scan:

- `/home/steven/桌面/work/vision/不同高度数据/2m`
- `/home/steven/桌面/work/vision/不同高度数据/3m`
- `/home/steven/桌面/work/vision/不同高度数据/5m`
- `/home/steven/桌面/work/vision/不同高度数据/7m`

The user said 7m can be ignored if it looks bad.

Quantitative missing-seedling comparison still uses the labeled subset:

- `meta_gpaf_output/evaluation/per_image_comparison.csv`
- `meta_gpaf_output/dataset/meta_dataset.csv`
- 201 manually labeled images, reference missing-seedling total 1043.

Use these current experiment values:

- Overall base MAE about 0.706; Meta-GPAF MAE about 0.682.
- Overall base count accuracy about 86.39%; Meta-GPAF about 86.86%.
- Complex proxy union: n=116, base MAE about 0.974, Meta MAE about 0.776, base accuracy about 82.77%, Meta accuracy about 86.28%.
- Small-scale proxy subset: n=61, base accuracy about 80.63%, Meta accuracy about 85.00%.
- Spatial-discrete proxy subset: n=97, base accuracy about 82.21%, Meta accuracy about 86.30%.
- Obvious-improvement subset: n=52, base MAE about 1.654, Meta MAE about 0.135, base accuracy about 75.22%, Meta accuracy about 97.98%.

Do not claim real high-wind/high-altitude labels unless such labels are added. Phrase these as proxy subsets based on scale and spatial dispersion.

## Seeed Remote Training Environment

Remote access:

```bash
ssh -p 10022 seeed@127.0.0.1
# password: 0
```

Main remote roots:

- `/home/seeed/.steven`
- `/home/seeed/.steven/vision`
- `/home/seeed/.steven/vision/RobotDetection-RiceEye`

Important remote outputs:

- `/home/seeed/.steven/vision/retrain_results/yolo26m_retrain/results.csv`
- `/home/seeed/.steven/vision/retrain_results/yolo26m_retrain/results.png`
- `/home/seeed/.steven/vision/retrain_results/yolo26m_retrain/BoxPR_curve.png`
- `/home/seeed/.steven/vision/retrain_results/yolo26m_retrain/weights/best.pt`

Verified `yolo26m_retrain` results:

- Best epoch: 450.
- Precision: 0.99813, i.e. 99.81%.
- Recall: 0.99016, i.e. 99.02%.
- mAP50: 0.99498, i.e. 99.50%.
- mAP50-95: 0.97858, i.e. 97.86%.

Verified inference speed:

- `/home/seeed/.steven/vision/logs/yolo26m_inference.log`: yolo26m, 28868 detections, about 21.9 FPS.
- `/home/seeed/.steven/vision/logs/inference_correct.log`: 1510-image report; yolo26n about 24.0 FPS, yolo26m about 21.6 FPS, yolo26x about 15.3 FPS.

These real numbers are already written into the current final integrated Word file.

## Chapter-Specific Notes

### Chapter 3

Keep the structure:

- 3.1 task definition and dataset construction.
- 3.1.4 must use the latest 594-image / 40675-box training data, not the old 201-image wording.
- 3.4 should include YOLO26m real metrics: Precision 99.81%, Recall 99.02%, mAP50 99.50%, mAP50-95 97.86%.

Core formulas:

- `B_i = (x_i^1, y_i^1, x_i^2, y_i^2, c_i)`
- `p_i = ((x_i^1 + x_i^2)/2, (y_i^1 + y_i^2)/2)`
- `P = {p_i | i = 1, 2, ..., n}`
- `D = f_YOLO(I; Θ)`
- `L = λ_box L_box + λ_cls L_cls + λ_dfl L_dfl`
- `Precision = TP / (TP + FP)`
- `Recall = TP / (TP + FN)`
- `F1 = 2 × Precision × Recall / (Precision + Recall)`
- `P_hat = P - P_miss + P_false + ε`

Current Ch.3 images include:

- `ch3_task_flow_clean.png`
- `ch3_single_box_annotation_clean.png`
- `ch3_dataset_scale.png`
- `ch3_training_flow_clean.png`
- `ch3_yolo26m_results.png`
- `ch3_yolo26m_pr_curve.png`

### Chapter 4

Ch.4 is the static-parameter baseline:

- Horizontal clustering uses fixed `bin_width`.
- Missing-seedling decision uses fixed `gap_ratio`.
- Global prior and local spacing fusion are allowed, but this is still not scene-level parameter adaptation.
- Ch.4 should end by exposing fixed-parameter mismatch under flight-height changes, wind deformation, or irregular row structure.

Existing Ch.4 images:

- `ch4_row_cluster.png`
- `ch4_spacing_fusion.png`
- `ch4_static_flow.png`
- `ch4_param_mismatch.png`

### Chapter 5

Use environment meta-features to predict parameters:

- Global scale features for flight-height/scale variation: detection-box mean/median area, width/height, density, image size.
- Spatial dispersion features for wind/row deformation: center-point variance/range, row count, plants-per-row variance, row span, spacing fluctuation.
- Random forest is preferred because it is interpretable, stable on small samples, fast online, and less prone to overfitting than MLP.

Core formulas:

- `θ* = argmin_θ |RS(I; θ) - y|`
- `θ = (gap_ratio, bin_width) = g(z)`
- `A_mean = (1/n) Σ_i A_i`
- `A_med = median({A_i})`
- `σ_x = sqrt((1/n)Σ_i(x_i - x_mean)^2), R_x = max(x_i) - min(x_i)`
- `σ_y = sqrt((1/n)Σ_i(y_i - y_mean)^2), R_y = max(y_i) - min(y_i)`
- `z = [z_s, z_d]`
- `(gap_ratio_hat, bin_width_hat) = g_RF(z)`
- `M = BaseDecision(P, gap_ratio_hat, bin_width_hat)`

Fig. 5-2 and Fig. 5-3 were fixed because the user did not want bottom explanation boxes inside images. Use the high-resolution clean versions:

- `ch5_feature_groups_clean_hd.png`: 3400x1900.
- `ch5_model_compare_clean_hd.png`: 3400x1850.

### Chapter 6

Use the user-requested structure:

- 6.1 experiment platform and metrics.
- 6.2 front-end perception verification.
- 6.3 core comparison of backend decision methods.
- 6.4 end-to-end accuracy and speed.
- 6.5 summary.

Key formulas:

- `MAE = (1/N) Σ_i |y_hat_i - y_i|`
- `Acc_count = 1 - Σ_i |y_hat_i - y_i| / Σ_i y_i`
- `Exact = (1/N) Σ_i 1(y_hat_i = y_i)`

Use real speed metrics:

- yolo26m about 21.9 FPS.
- yolo26n about 24.0 FPS.

## Abstract Writing Pattern

The abstract should stay in five paragraphs:

1. Background and pain point: rice missing-seedling importance, UAV visual inspection, perspective distortion, flight-height fluctuation, wind deformation, fixed-threshold failure.
2. Front-end perception: YOLO26 converts complex rice-field images into clean 2D center-point coordinates.
3. Back-end prior decision: row topology, global prior, local trend, sample-count weighted fusion; end by noting static-threshold limitations.
4. Meta adaptive optimization: global scale features plus spatial dispersion features, lightweight model predicts `bin_width` and `gap_ratio`, scene-parameter mapping.
5. Experiments: include real numbers, especially 594 training images, 40675 boxes, 1711 candidate images, 86.86% overall Meta count accuracy, 86.28% complex-proxy accuracy, and 97.98% obvious-improvement subset accuracy.

Current Chinese keywords:

- `水稻缺苗检测；YOLO26；全局先验；环境元特征；参数自适应`

Current English keywords:

- `rice seedling missing detection; YOLO26; global prior; environmental meta-features; parameter adaptation`

## Word Figure and Layout Rules

The user is sensitive to Word layout. Before finalizing any thesis document:

- Export with LibreOffice to PDF.
- Check that body text is left-aligned, formulas centered, pictures centered, figure/table captions centered.
- Clear `page_break_before`, `keep_with_next`, and `keep_together` on generated normal paragraphs.
- Avoid picture paragraphs inheriting fixed line spacing that clips images.
- Do not put extra explanation boxes inside figures below the visual content; Word figure captions are enough.
- Prefer high-resolution generated PNGs around 3000px wide when replacing figures.

## May 7 Thesis Formatting State

When the user asks about the latest thesis formatting/figure state, use these current facts first.

- The active file the user asked to edit directly is `/home/steven/桌面/work/vision/RiceEye/docs/张强毕设（终稿）-2026年.docx`; do not switch back to `毕设5-6.docx` unless the user names it.
- Important backups now exist:
  - `毕设.docx.bak_before_fig_title_cleanup`
  - `毕设.docx.bak_before_restore_original_style_6figs`
  - `毕设.docx.bak_before_three_line_tables`
- Detailed May 7 context is also recorded at `/home/steven/桌面/work/vision/RiceEye/docs/RiceEyse_skill_补充_2026-05-07.md`.

### Current Figure Asset Workflow

- Editable figure assets live in `/home/steven/桌面/work/vision/RiceEye/docs/figures_editable`, with one folder per figure such as `图3-2`, `图4-3`, `图5-5`.
- Typical files are `preview.png`, `editable.pptx`, `editable.svg`, and `README.txt`.
- The user prefers Word captions below figures, so image content should not include duplicate top titles.
- The user dislikes bottom explanation boxes/small notes inside figures when those notes repeat the caption or prose.
- If the user says to keep the original `毕设.docx` appearance, do not redraw in a new style. Start from the original embedded PNG and only erase title/note regions.
- The cleaned original-style images for `图3-2`, `图3-3`, `图4-1`, `图4-2`, `图4-3`, and `图4-6` are under `/home/steven/桌面/work/vision/RiceEye/docs/images/doc_original_cleaned`.
- `图3-3` was adjusted so `train`, `train2`, and `综合实验图像` are centered under the three bars.
- Special case: do not proactively convert `图4-3/editable.pptx` into editable shapes. The user said “图4-3不用改”. It was restored to image-based PPT after a shape-version attempt; expected check is `pictures=1`, `text_runs=0`.

### Tables and School Format

- `毕设.docx` currently has 7 tables and they were converted to three-line tables: top thick line, header bottom thin line, bottom thick line, no vertical/internal grid lines.
- Three-line-table backup is `毕设.docx.bak_before_three_line_tables`.
- The school format files used for checking are:
  - `/home/steven/文档/xwechat_files/wxid_fq4qu3rctwv522_f300/msg/file/2026-05/（2026届版本）2.广东石油化工学院本科毕业论文（设计）的基本构成及其表述（修改关键词个数、间隔符）.doc`
  - `/home/steven/文档/xwechat_files/wxid_fq4qu3rctwv522_f300/msg/file/2026-05/（2026届版本）3.广东石油化工学院本科生毕业论文（设计）格式规范.doc`
- Key school requirements found there:
  - A4, margins top 2.8 cm, bottom 2.2 cm, left 2.8 cm, right 2.2 cm.
  - Fixed line spacing 20 pt.
  - Chinese/English abstracts each occupy one page.
  - Front matter page numbers use uppercase Roman numerals; body starts Arabic numbering at Chapter 1.
  - Chapter titles use Arabic chapter numbers, three-level title font rules: first-level 三号粗黑体 centered; second-level 小三黑体 left; third-level 四号黑体 left.
  - Body text 小四号宋体.
  - Figure captions and figure text 五号宋体.
  - Tables are generally three-line tables, with table titles above tables and figure titles below figures.
  - References at least 15 items, including at least 2 foreign-language references.
  - Keywords must be 3-5, separated by Chinese semicolons, final keyword has no trailing semicolon.
- Current format audit conclusions:
  - Margins conform.
  - References count is enough, around 20.
  - Figure captions are below figures and table captions above tables.
  - Issues still worth fixing if requested: missing/undetected TOC, Chinese abstract too long and multi-paragraph, English abstract too long, keyword says `YOLO26` while body says `YOLO26n`, chapter labels mix `第1章` with `第二章/第三章`, header does not match odd/even school rule, page numbering needs manual Word/WPS confirmation.

### Chapter 5.3.3 Table Note

For the Meta training-data table in Section 5.3.3, the user explicitly said to write the training sample scale as `594` despite older training reports mentioning `201`. Use the thesis narrative value `594 个图像级样本` unless the user changes this decision.

## Reference

For detailed recovered conversation context, exact Q&A wording, file paths, and generated artifact names, read:

- `references/context.md`
