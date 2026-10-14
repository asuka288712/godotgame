# 渔村森林与地面植被

渔村的 `scenes/main.tscn` 在 `World/VillageVegetation` 实例化 `scenes/village_vegetation.tscn`。森林位于东南侧（X=9–29、Z=6–29），林道从村道 `(12, 0)` 延伸到 `(25, 27)`，沿途可步行。所有树木、路径和植物均为可在编辑器内调整的原生节点。

- 森林：36 棵树，4 种外观；树干有碰撞，挡住角色的树冠会平滑淡化。
- 地面：213 处草丛、蕨类、灌木、野花、芦苇、苔石装饰；低矮植物不阻挡移动。
- 十里坡入口：`StoryManager._install_bridge` 的 `temple` 点位于林道尽头，按 E 进入；下山返回 `town` 的 `Spawns/forest_return`（24, 0.1, 23），避开出口。
- 集市原有直达十里坡的入口已移除。

素材通过 codex-image2-5 技能的原生 CLI，使用 `gpt-image-2`、请求 `1K`、质量 `auto` 生成。两张原始图实际均为 1254×1254。完整提示词保存在 `output/imagegen/village_forest/jobs.jsonl`，原图保存在同目录。

使用带 Pillow 的 Python 运行 `tools/build_village_forest.py`，可从原图重新提取透明素材，并生成独立植被场景。地面小素材及树木 PNG 位于 `assets/generated/village_forest/`；林道复用已有碎石纹理。

验证脚本：`output/imagegen/village_forest/verify_forest.gd`。检查场景实例、林道全段碰撞、树干碰撞、十里坡往返及返回落点。
