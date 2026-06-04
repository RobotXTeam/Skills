---
name: pdply
description: "Write concise Seeed Studio product detail pages (商详) from local PRD/datasheet/reference data and generate a structured DOCX. Use when asked to create, draft, refine, or export a product listing/detail page using PDPly reference data, 商详标准, 标品文档, 配件或套件文档, or /home/steven/agent/PDPly/参考数据."
metadata:
  short-description: "Generate concise product-detail DOCX files"
---

# PDPly Product Detail Writer

Use this skill to write a Seeed Studio-style product detail page (商详) from local reference data and export it as a `.docx`.

## Required workflow

1. Read `references/商详写作知识库.md` before drafting. It contains the product grading rules, module rules, templates, and quality checklist.
2. Read every relevant file in the user-provided reference data directory. For `.docx`, use `python-docx` or an equivalent parser to extract paragraphs and tables.
3. Extract embedded images from reference `.docx` files before drafting. Build a small contact sheet or inspect thumbnails. For each candidate image, decide its commercial purpose and target section; do not ignore images just because they are embedded in Word.
4. Determine product grade:
   - A: strategic standard product, platform product, high-value dev kit, robotics/edge AI/system bundle.
   - B: normal standard product, functional module, dedicated hardware.
   - C: low-importance accessory, cable, small replacement part.
5. Draft the商详 in English body text with Chinese/English section headings.
6. Do not fabricate SKU, parameters, certifications, compatibility, public links, images, inventory, price, or claims. Use placeholders such as `[待补：公开 Datasheet 链接]`.
7. Keep the copy concise and human-written: useful facts, concrete values, no datasheet dumping, no generic marketing.
8. Export a `.docx` using `scripts/create_pdply_docx.py`. Also create a short missing-info Markdown file when useful.

## Image rules

Images are part of the sales argument, not decoration. Every inserted image must answer why it appears there.

- Do not force images into the DOCX. If the reference data does not contain the right image, write a clear placeholder and add the image to the missing-info list.
- Never use an image merely because it exists in the reference file. Insert it only when it is valuable, readable, customer-facing, and directly supports the section.
- Do not substitute a similar-looking or unrelated image for a missing product image. If the official hero/product/part-list image is missing, write `[待补：正式商品图]`.
- Product image / render: place in `产品图片【Images And Videos】` or early `Features` to establish what the product is.
- Exploded view, board stack, enclosure, interface layout, pinout, dimension, mounting: place in `Hardware overview`.
- Web UI, model conversion, SenseCraft, API or dashboard screenshots: place near Features or Application only if they explain development workflow.
- Scenario images or application dashboards: place in `Application`.
- Tables captured as screenshots should usually be converted to real Word tables unless the screenshot is a UI or visual comparison.
- Competitor screenshots, market research images, internal PRD notes, and low-readability screenshots should not be inserted into the customer-facing doc unless explicitly writing a comparison section.
- Prefer 4-8 meaningful images for A-grade products, 1-4 for B-grade products, and 0-2 for C-grade accessories.
- Add a short caption or lead-in sentence for each image so the reviewer knows its purpose.

## Output structure

Default sections:

- 产品图片【Images And Videos】
- 产品名称【Product Name】
- 产品简述【Short description】
- 关联SKU【Related attribute skus】
- 商品详情【Content】
  - 5.1 产品特点【Features】
  - 5.2 产品规格【Specification】
  - 5.3 产品硬件图【Hardware overview】
  - 5.4 产品应用【Application】
  - 5.5 产品文档【Document】
- Attribute
- 产品零件列表【Part List】
- 产品wiki/blog【Learn】
- 猜你喜欢【You May Like This】
- 关联产品推荐【Also add】
- SEO【Search Engine Optimization】
- 产品特殊通知【Product notes】
- 产品广告位/活动【Product Events】
- 产品 Bundle 页面【Product bundle】
- 产品 Selection 页面【Product selection】

For C-grade products, keep required backend sections but leave non-applicable content blank or with clear placeholders.

## DOCX script

Prepare a JSON file and run:

```bash
python3 scripts/create_pdply_docx.py input.json output.docx
```

The JSON schema is simple:

```json
{
  "title": "Product 商详",
  "sections": [
    {"level": 2, "title": "产品名称【Product Name】", "paragraphs": ["..."]},
    {"level": 3, "title": "5.1 产品特点【Features】", "bullets": [{"label": "Feature", "text": "..."}]},
    {"level": 3, "title": "5.2 产品规格【Specification】", "tables": [{"headers": ["Specification", "Details"], "rows": [["Main SoC", "RV1126B"]]}]},
    {"level": 3, "title": "5.3 产品硬件图【Hardware overview】", "images": [{"path": "images/hardware.png", "caption": "Board stack and interface overview.", "width_inches": 5.8}]}
  ]
}
```

Supported section keys: `paragraphs`, `bullets`, `numbered`, `tables`, `images`, and nested `sections`. Image paths are resolved relative to the JSON file first, then relative to the current working directory.

For this PDPly workspace, generated DOCX should default to the format of:

```text
/home/steven/agent/PDPly/配件或套件文档/MeshCore虚拟套件上架商祥.docx
```

Use ordinary numbered paragraphs instead of Word Heading styles, blue section numbers, bold section titles, Arial font, compact paragraph spacing, 5.75-inch image width, and simple Word tables.
