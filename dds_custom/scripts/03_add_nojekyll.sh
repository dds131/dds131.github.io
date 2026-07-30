#!/usr/bin/env bash
# =============================================================================
# 03_add_nojekyll.sh —— 补齐 .nojekyll，使部署符合 GitHub Pages 官方要求
# =============================================================================
#
# 【目的】
#   让 GitHub Pages 原样发布 GitHub Actions 已经构建好的产物，
#   而不是对产物再跑一遍 GitHub 自带的 Jekyll。
#
# 【解决了什么问题（有实测证据）】
#   现象：站点上线后 https://dds131.github.io/_pages/dropdown/ 返回 404，
#         但该文件确实存在于 gh-pages 分支上。
#   原因：Pages 发布源虽已设为 gh-pages，但 build_type 是 legacy，
#         GitHub 会对【已经构建好的产物】再跑一遍内置 Jekyll。
#         而 Jekyll 默认丢弃以 _ 、. 或 # 开头的文件和目录，
#         al-folio 的产物根目录恰好有 _pages/，于是被丢掉了。
#   修复后：同一路径返回 200。
#
# 【官方依据】
#   1) https://docs.github.com/en/pages/getting-started-with-github-pages/
#      configuring-a-publishing-source-for-your-github-pages-site
#      原文要点：外部 CI 通常「把构建产物提交到 gh-pages 分支」并且
#      「包含一个 .nojekyll 文件」，此时 GitHub「会检测到该分支不需要构建步骤」，
#      直接进入部署。
#      另注明：使用 GITHUB_TOKEN 的 workflow 产生的提交不会触发 Pages 构建。
#   2) https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/
#      about-github-pages-and-jekyll
#      原文要点：Jekyll 默认不构建以 _ 、. 或 # 开头的文件或文件夹。
#
# 【附带收益】
#   官方文档明确写明「使用 GITHUB_TOKEN 的 workflow 产生的提交不会触发 Pages 构建」。
#   deploy.yml 正是用 GITHUB_TOKEN 把产物推到 gh-pages 的，所以在补齐 .nojekyll 之前，
#   每次都需要手动调 API 触发 Pages 构建，站点才会更新。
#   带上 .nojekyll 后 GitHub 识别出该分支无需构建步骤，直接部署，
#   实测后续推送能自动触发并完成部署。
#
# 【本脚本改了什么】（2 处）
#   ① 在 al-folio 仓库根目录新建空文件 .nojekyll
#   ② _config.yml: include: ["_pages"]  ->  include: ["_pages", ".nojekyll"]
#
# 【为什么改动 ② 是必需的，不是可选的】
#   Jekyll 默认不处理以 . 开头的文件。
#   如果只创建 .nojekyll 而不把它加进 include，Jekyll 构建时会直接忽略它，
#   它就不会被复制进 _site/，也就传不到 gh-pages 分支 —— 等于白加。
#   必须显式加入 include 列表，Jekyll 才会把它拷贝到构建产物里。
#
# 【为什么 .nojekyll 不能放在 dds_custom/ 目录下】
#   该文件必须位于【发布站点的根目录】才有效，这是 GitHub 的硬性规则，
#   无法通过目录组织规避。这也是本项目唯一一个放在 dds_custom/ 之外的新增文件。
#
# 【与上游设计的关系：这是补齐缺口，不是违背上游】
#   al-folio 的 _config.yml 第 243-245 行本来就有：
#       keep_files:
#         - CNAME
#         - .nojekyll
#   keep_files 的含义是"重新构建时不要删除 _site 里的这些文件"，
#   说明上游【预期该文件存在】并主动保护它。
#   但仓库里从来没有真正创建过这个文件（find . -name .nojekyll 结果为空），
#   而且 CI 是全新检出构建，_site 每次都是空的，keep_files 在 CI 里根本不起作用。
#   所以这是 al-folio 自身的一个缺口，本脚本是补齐它。
#
# 【使用方法】
#   # 执行
#   docker exec xitu_dds_linshi_project_1 bash -lc \
#     'bash /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/03_add_nojekyll.sh'
#
#   # 回滚（删除 .nojekyll 并还原 include）
#   docker exec xitu_dds_linshi_project_1 bash -lc \
#     'bash /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/03_add_nojekyll.sh --undo'
#
# 【如何验证】
#   # 本地
#   ls -la .nojekyll && grep -n '^include:' _config.yml
#   # 线上（部署完成后）
#   curl -s -o /dev/null -w "%{http_code}\n" https://dds131.github.io/.nojekyll          # 期望 200
#   curl -s -o /dev/null -w "%{http_code}\n" https://dds131.github.io/_pages/dropdown/   # 期望 200
#
# 【执行结果】2026-07-30 13:54:32 UTC
#   两处均成功。部署后 /_pages/dropdown/ 从 404 变为 200，
#   全站 20 项回归测试 0 失败。
# =============================================================================

set -euo pipefail   # 出错即停 / 未定义变量报错 / 管道失败即失败

# ---- 路径与目标值定义 ----
ROOT="/workspace/project_files/dds_web_projection_1/al-folio"   # 仓库根目录
CFG="${ROOT}/_config.yml"                                        # 要修改的配置文件
NOJEKYLL="${ROOT}/.nojekyll"                                     # 要创建的空文件

# include 行的改前 / 改后值，集中定义便于维护和回滚复用
OLD_INC='include: ["_pages"]'
NEW_INC='include: ["_pages", ".nojekyll"]'

[ -f "${CFG}" ] || { echo "[错误] 找不到 ${CFG}"; exit 1; }

# -------------------------------------------------------------------------
# 回滚模式
# -------------------------------------------------------------------------
# 做两件事：删掉 .nojekyll 文件，把 include 行改回原值。
# rm -f 的 -f：文件不存在时也不报错，保证回滚可重复执行。
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

# -------------------------------------------------------------------------
# 改动 ① —— 创建空文件 .nojekyll
# -------------------------------------------------------------------------
# ": > 文件" 是创建空文件的写法：
#   : 是 bash 内建的空命令（什么都不做，返回成功）
#   > 重定向会创建文件（已存在则清空）
# 等价于 touch，但语义更明确地表达"内容就是空的"。
# .nojekyll 的作用完全由"它存在"这一事实决定，内容无关紧要，所以是 0 字节。
if [ -f "${NOJEKYLL}" ]; then
    echo "[03_nojekyll] ① .nojekyll 已存在，跳过"
else
    : > "${NOJEKYLL}"
    echo "[03_nojekyll] ① 已创建空文件 ${NOJEKYLL}"
fi

# -------------------------------------------------------------------------
# 改动 ② —— 修改 _config.yml 的 include 行
# -------------------------------------------------------------------------
# 与 02_patch_config.sh 相同的三分支安全模式：
#   已是目标值 -> 跳过；是原始值 -> 修改；都不是 -> 报错中止。
#
# grep -qF 的 -F：把模式当作固定字符串而非正则。
# 这里必须用 -F，因为 include 值里含有 [ ] " 等正则元字符，
# 用正则模式会匹配失败或产生意外结果。
if grep -qF "${NEW_INC}" "${CFG}"; then
    echo "[03_nojekyll] ② include 已是目标值，跳过"
elif grep -qF "${OLD_INC}" "${CFG}"; then
    # sed 需要正则，而 OLD_INC 含 [ ] . 等元字符，必须先转义。
    # 内层的 sed 's/[][\.*^$/]/\\&/g' 就是转义器：
    #   字符集 [][\.*^$/] 列出所有需要转义的字符
    #     （] 放在字符集开头是唯一不需要转义它的位置，这是 POSIX 规则）
    #   \\& 表示"在匹配到的字符前加一个反斜杠"（& 代表匹配内容本身）
    # 转义后再交给外层 sed 做替换，这样 [ ] 等字符被当作字面量处理。
    # 末尾的 \$ 锚定行尾，确保整行精确匹配。
    sed -i "s|^$(printf '%s' "${OLD_INC}" | sed 's/[][\.*^$/]/\\&/g')\$|${NEW_INC}|" "${CFG}"
    # 事后校验，防止 sed 静默失败（sed 未匹配到内容时也返回 0）
    grep -qF "${NEW_INC}" "${CFG}" || { echo "[错误] ② include 修改失败"; exit 1; }
    echo "[03_nojekyll] ② include 已修改"
else
    echo "[错误] ② include 行不符合预期，请人工检查:"; grep -n '^include:' "${CFG}"; exit 1
fi

# -------------------------------------------------------------------------
# 打印结果供人工核对
# -------------------------------------------------------------------------
echo "----------------------------------------------"
echo "[03_nojekyll] 确认:"
ls -la "${NOJEKYLL}"                    # 确认文件存在且为 0 字节
grep -n '^include:' "${CFG}"            # 确认 include 已包含 .nojekyll
grep -n -A 3 '^keep_files:' "${CFG}"    # 顺带展示上游的 keep_files，印证"补齐缺口"的说法
echo "=============================================="
