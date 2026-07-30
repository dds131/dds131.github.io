#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 01_backup.sh —— 容器内 git 备份（不上传，仅本地留存，便于回退与比较）
#
# 目的
#   1) 为 al-folio 建立一个「独立的快照 git 仓库」，每个里程碑一个 commit + tag，
#      便于随时 diff 比较、回退到任意里程碑。
#      之所以另建仓库而不是直接用 al-folio 自带的 .git：
#      al-folio 自带 .git 有 354 MiB 上游历史，直接再克隆一份代价高；
#      快照仓库只跟踪工作区文件（约 55 MiB），轻量且语义清晰。
#   2) 同时在 al-folio 自身仓库打同名 annotated tag，作为轻量锚点，
#      可直接 `git diff <tag>` 查看相对该里程碑改了什么。
#
# 备份地址（均在容器内，不上传）
#   快照仓库 : /workspace/project_files/dds_backup_repos/al-folio_snapshots/
#   源仓库tag: /workspace/project_files/dds_web_projection_1/al-folio (git tag)
#
# 用法
#   bash 01_backup.sh <TAG> "<说明文字>"
# 示例
#   bash 01_backup.sh al-folio.v1.0.0.upstream-original-unmodified.2026.07.30 "上游原始克隆，未做任何修改"
# ---------------------------------------------------------------------------
set -euo pipefail

SRC="/workspace/project_files/dds_web_projection_1/al-folio"
BACKUP_ROOT="/workspace/project_files/dds_backup_repos"
SNAP="${BACKUP_ROOT}/al-folio_snapshots"

TAG="${1:?用法: bash 01_backup.sh <TAG> \"<说明文字>\"}"
MSG="${2:-无说明}"

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

[ -d "${SRC}" ] || { echo "[错误] 源目录不存在: ${SRC}"; exit 1; }

# ---- 1. 初始化快照仓库（幂等） ----
mkdir -p "${SNAP}"
if [ ! -d "${SNAP}/.git" ]; then
    git init -q -b main "${SNAP}"
    git -C "${SNAP}" config user.name  "${GIT_NAME}"
    git -C "${SNAP}" config user.email "${GIT_MAIL}"
    echo "[01_backup] 已初始化快照仓库: ${SNAP}"
else
    echo "[01_backup] 快照仓库已存在，追加新快照"
fi

# ---- 2. 同步工作区文件到快照仓库 ----
# 排除 .git（上游 354MiB 历史，源仓库自身已保留）
# 不排除 dds_custom，使每个快照都完整反映当时的全部内容
echo "[01_backup] 清空快照工作区（保留 .git）..."
find "${SNAP}" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

echo "[01_backup] 拷贝源文件..."
tar -C "${SRC}" --exclude='./.git' -cf - . | tar -C "${SNAP}" -xf -

# ---- 3. 提交快照 ----
git -C "${SNAP}" add -A
if git -C "${SNAP}" diff --cached --quiet; then
    echo "[01_backup] 内容与上一快照一致，跳过 commit"
else
    git -C "${SNAP}" commit -q -m "${TAG}

${MSG}

备份时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
源目录  : ${SRC}
源HEAD  : $(git -C "${SRC}" rev-parse HEAD)"
    echo "[01_backup] 已提交快照 commit"
fi

# ---- 4. 打 tag（快照仓库） ----
if git -C "${SNAP}" rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "[01_backup] 快照仓库 tag 已存在，跳过: ${TAG}"
else
    git -C "${SNAP}" tag -a "${TAG}" -m "${MSG}"
    echo "[01_backup] 快照仓库已打 tag: ${TAG}"
fi

# ---- 5. 打 tag（al-folio 源仓库，本地锚点，绝不推送） ----
if git -C "${SRC}" rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "[01_backup] 源仓库 tag 已存在，跳过: ${TAG}"
else
    git -C "${SRC}" -c user.name="${GIT_NAME}" -c user.email="${GIT_MAIL}" \
        tag -a "${TAG}" -m "${MSG}"
    echo "[01_backup] 源仓库已打 tag: ${TAG}"
fi

echo "----------------------------------------------"
echo "[01_backup] 完成。快照仓库现有 tag:"
git -C "${SNAP}" tag -n1
echo "[01_backup] 快照仓库体积: $(du -sh "${SNAP}" | cut -f1)"
echo "=============================================="
