#!/usr/bin/env bash
# =============================================================================
# 01_backup.sh —— 容器内 git 快照备份（不上传，仅本地留存，便于回退与比较）
# =============================================================================
#
# 【目的】
#   在对 al-folio 做任何修改之前、以及每完成一个里程碑之后，留下一份
#   可以精确回退、可以逐行比较的历史快照。
#
# 【解决了什么问题】
#   1. 改坏了要能退回去 —— 每个里程碑一个 tag，随时 git reset --hard 回退
#   2. 要能说清"到底改了什么" —— git diff <tag> 一目了然
#   3. 源目录整个损坏也要能救 —— 快照仓库物理独立，不依赖源目录
#
# 【为什么建"独立快照仓库"而不是直接复制目录】
#   al-folio 自带的 .git 有 354 MiB（1096 个 commit 的上游完整历史）。
#   每个里程碑复制一份整目录，磁盘开销迅速膨胀，而且多份副本之间
#   没法用 git 工具做比较。
#   独立快照仓库只跟踪工作区文件（约 55 MiB），多个里程碑共享 git 对象存储，
#   增量存储、体积可控，还能直接用 git diff 比较任意两个里程碑。
#
# 【为什么同时也在源仓库打 tag】
#   两种方式互补，本脚本两个都做：
#     - 源仓库 tag  : 零额外空间，git diff <tag> 最方便，但与源目录同生共死
#     - 独立快照库  : 占空间，但源目录被误删/.git 损坏时仍能恢复
#
# 【为什么快照仓库排除 .git】
#   快照的目的是保存"内容"，不是保存上游的提交历史。
#   上游历史在 al-folio 源仓库里已有一份，且公开可从 GitHub 重新获取，
#   没必要在备份里再存一份 354 MiB。
#
# 【备份地址】（均在容器内，绝不上传）
#   快照仓库  : /workspace/project_files/dds_backup_repos/al-folio_snapshots/
#   源仓库tag : /workspace/project_files/dds_web_projection_1/al-folio （git tag）
#
# 【使用方法】
#   bash 01_backup.sh <版本号> "<说明文字>"
#
#   完整示例：
#     docker exec xitu_dds_linshi_project_1 bash -lc \
#       'bash /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/01_backup.sh \
#          al-folio.v1.6.0.docs-enhanced.2026.07.30 \
#          "文档与脚本注释大幅完善"'
#
# 【版本号命名规范】
#   <项目名>.<语义化版本>.<内容简述>.<年.月.日>
#   例：al-folio.v1.0.0.upstream-original-unmodified.2026.07.30
#
# 【幂等性】
#   可重复执行。内容无变化时跳过 commit；tag 已存在时跳过打 tag。
#   不会因为多跑一次而产生重复提交或报错中断。
#
# 【如何回退】
#   # 查看所有里程碑及其说明
#   cd /workspace/project_files/dds_web_projection_1/al-folio && git tag -n1
#   # 看相对某里程碑改了什么
#   git diff al-folio.v1.0.0.upstream-original-unmodified.2026.07.30
#   # 整体回退到某里程碑（会丢弃之后的提交，谨慎）
#   git reset --hard al-folio.v1.0.0.upstream-original-unmodified.2026.07.30
#   # 源目录损坏时从快照仓库恢复
#   cd /workspace/project_files/dds_backup_repos/al-folio_snapshots
#   git checkout <tag> -- .
# =============================================================================

# set -e          任一命令返回非 0 立即退出，避免出错后继续执行造成半截状态
# set -u          引用未定义变量时报错退出，防止路径变量为空导致 rm 误删
# set -o pipefail 管道中任一环节失败即视为整条管道失败（默认只看最后一个命令）
# 这三项组合是 bash 脚本的安全基线，对含 rm -rf 的脚本尤其重要。
set -euo pipefail

# ---- 路径定义（全部硬编码，不接受外部传入，避免误操作到别的目录）----
SRC="/workspace/project_files/dds_web_projection_1/al-folio"   # 备份源：al-folio 工作区
BACKUP_ROOT="/workspace/project_files/dds_backup_repos"        # 备份根目录
SNAP="${BACKUP_ROOT}/al-folio_snapshots"                       # 快照仓库目录

# ---- 参数解析 ----
# ${1:?错误信息} 语法：$1 未提供或为空时，打印错误信息并退出。
# 强制要求必须传版本号，避免打出没有意义的匿名备份。
TAG="${1:?用法: bash 01_backup.sh <TAG> \"<说明文字>\"}"
# 说明文字可选，未提供时用默认值（不强制，降低使用门槛）
MSG="${2:-无说明}"

# git 提交身份。用 GitHub 官方 noreply 邮箱，不暴露真实邮箱地址。
GIT_NAME="dds131"
GIT_MAIL="dds131@users.noreply.github.com"

echo "=============================================="
echo "[01_backup] 开始备份"
echo "  时间   : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  源目录 : ${SRC}"
echo "  快照库 : ${SNAP}"
echo "  版本号 : ${TAG}"
echo "  说明   : ${MSG}"
echo "=============================================="

# 前置检查：源目录必须存在，否则后面 tar 会失败且报错难懂。
[ -d "${SRC}" ] || { echo "[错误] 源目录不存在: ${SRC}"; exit 1; }

# -------------------------------------------------------------------------
# 步骤 1：初始化快照仓库（幂等 —— 已存在则跳过初始化，直接追加新快照）
# -------------------------------------------------------------------------
mkdir -p "${SNAP}"
# 判断依据是 .git 子目录是否存在，而不是目录本身是否存在，
# 因为上一行 mkdir -p 已经保证目录一定存在了。
if [ ! -d "${SNAP}/.git" ]; then
    # -q 静默；-b main 指定初始分支名为 main（避免 git 版本差异导致有的叫 master）
    git init -q -b main "${SNAP}"
    # 只在这个仓库内设置身份（不加 --global，不影响容器内其他仓库）
    git -C "${SNAP}" config user.name  "${GIT_NAME}"
    git -C "${SNAP}" config user.email "${GIT_MAIL}"
    echo "[01_backup] 已初始化快照仓库: ${SNAP}"
else
    echo "[01_backup] 快照仓库已存在，追加新快照"
fi

# -------------------------------------------------------------------------
# 步骤 2：把源目录的工作区文件同步到快照仓库
# -------------------------------------------------------------------------
# 先清空再拷贝，而不是直接覆盖。
# 原因：如果只覆盖，源目录里已被删除的文件会残留在快照里，
#       导致快照不能精确反映当时的真实状态。
#
# ⚠️ rm -rf 的作用域严格限定在 ${SNAP}（硬编码为快照仓库目录），
#    永远不会碰到源目录 ${SRC}。源目录全程只被 tar 读取，不写不删。
#
# find 参数逐个解释：
#   ${SNAP}        起始目录
#   -mindepth 1    不包括 ${SNAP} 目录本身（否则会把快照仓库自己删掉）
#   -maxdepth 1    只处理第一层，不递归（配合 rm -rf 已能删干净，且更快）
#   ! -name '.git' 排除 .git，保留 git 历史（这是整个备份机制的核心）
#   -exec rm -rf {} +   对匹配项执行 rm -rf；用 + 而非 \; 表示批量传参，效率更高
echo "[01_backup] 清空快照工作区（保留 .git）..."
find "${SNAP}" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

# 用 tar 管道复制，而不是 cp -r。
# 原因：
#   1. tar 的 --exclude 能可靠地排除 .git，cp 做不到（cp 没有 exclude 选项）
#   2. tar 能完整保留文件权限、符号链接、时间戳
#   3. 管道方式不产生中间临时文件，节省磁盘和时间
# 参数解释：
#   -C ${SRC}          先切换到源目录，使归档内路径为相对路径（./xxx）
#   --exclude='./.git' 排除上游 354 MiB 的 git 历史
#   -cf -              创建归档并输出到 stdout
#   | tar -C ${SNAP} -xf -   从 stdin 读取并解包到快照仓库
echo "[01_backup] 拷贝源文件..."
tar -C "${SRC}" --exclude='./.git' -cf - . | tar -C "${SNAP}" -xf -

# -------------------------------------------------------------------------
# 步骤 3：把这次快照提交到快照仓库
# -------------------------------------------------------------------------
# -A 表示暂存所有变化，包括新增、修改和删除（删除很重要，见步骤 2 的说明）
git -C "${SNAP}" add -A

# 先判断有没有实际变化，没有就跳过 commit。
# git diff --cached --quiet：暂存区与 HEAD 相同时返回 0（真），有差异时返回 1。
# 这样重复执行本脚本不会产生一堆内容完全相同的空提交。
if git -C "${SNAP}" diff --cached --quiet; then
    echo "[01_backup] 内容与上一快照一致，跳过 commit"
else
    # 提交信息采用多行格式：首行是版本号（便于 git log --oneline 查看），
    # 后面附上说明、备份时间和源仓库 HEAD（便于日后追溯对应上游哪个提交）。
    git -C "${SNAP}" commit -q -m "${TAG}

${MSG}

备份时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
源目录  : ${SRC}
源HEAD  : $(git -C "${SRC}" rev-parse HEAD)"
    echo "[01_backup] 已提交快照 commit"
fi

# -------------------------------------------------------------------------
# 步骤 4：在快照仓库打 annotated tag
# -------------------------------------------------------------------------
# 用 annotated tag（-a）而不是轻量 tag，因为 annotated tag 能附带说明文字，
# git tag -n1 可以直接列出"版本号 + 这个版本干了什么"，便于日后辨认。
#
# rev-parse -q --verify refs/tags/xxx：检查 tag 是否已存在。
#   -q 静默（不存在时不报错到 stderr）
#   --verify 严格校验引用格式
# 已存在就跳过，不用 -f 强制覆盖 —— 避免误改历史里程碑的指向。
if git -C "${SNAP}" rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "[01_backup] 快照仓库 tag 已存在，跳过: ${TAG}"
else
    git -C "${SNAP}" tag -a "${TAG}" -m "${MSG}"
    echo "[01_backup] 快照仓库已打 tag: ${TAG}"
fi

# -------------------------------------------------------------------------
# 步骤 5：在 al-folio 源仓库也打同名 tag（纯本地锚点，绝不推送）
# -------------------------------------------------------------------------
# 作用：可以直接在源仓库执行 git diff <tag> 看改了什么，比切到快照仓库方便。
#
# ⚠️ 这些 tag 只存在于容器本地。推送时一律使用显式 refspec main:main，
#    不用 --tags 也不用 --follow-tags，因此这些 tag 不会被推到 GitHub。
#
# -c user.name=... -c user.email=... 是单次生效的临时配置，
# 用它而不是 git config，是为了不改动 al-folio 仓库的持久配置。
if git -C "${SRC}" rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "[01_backup] 源仓库 tag 已存在，跳过: ${TAG}"
else
    git -C "${SRC}" -c user.name="${GIT_NAME}" -c user.email="${GIT_MAIL}" \
        tag -a "${TAG}" -m "${MSG}"
    echo "[01_backup] 源仓库已打 tag: ${TAG}"
fi

# -------------------------------------------------------------------------
# 步骤 6：打印结果，便于确认备份成功
# -------------------------------------------------------------------------
echo "----------------------------------------------"
echo "[01_backup] 完成。快照仓库现有 tag:"
# -n1 表示每个 tag 显示说明文字的第一行
git -C "${SNAP}" tag -n1
echo "[01_backup] 快照仓库体积: $(du -sh "${SNAP}" | cut -f1)"
echo "=============================================="
