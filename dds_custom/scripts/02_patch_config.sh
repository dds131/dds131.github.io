#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 02_patch_config.sh —— 修改 al-folio 的 _config.yml，使其指向 dds131 的 GitHub Pages
#
# 这是本项目对 al-folio 原有源码的【唯一】修改，共 3 处：
#   ① url      : https://alshedivat.github.io  ->  https://dds131.github.io
#   ② baseurl  : /al-folio                     ->  (留空，保留该行)
#   ③ exclude  : 新增一行 "  - dds_custom/"    （防止自定义目录被 Jekyll 渲染进站点）
#
# 为什么必须改 _config.yml 而不能用叠加配置文件绕开：
#   上游 .github/workflows/deploy.yml 执行的是裸的 `bundle exec jekyll build`，
#   不带 --config 参数。若改用叠加配置就必须修改 workflow 文件，
#   那比改这 3 行动静更大、更底层。故改 _config.yml 才是最小改动。
#
# 为什么 baseurl 留空：
#   仓库名 dds131.github.io 恰好等于 <用户名>.github.io，GitHub 判定为「用户主页站」，
#   站点根路径就是 /，baseurl 必须为空。若误填，全站 CSS/JS/图片会 404。
#
# 特性：幂等（重复执行安全）、自动备份原文件、执行前后打印 diff
# 用法：bash 02_patch_config.sh
# 回滚：bash 02_patch_config.sh --restore     （从 .bak 恢复）
# ---------------------------------------------------------------------------
set -euo pipefail

CFG="/workspace/project_files/dds_web_projection_1/al-folio/_config.yml"
BAK="/workspace/project_files/dds_web_projection_1/al-folio/dds_custom/_config.yml.original.bak"

NEW_URL="https://dds131.github.io"

[ -f "${CFG}" ] || { echo "[错误] 找不到 ${CFG}"; exit 1; }

# ---- 回滚模式 ----
if [ "${1:-}" = "--restore" ]; then
    [ -f "${BAK}" ] || { echo "[错误] 备份不存在: ${BAK}"; exit 1; }
    cp -f "${BAK}" "${CFG}"
    echo "[02_patch] 已从备份恢复 _config.yml"
    exit 0
fi

echo "=============================================="
echo "[02_patch] 修改 _config.yml"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  文件: ${CFG}"
echo "=============================================="

# ---- 备份原文件（只在首次备份，保证 .bak 永远是最初的原始版本） ----
if [ ! -f "${BAK}" ]; then
    mkdir -p "$(dirname "${BAK}")"
    cp -f "${CFG}" "${BAK}"
    echo "[02_patch] 已备份原始文件 -> ${BAK}"
else
    echo "[02_patch] 原始备份已存在，不覆盖 -> ${BAK}"
fi

# ---- ① url ----
if grep -qE '^url: https://alshedivat\.github\.io' "${CFG}"; then
    sed -i -E "s|^url: https://alshedivat\.github\.io|url: ${NEW_URL}|" "${CFG}"
    echo "[02_patch] ① url 已修改 -> ${NEW_URL}"
elif grep -qE "^url: ${NEW_URL}" "${CFG}"; then
    echo "[02_patch] ① url 已是目标值，跳过"
else
    echo "[错误] ① url 行不符合预期，请人工检查:"; grep -n '^url:' "${CFG}"; exit 1
fi

# ---- ② baseurl ----
if grep -qE '^baseurl: /al-folio' "${CFG}"; then
    sed -i -E 's|^baseurl: /al-folio |baseurl: |' "${CFG}"
    echo "[02_patch] ② baseurl 已清空（保留该行）"
elif grep -qE '^baseurl: +#' "${CFG}"; then
    echo "[02_patch] ② baseurl 已为空，跳过"
else
    echo "[错误] ② baseurl 行不符合预期，请人工检查:"; grep -n '^baseurl:' "${CFG}"; exit 1
fi

# ---- ③ exclude 新增 dds_custom/ ----
if grep -qE '^  - dds_custom/$' "${CFG}"; then
    echo "[02_patch] ③ exclude 中已有 dds_custom/，跳过"
else
    # 插到 "  - docs/" 之前，维持该列表原有的字母序
    sed -i '0,/^  - docs\/$/s|^  - docs/$|  - dds_custom/\n  - docs/|' "${CFG}"
    grep -qE '^  - dds_custom/$' "${CFG}" || { echo "[错误] ③ 插入 exclude 失败"; exit 1; }
    echo "[02_patch] ③ exclude 已新增 dds_custom/"
fi

echo "----------------------------------------------"
echo "[02_patch] 结果 diff（原始 -> 现在）:"
diff -u "${BAK}" "${CFG}" || true
echo "----------------------------------------------"
echo "[02_patch] 关键行确认:"
grep -nE '^(url|baseurl):' "${CFG}"
grep -nE '^  - dds_custom/$' "${CFG}"
echo "=============================================="
