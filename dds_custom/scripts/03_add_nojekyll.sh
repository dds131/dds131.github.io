#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 03_add_nojekyll.sh —— 补齐 .nojekyll，使部署符合 GitHub Pages 官方要求
#
# 依据的官方文档
#   https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
#     原文要点：外部 CI 通常「把构建产物提交到 gh-pages 分支」并且「包含一个 .nojekyll 文件」，
#               此时 GitHub「会检测到该分支不需要构建步骤」，直接进入部署。
#     另注明：使用 GITHUB_TOKEN 的 workflow 产生的提交不会触发 Pages 构建。
#   https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll
#     原文要点：Jekyll 默认不构建以 _ 、. 或 # 开头的文件或文件夹。
#
# 要解决的实际问题
#   Pages 发布源为 gh-pages 且 build_type=legacy 时，GitHub 会对已经构建好的产物
#   再跑一遍内置 Jekyll。由于 al-folio 的产物根目录含 _pages/（下划线开头），
#   该目录会被内置 Jekyll 丢弃。实测 https://dds131.github.io/_pages/dropdown/ 返回 404。
#   加上 .nojekyll 后 GitHub 原样发布产物，不再二次处理。
#
# 本脚本做的两处改动
#   ① 在 al-folio 仓库根目录新建空文件 .nojekyll
#   ② _config.yml: include: ["_pages"] -> include: ["_pages", ".nojekyll"]
#      必需，否则 Jekyll 不会把点开头的 .nojekyll 复制进 _site，也就传不到 gh-pages。
#
# 说明：al-folio 的 _config.yml 本就有
#         keep_files:
#           - CNAME
#           - .nojekyll
#       即上游已预期存在该文件并保护它，但从未真正创建。本脚本是补齐该缺口。
#
# 特性：幂等（重复执行安全）、执行前后打印 diff
# 用法：bash 03_add_nojekyll.sh
# 回滚：bash 03_add_nojekyll.sh --undo
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="/workspace/project_files/dds_web_projection_1/al-folio"
CFG="${ROOT}/_config.yml"
NOJEKYLL="${ROOT}/.nojekyll"

OLD_INC='include: ["_pages"]'
NEW_INC='include: ["_pages", ".nojekyll"]'

[ -f "${CFG}" ] || { echo "[错误] 找不到 ${CFG}"; exit 1; }

# ---- 回滚模式 ----
if [ "${1:-}" = "--undo" ]; then
    rm -f "${NOJEKYLL}"
    sed -i "s|^${NEW_INC}\$|${OLD_INC}|" "${CFG}"
    echo "[03_nojekyll] 已回滚：删除 .nojekyll，include 恢复为 ${OLD_INC}"
    grep -n '^include:' "${CFG}"
    exit 0
fi

echo "=============================================="
echo "[03_nojekyll] 补齐 .nojekyll（GitHub Pages 官方要求）"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "=============================================="

# ---- ① 创建 .nojekyll ----
if [ -f "${NOJEKYLL}" ]; then
    echo "[03_nojekyll] ① .nojekyll 已存在，跳过"
else
    : > "${NOJEKYLL}"
    echo "[03_nojekyll] ① 已创建空文件 ${NOJEKYLL}"
fi

# ---- ② 修改 include ----
if grep -qF "${NEW_INC}" "${CFG}"; then
    echo "[03_nojekyll] ② include 已是目标值，跳过"
elif grep -qF "${OLD_INC}" "${CFG}"; then
    sed -i "s|^$(printf '%s' "${OLD_INC}" | sed 's/[][\.*^$/]/\\&/g')\$|${NEW_INC}|" "${CFG}"
    grep -qF "${NEW_INC}" "${CFG}" || { echo "[错误] ② include 修改失败"; exit 1; }
    echo "[03_nojekyll] ② include 已修改"
else
    echo "[错误] ② include 行不符合预期，请人工检查:"; grep -n '^include:' "${CFG}"; exit 1
fi

echo "----------------------------------------------"
echo "[03_nojekyll] 确认:"
ls -la "${NOJEKYLL}"
grep -n '^include:' "${CFG}"
grep -n -A 3 '^keep_files:' "${CFG}"
echo "=============================================="
