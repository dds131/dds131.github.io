#!/usr/bin/env bash
# =============================================================================
# 02_patch_config.sh —— 修改 al-folio 的 _config.yml，使其指向 dds131 的 GitHub Pages
# =============================================================================
#
# 【目的】
#   al-folio 从上游克隆下来时，_config.yml 里的站点地址是上游演示站的地址。
#   要让它变成"你自己的网站"，必须把这些地址改成你的。
#
# 【本脚本改了什么】（对 al-folio 原有源码的修改，共 3 处）
#   ① url     : https://alshedivat.github.io  ->  https://dds131.github.io
#   ② baseurl : /al-folio                     ->  (留空，但保留该行)
#   ③ exclude : 新增一行 "  - dds_custom/"
#
# 【每一处的作用与不改的后果】
#
#   ① url
#      作用：站点的绝对根地址。Jekyll 用它生成 canonical link、sitemap.xml、
#            RSS feed、Open Graph 标签里的绝对 URL。
#      不改的后果：这些元数据全部指向上游作者的网站。搜索引擎会认为你的页面
#            是别人网站的副本，SEO 受损；RSS 订阅会跳到别人站上。
#
#   ② baseurl
#      作用：站点在域名下的子路径前缀。
#            - 用户主页站（仓库名 == <用户名>.github.io）根路径是 /，必须留空
#            - 项目站（仓库名任意）路径是 /<仓库名>/，必须填 /<仓库名>
#      本项目仓库名 dds131.github.io 恰好等于 <用户名>.github.io，
#      是用户主页站，所以必须留空。
#      不改的后果（严重）：所有资源 URL 会被加上 /al-folio 前缀，
#            例如 /al-folio/assets/css/main.css，而文件实际在 /assets/css/main.css
#            —— 全站 CSS、JS、图片 100% 404，页面变成一堆没有样式的裸文字。
#      为什么保留空行而不删掉：al-folio 官方文档明确要求
#            "leave baseurl empty (do NOT delete it)"。
#            Jekyll 读不到该键与读到空值的行为不同，删除会出问题。
#
#   ③ exclude 新增 dds_custom/
#      作用：exclude 列出 Jekyll 构建时要忽略的路径。
#      不改的后果：dds_custom/ 下的 .md 文档会被 Jekyll 当成网页渲染，
#            出现在最终站点里，还可能因为 Markdown 里的 Liquid 语法
#            （如 {{ }} 、{% %}）导致构建报错。
#
# 【为什么必须改 _config.yml，不能用叠加配置绕开】
#   Jekyll 支持 `--config a.yml,b.yml` 做配置叠加，理论上可以把自定义配置
#   全放在 dds_custom/ 下，完全不碰 _config.yml。
#   但上游 .github/workflows/deploy.yml 第 100 行执行的是【裸的】
#   `bundle exec jekyll build`，不带 --config 参数。
#   要用叠加配置就必须修改这个 CI workflow 文件。
#   权衡：改 _config.yml 的 3 行  vs  改 CI workflow 文件。
#   后者更底层、影响面更大（workflow 改错会导致整个部署链路瘫痪），
#   所以改 _config.yml 才是真正的最小改动。
#
# 【安全设计】
#   1. 自动备份：首次执行时把原始 _config.yml 完整复制到
#      dds_custom/_config.yml.original.bak，且后续重跑【不覆盖】该备份，
#      保证 .bak 永远是最初的原始版本。
#   2. 严格校验：三处改动各自先检查当前内容是否符合预期。
#      只要有任何一处匹配不上，立刻 exit 1 中止，绝不做半截修改。
#   3. 幂等：已经改过的部分会跳过，重复执行安全。
#   4. 可回滚：bash 02_patch_config.sh --restore 一键还原。
#   5. 结果可验：执行完自动打印 diff -u 和关键行，肉眼即可核对。
#
# 【使用方法】
#   # 执行修改
#   docker exec xitu_dds_linshi_project_1 bash -lc \
#     'bash /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/02_patch_config.sh'
#
#   # 回滚（从 .bak 还原原始文件）
#   docker exec xitu_dds_linshi_project_1 bash -lc \
#     'bash /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/02_patch_config.sh --restore'
#
# 【如何验证改动】
#   grep -nE '^(url|baseurl):' _config.yml
#   grep -nE '^  - dds_custom/$' _config.yml
#   git diff -- _config.yml
#
# 【执行结果】2026-07-30 13:33:08 UTC
#   三处全部修改成功，diff 确认只有预期的 3 处，无任何多余改动。
# =============================================================================

set -euo pipefail   # 出错即停 / 未定义变量报错 / 管道失败即失败

# ---- 路径与目标值定义 ----
CFG="/workspace/project_files/dds_web_projection_1/al-folio/_config.yml"                      # 要修改的配置文件
BAK="/workspace/project_files/dds_web_projection_1/al-folio/dds_custom/_config.yml.original.bak"  # 原始文件备份位置

NEW_URL="https://dds131.github.io"   # 目标站点地址（GitHub 用户主页站固定为 https://<用户名>.github.io）

# 前置检查：配置文件必须存在
[ -f "${CFG}" ] || { echo "[错误] 找不到 ${CFG}"; exit 1; }

# -------------------------------------------------------------------------
# 回滚模式：从备份还原原始 _config.yml
# -------------------------------------------------------------------------
# 放在最前面处理，这样即使后面的逻辑有问题也不影响回滚能力。
# "${1:-}" 的写法：$1 不存在时取空字符串，避免 set -u 下引用未定义变量报错。
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

# -------------------------------------------------------------------------
# 备份原文件
# -------------------------------------------------------------------------
# 关键设计：只在 .bak 不存在时才备份。
# 如果每次都覆盖，第二次执行就会把"已修改的版本"当成"原始版本"存进去，
# 备份就失去意义了，也无法再回滚到真正的原始状态。
if [ ! -f "${BAK}" ]; then
    mkdir -p "$(dirname "${BAK}")"   # 确保 dds_custom/ 目录存在
    cp -f "${CFG}" "${BAK}"
    echo "[02_patch] 已备份原始文件 -> ${BAK}"
else
    echo "[02_patch] 原始备份已存在，不覆盖 -> ${BAK}"
fi

# -------------------------------------------------------------------------
# 改动 ① —— url
# -------------------------------------------------------------------------
# 三分支结构（本脚本三处改动都用这个模式）：
#   分支 1：匹配到原始值   -> 执行修改
#   分支 2：匹配到目标值   -> 说明已改过，跳过（保证幂等）
#   分支 3：两者都不匹配   -> 说明文件被人动过或上游版本变了，报错中止
# 第 3 个分支是关键：宁可停下来让人检查，也不要在未知状态下乱改。
if grep -qE '^url: https://alshedivat\.github\.io' "${CFG}"; then
    # sed 用 | 作分隔符而不是默认的 /，因为 URL 里含有 /，
    # 用 / 的话需要大量转义，可读性差且容易出错。
    # 正则里的 \. 是转义的字面点号（不转义的话 . 匹配任意字符）。
    sed -i -E "s|^url: https://alshedivat\.github\.io|url: ${NEW_URL}|" "${CFG}"
    echo "[02_patch] ① url 已修改 -> ${NEW_URL}"
elif grep -qE "^url: ${NEW_URL}" "${CFG}"; then
    echo "[02_patch] ① url 已是目标值，跳过"
else
    echo "[错误] ① url 行不符合预期，请人工检查:"; grep -n '^url:' "${CFG}"; exit 1
fi

# -------------------------------------------------------------------------
# 改动 ② —— baseurl
# -------------------------------------------------------------------------
# 注意替换模式 '^baseurl: /al-folio ' 末尾有一个空格，
# 这样只删掉值 "/al-folio"，把后面的注释文字原样保留下来：
#   改前: baseurl: /al-folio # the subpath of your site, e.g. /blog/. ...
#   改后: baseurl: # the subpath of your site, e.g. /blog/. ...
# 保留注释是有意为之 —— 日后看到这行能立刻明白它是干什么的、为什么是空的。
if grep -qE '^baseurl: /al-folio' "${CFG}"; then
    sed -i -E 's|^baseurl: /al-folio |baseurl: |' "${CFG}"
    echo "[02_patch] ② baseurl 已清空（保留该行）"
# 幂等判断：'^baseurl: +#' 匹配 "baseurl:" 后跟若干空格再跟 # 注释，
# 即"值为空且后面有注释"的已修改状态。
elif grep -qE '^baseurl: +#' "${CFG}"; then
    echo "[02_patch] ② baseurl 已为空，跳过"
else
    echo "[错误] ② baseurl 行不符合预期，请人工检查:"; grep -n '^baseurl:' "${CFG}"; exit 1
fi

# -------------------------------------------------------------------------
# 改动 ③ —— exclude 列表新增 dds_custom/
# -------------------------------------------------------------------------
# grep -qE '^  - dds_custom/$' 中：
#   ^  - 表示行首两个空格加 "- "（YAML 列表项的固定缩进）
#   $   表示行尾，确保精确匹配，不会误判 "- dds_custom_old/" 之类
if grep -qE '^  - dds_custom/$' "${CFG}"; then
    echo "[02_patch] ③ exclude 中已有 dds_custom/，跳过"
else
    # sed 命令逐段解释：
    #   0,/^  - docs\/$/   地址范围：从第 0 行到【第一个】匹配 "  - docs/" 的行。
    #                      用 0, 而不是 1, 是为了让范围能在第一行就结束。
    #                      作用是只替换第一次出现，防止文件里别处也有 "  - docs/" 被误改。
    #   s|...|...|         替换命令，同样用 | 作分隔符避免转义路径里的 /
    #   \n                 在替换结果中插入换行，实现"在 docs/ 之前插入一行"
    # 插在 docs/ 之前是为了维持该列表原有的字母序（dds < docs）。
    sed -i '0,/^  - docs\/$/s|^  - docs/$|  - dds_custom/\n  - docs/|' "${CFG}"
    # 事后校验：sed 即使没匹配到任何内容也返回 0（成功），
    # 所以必须再 grep 一次确认真的插进去了，否则会静默失败。
    grep -qE '^  - dds_custom/$' "${CFG}" || { echo "[错误] ③ 插入 exclude 失败"; exit 1; }
    echo "[02_patch] ③ exclude 已新增 dds_custom/"
fi

# -------------------------------------------------------------------------
# 打印结果供人工核对
# -------------------------------------------------------------------------
echo "----------------------------------------------"
echo "[02_patch] 结果 diff（原始 -> 现在）:"
# diff 在发现差异时返回 1，而 set -e 会让脚本因非 0 返回值退出。
# 加 "|| true" 把返回值吞掉，保证脚本能继续执行到最后。
diff -u "${BAK}" "${CFG}" || true
echo "----------------------------------------------"
echo "[02_patch] 关键行确认:"
grep -nE '^(url|baseurl):' "${CFG}"
grep -nE '^  - dds_custom/$' "${CFG}"
echo "=============================================="
