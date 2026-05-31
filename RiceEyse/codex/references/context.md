# RiceEyse Context

## Recovered Sessions

Relevant raw Codex sessions:

- `/home/steven/.codex/sessions/2026/05/02/rollout-2026-05-02T12-04-55-019de6dc-61ed-70d1-a032-ab477a7469b1.jsonl`
  - cwd: `/mnt/debian/home/steven/work/vision/RiceEye/docs`
  - topic: graduation thesis, Meta-GPAF, deployment explanation, defense Q&A
- `/home/steven/.codex/sessions/2026/05/03/rollout-2026-05-03T12-04-18-019dec02-2c86-75c3-96da-c00881546230.jsonl`
  - cwd: `/mnt/debian/home/steven/work/vision/bk/水稻数据集`
  - topic: locate annotations, convert COCO to YOLO, visualize labels, diagnose wrong annotation source
- `/home/steven/.codex/sessions/2026/05/03/rollout-2026-05-03T12-11-09-019dec08-7061-7300-9ff9-1368c15ce4a2.jsonl`
  - cwd: `/mnt/debian/home/steven/work/vision/bk/水稻数据集/lab_1/dataset`
  - topic: merge current manual dataset with old RiceEye training dataset for retraining

## Thesis And Defense Q&A Context

The user's thesis file was:

- `/home/steven/桌面/work/vision/RiceEye/docs/毕设.docx`

The corresponding project was:

- `/home/steven/桌面/work/vision/RiceEye`

The user asked whether Meta-GPAF means the UAV should first take several photos before normal operation as global prior data.

Recovered answer:

- This is not how the current project works.
- Current Meta-GPAF is an offline-trained parameter prediction method.
- Online inference processes each image as its own task:
  1. YOLO detects rice seedlings.
  2. The system extracts 29-dimensional visual meta-features from the current image.
  3. The random forest proxy predicts `gap_ratio` and `bin_width`.
  4. GPAF uses those parameters for row clustering, spacing-prior estimation, and missing-seedling detection.
- GPAF's "global prior" is the image-level spacing baseline estimated from all valid seedling spacings in the current image.
- It is not a field-level prior from additional support images.

Useful defense wording:

> 固定参数法是“先人工选参数，再批量处理”；Meta-GPAF 是“模型已离线训练好，在线对每张图自动预测参数，再执行缺苗检测”。因此它更适合无人机巡田这种航高、光照、视角不断变化的场景。

## Engineering Deployment Answer

If asked how missing-seedling detection is deployed in practice:

1. The UAV collects rice-field images along a flight route.
2. Images are sent to an edge device or server.
3. YOLO detects individual rice seedlings and outputs boxes/center points.
4. The system extracts visual meta-features for the current image.
5. The Meta model predicts current-image `gap_ratio` and `bin_width`.
6. GPAF performs row clustering, global spacing prior estimation, local fusion, and missing-seedling judgment.
7. The system outputs total missing count, marked missing positions, and statistics for later replanting or field management.

Fixed-parameter method explanation:

- In a traditional fixed-parameter method, engineers often first collect several representative images under the current field/flight-height/lighting condition and manually choose parameters such as clustering width and missing-gap threshold.
- Then all images are processed with this fixed parameter set.
- This can fail when flight height, view angle, lighting, water reflection, or row structure changes.

Meta-GPAF explanation:

- It does not require manual pre-flight parameter tuning at deployment time.
- It predicts backend parameters per image from the image's own meta-features.

## Dataset Size And Feasibility Answer

If a teacher asks whether the offline model requires a large dataset and whether the dataset supports this work:

- Yes, Meta-GPAF needs offline data support.
- But it does not train an end-to-end deep model from raw pixels to missing-seedling count.
- It learns a low-dimensional structured mapping: 29 visual meta-features -> two backend parameters, `gap_ratio` and `bin_width`.
- This is a smaller regression task suitable for a random forest proxy in a small-sample setting.
- The project had 201 missing-seedling evaluation images with manual missing-count labels.
- For a large deep model, 201 images is small; for the current random-forest parameter prediction task, it can support graduation-design-level feasibility validation.
- State the limitation clearly: broader engineering deployment needs more data across different fields, light, flight heights, seasons, and growth stages, plus cross-scene validation.

Short defense version:

> 是的，Meta-GPAF 需要离线数据支撑。但它不是重新训练一个端到端深度网络，也不是直接从原始图像像素学习缺苗结果，而是学习 29 维结构化元特征到 `gap_ratio`、`bin_width` 两个参数的映射。因此它对数据量的要求比深度模型低。当前 201 张图像虽然规模不大，但配合随机森林代理模型和 29 维可解释特征，已经能够支撑毕业设计中对参数自适应有效性的验证。不过如果要推广到更多田块和复杂作业条件，还需要继续扩充数据集并做跨场景验证。

## What Is Trained

Explain as "two datasets, two training targets":

1. YOLO rice seedling detection dataset
   - Artificially marked rice-field images.
   - Each seedling gets a detection box.
   - Class is `rice_seedling` or `rice`, depending on dataset config.
   - YOLO learns where seedlings are.
   - YOLO does not directly determine missing seedlings.

2. Meta-GPAF parameter prediction dataset
   - Each image is one sample.
   - Run YOLO to get seedling detections.
   - Extract 29 visual meta-features, such as detection count, box area, brightness, spatial distribution, row/column structure, and average spacing.
   - Use manual missing-seedling total labels to search offline for each image's best `gap_ratio` and `bin_width`, so GPAF's result is close to manual count.
   - Train a random forest proxy on:
     `image meta-features -> best gap_ratio, best bin_width`
   - At online inference, no manual labels or offline search are needed.

Short version:

> YOLO 的数据集训练“秧苗在哪里”，Meta-GPAF 的数据集训练“这张图该用什么缺苗判定参数”。前者用目标框标注，后者用每张图的人工缺苗总数，通过离线参数搜索生成监督标签。

## Why Not End-To-End Deep Learning

The user later asked to add:

- Why not use deep learning directly?
- What is the difference?
- What is a random forest proxy model?

Answer:

- The system does use deep learning in the front-end YOLO detector.
- It does not use an end-to-end deep model for missing-seedling counting because:
  - missing-seedling judgment depends heavily on row geometry, spacing, and agronomic structure, not only appearance;
  - end-to-end counting or segmentation would require much more diverse labeled data;
  - current data volume is limited;
  - GPAF is more interpretable: row clustering, spacing baseline, and gap judgment can be explained in defense.
- Meta-GPAF combines deep detection with rule/geometric reasoning and machine-learning parameter adaptation.

Random forest proxy model:

- A random forest is an ensemble of many decision trees.
- Each tree learns simple split rules on input features.
- The forest averages/votes across trees, making it more stable than a single tree.
- In this project it is called a proxy model because it does not replace GPAF. It approximates the offline parameter-search result and predicts good GPAF parameters from current image meta-features.
- Input: 29-dimensional meta-features.
- Output: `gap_ratio` and `bin_width`.
- It is suitable here because the sample size is limited, features are structured and interpretable, and the output dimension is small.

## Generated Defense Document

A Markdown document was created at:

- `/home/steven/桌面/work/vision/RiceEye/docs/Meta-GPAF答辩问答整理.md`

It included:

- Actual deployment process for missing-seedling detection.
- Difference between fixed-parameter method and Meta-GPAF.
- Whether the Meta model is the core advantage.
- Whether data size supports the offline model.
- How the training datasets are built.
- Why not direct end-to-end deep learning, and what random forest proxy means.
- A concise rehearsal summary.

## Dataset Conversion Session

Initial user path:

- `/home/steven/桌面/work/vision/bk/水稻数据集/train`

Findings:

- Matching COCO annotation file existed:
  `/home/steven/桌面/work/vision/bk/水稻数据集/instances_train2017.json`
- `train/` image count: 1510.
- JSON image records: 1510.
- Missing images referenced by JSON: 0.
- Extra images not referenced by JSON: 0.
- Format: COCO instance format with `bbox` and `segmentation`.
- Category: `plot`.
- Also present: `instances_val2017.json` and `instances_test2017.json`.

YOLO conversion performed:

- Generated `labels/train/`.
- Each image got one same-name `.txt`.
- Example mapping: `train/000000746.tif` -> `labels/train/000000746.txt`.
- Generated `classes.txt`.
- Generated `rice_yolo.yaml`.
- Generated `images/train` symlink pointing to original `train`.
- Counts at that time:
  - train: 1510 label files, 8278 boxes.
  - val: 648 label files, 3522 boxes.
  - test: 2194 label files, 12198 boxes.
  - class `0 plot`.

Visualization:

- Output directory:
  `/home/steven/桌面/work/vision/bk/水稻数据集/yolo_preview/`
- Example files:
  - `000000300_yolo.jpg`
  - `000000315_yolo.jpg`
  - `000000503_yolo.jpg`
  - `000000605_yolo.jpg`
  - `000000792_yolo.jpg`
  - `000001392_yolo.jpg`
  - `000001479_yolo.jpg`
  - `000001778_yolo.jpg`

User reported labels were wrong and pointed to trusted manual labels:

- `/home/steven/桌面/work/vision/bk/水稻数据集/lab_1/dataset/labels`

Diagnosis:

- The conversion formula was not the problem.
- The COCO source labels represented `plot` large region boxes, not the rice seedling small objects needed for training.
- Manual labels are YOLO-style, class `rice`, small target boxes.
- Manual labels average about 90 boxes per image.
- COCO-converted labels average about 6 boxes per image.

Comparison images:

- Output directory:
  `/home/steven/桌面/work/vision/bk/水稻数据集/yolo_compare_manual/`
- Green boxes: manual labels.
- Red boxes: COCO-converted labels.
- Example files:
  - `000001114_compare.jpg`
  - `000001122_compare.jpg`
  - `000001128_compare.jpg`
  - `000001153_compare.jpg`
  - `000000062_compare.jpg`

Conclusion:

- For rice seedling small-object training, use `lab_1/dataset/labels` or find the original full rice small-object annotation file.
- Do not use `instances_train2017.json` as rice seedling labels unless the target is plot/region detection.

## Dataset Merge Session

User wanted to merge:

- Current manual dataset under:
  `/home/steven/桌面/work/vision/bk/水稻数据集/lab_1/dataset`
- Old RiceEye training data:
  `/home/steven/桌面/work/vision/RiceEye/Inference/train`

Findings:

- Both were YOLO-style `images/` + `labels/`.
- Current dataset: 393 images and 393 labels.
- Old RiceEye dataset: 201 images but 202 labels.
- The extra old label was `labels/classes.txt`, not a YOLO annotation file.
- One label first column was `rice` rather than a numeric class; the merge logic normalized/ignored non-annotation metadata so final labels used class `0`.

Merge policy:

- Original datasets were not modified.
- New dataset created with YOLOv8-style structure:
  `images/train|val|test` and `labels/train|val|test`.
- Fixed random seed.
- Approximate split: 80/10/10.
- Source prefixes were added to avoid filename collisions.

Output:

- `/mnt/debian/home/steven/work/vision/bk/水稻数据集/lab_1/rice_merged_yolo_20260503`

Structure:

- `data.yaml`
- `images/train`
- `images/val`
- `images/test`
- `labels/train`
- `labels/val`
- `labels/test`
- `split_report.txt`

Counts:

- Total: 594 images / 594 labels.
- train: 475.
- val: 59.
- test: 60.
- Source distribution:
  - lab1: 393.
  - riceeye: 201.
- Class id: `0`.
- Class name: `rice`.

Training config:

- `/mnt/debian/home/steven/work/vision/bk/水稻数据集/lab_1/rice_merged_yolo_20260503/data.yaml`

Before future training, quickly verify current state because the user may have edited files after this context was recorded.
