# dds_custom —— 本项目所有自定义内容的集中目录

本目录是 **al-folio 部署到 `https://dds131.github.io/` 这一任务中，所有新增内容的唯一存放位置**。

设计原则：**尽量不改源码；必须改的部分降到最低；所有新增文件集中在这一个目录下。**

---

## 目录结构

```
dds_custom/
├── README.md                          # 本文件
├── _config.yml.original.bak           # 修改前的原始 _config.yml（自动备份，用于回滚与比对）
├── docs/
│   ├── 01_技术路线与实现方案.md        # 为什么这么做：方案选型、原理、权衡
│   ├── 02_源码改动详细清单.md          # 【集中说明】改了哪个文件、哪一行、改成什么、为什么
│   ├── 03_部署操作手册.md              # 怎么做：完整可复现的操作步骤与命令
│   ├── 04_GitHub官方要求对照.md        # 官方文档要求逐条核对结果
│   └── 05_问题与排查记录.md            # 遇到的问题、原因、解决过程
└── scripts/
    ├── 00_env_proxy.sh                # 设置容器内 clash 代理环境变量
    ├── 01_backup.sh                   # 容器内 git 快照备份（幂等）
    ├── 02_patch_config.sh             # 修改 _config.yml 的 url/baseurl/exclude（幂等、可回滚）
    └── 03_add_nojekyll.sh             # 补齐 .nojekyll 以符合 GitHub Pages 官方要求（幂等、可回滚）
```

---

## 快速开始

```bash
# 1) ssh 到 GPU 服务器（密码 Changeme0537），进入容器
ssh dongdesheng@192.168.2.122
docker exec -it xitu_dds_linshi_project_1 /bin/bash

# 2) 进入项目
cd /workspace/project_files/dds_web_projection_1/al-folio

# 3) 设置代理（访问 GitHub 需要）
source dds_custom/scripts/00_env_proxy.sh

# 4) 查看本项目相对上游原始状态的全部改动
git diff al-folio.v1.0.0.upstream-original-unmodified.2026.07.30 -- _config.yml .nojekyll
```

---

## 对源码的改动一览

**只改了 1 个原有文件（`_config.yml`，共 4 处），新增了 1 个空文件（`.nojekyll`）。**
其余所有内容（`_pages/`、`_posts/`、`_projects/`、`_layouts/`、`_includes/`、`_sass/`、`assets/`、`Gemfile`、`.github/workflows/` 等）**一律未动**。

详见 [`docs/02_源码改动详细清单.md`](docs/02_源码改动详细清单.md)。

---

## 相关文档

- 备份与版本管理：`/workspace/project_files/git_document.md`
- 站点地址：<https://dds131.github.io/>
- 仓库地址：<https://github.com/dds131/dds131.github.io>
