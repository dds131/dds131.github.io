# dds_custom —— 本项目所有自定义内容的集中目录

> **项目目标**：复现 al-folio 项目，构建 GitHub Pages 静态网站，通过 git 托管并展示网页。
>
> **完成状态**：✅ 已完成。网站已上线并通过验收。
>
> | 项         | 值                                                              |
> | ---------- | --------------------------------------------------------------- |
> | 网站地址   | <https://dds131.github.io/>                                     |
> | 仓库地址   | <https://github.com/dds131/dds131.github.io>                    |
> | 上线时间   | 2026-07-30                                                      |
> | 验收结果   | 23 个页面 + 19 个资源，全部返回 200，零 404                     |
> | 正式版本号 | `al-folio.v2.0.0.release-website-live-verified-demo.2026.07.30` |

---

## 一、这个目录是什么

本目录是**本次任务中所有新增内容的唯一存放位置**。

**设计原则**：尽量不改源码；必须改的部分降到最低；所有新增文件集中在这一个目录下。

**它不会影响网站**：`dds_custom/` 已加入 `_config.yml` 的 `exclude` 列表，Jekyll 构建时完全忽略。

---

## 二、目录结构

```
dds_custom/
├── README.md                          # 本文件：目录总览与快速开始
├── _config.yml.original.bak           # 修改前的原始 _config.yml（自动生成，用于回滚与比对）
│
├── docs/                              # 说明文档（共 5 份）
│   ├── 01_技术路线与实现方案.md        # 为什么这么做：原理、方案权衡、架构、关键决策
│   ├── 02_源码改动详细清单.md          # 【集中说明】改了什么、为什么、怎么改的、如何验证与回退
│   ├── 03_部署操作手册.md              # 怎么做：完整可复现的命令清单、日常更新、回滚
│   ├── 04_GitHub官方要求对照.md        # GitHub 官方文档要求与限制的逐条核对结果
│   └── 05_问题与排查记录.md            # 全过程 12 个问题的现象、根因、官方依据、解决过程
│
└── scripts/                           # 可执行脚本（共 4 个，均含详细注释）
    ├── 00_env_proxy.sh                # 设置容器内 clash 代理环境变量        (68 行)
    ├── 01_backup.sh                   # 容器内 git 快照备份，幂等             (215 行)
    ├── 02_patch_config.sh             # 改 url/baseurl/exclude，幂等、可回滚  (197 行)
    └── 03_add_nojekyll.sh             # 补齐 .nojekyll，幂等、可回滚          (164 行)
```

---

## 三、对源码的改动一览

**只改了 1 个原有文件（`_config.yml`，共 4 处），新增 1 个空文件（`.nojekyll`）。**

| #   | 文件          | 位置      | 改动                                  | 作用                                                |
| --- | ------------- | --------- | ------------------------------------- | --------------------------------------------------- |
| ①   | `_config.yml` | 第 21 行  | `url` 改为 `https://dds131.github.io` | 站点绝对根地址，影响 sitemap / RSS / canonical      |
| ②   | `_config.yml` | 第 22 行  | `baseurl` 清空（保留该行）            | 子路径前缀。用户主页站必须为空，否则全站资源 404    |
| ③   | `_config.yml` | 第 228 行 | `exclude` 新增 `dds_custom/`          | 让 Jekyll 忽略本目录，不渲染进站点                  |
| ④   | `_config.yml` | 第 219 行 | `include` 新增 `.nojekyll`            | 让 Jekyll 把点开头的 `.nojekyll` 复制进构建产物     |
| ⑤   | `.nojekyll`   | 根目录    | 新增 0 字节空文件                     | GitHub Pages 官方要求，让其原样发布产物不再二次处理 |

**其余一律未动**：`_pages/` `_posts/` `_projects/` `_news/` `_books/` `_teachings/` `_bibliography/`
`_layouts/` `_includes/` `_sass/` `_data/` `assets/` `Gemfile` `package.json`
以及 `.github/workflows/` 下全部 22 个 CI 配置文件。

**完整说明见** [`docs/02_源码改动详细清单.md`](docs/02_源码改动详细清单.md)。

---

## 四、快速开始

### 4.1 进入环境

```bash
# 从本地 ssh 到 GPU 服务器（密码 Changeme0537）
ssh dongdesheng@192.168.2.122

# 进入容器
docker exec -it xitu_dds_linshi_project_1 /bin/bash

# 进入项目
cd /workspace/project_files/dds_web_projection_1/al-folio

# 设置代理（访问 GitHub 需要，注意必须用 source）
source dds_custom/scripts/00_env_proxy.sh
```

### 4.2 查看本项目改了什么

```bash
# 相对上游原始状态的全部改动
git diff al-folio.v1.0.0.upstream-original-unmodified.2026.07.30 -- _config.yml .nojekyll

# 与备份的原始配置逐行对比
diff -u dds_custom/_config.yml.original.bak _config.yml

# 确认 CI workflow 一行未改（应无任何输出）
git diff --stat al-folio.v1.0.0.upstream-original-unmodified.2026.07.30 -- .github/
```

### 4.3 查看所有备份里程碑

```bash
git tag -n1
git -C /workspace/project_files/dds_backup_repos/al-folio_snapshots tag -n1
```

### 4.4 更新网站内容

```bash
# 在容器内改内容，例如编辑 _pages/about.md
git add -A
git commit -m "更新内容说明"
bash dds_custom/scripts/01_backup.sh al-folio.v2.1.0.<内容简述>.$(date +%Y.%m.%d) "<说明>"
exit
```

推送（在宿主机执行，token 走环境变量不落盘）：

```bash
docker exec -e GH_TOKEN='<你的PAT>' xitu_dds_linshi_project_1 bash -lc '
source /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/00_env_proxy.sh
cd /workspace/project_files/dds_web_projection_1/al-folio
git -c credential.helper="!f(){ echo username=dds131; echo password=$GH_TOKEN; };f" \
    push https://github.com/dds131/dds131.github.io.git main:main'
```

推送后 `Deploy site` 自动触发，约 2~4 分钟站点更新。

### 4.5 回滚

```bash
# 只还原配置改动
bash dds_custom/scripts/02_patch_config.sh --restore
bash dds_custom/scripts/03_add_nojekyll.sh --undo

# 整体回到某个里程碑（会丢弃之后的提交，谨慎）
git reset --hard al-folio.v1.0.0.upstream-original-unmodified.2026.07.30
```

---

## 五、脚本使用速查

| 脚本                 | 执行方式                                        | 回滚方式                                |
| -------------------- | ----------------------------------------------- | --------------------------------------- |
| `00_env_proxy.sh`    | `source .../00_env_proxy.sh`（**必须 source**） | 不需要，只设环境变量                    |
| `01_backup.sh`       | `bash .../01_backup.sh <版本号> "<说明>"`       | 不需要，只新增备份                      |
| `02_patch_config.sh` | `bash .../02_patch_config.sh`                   | `bash .../02_patch_config.sh --restore` |
| `03_add_nojekyll.sh` | `bash .../03_add_nojekyll.sh`                   | `bash .../03_add_nojekyll.sh --undo`    |

**所有脚本的共同特性**：

- `set -euo pipefail`：出错立即停止，不产生半截状态
- 幂等：可重复执行，已完成的部分自动跳过
- 路径硬编码：不接受外部传入路径，避免误操作到别的目录
- 执行前后双重校验：改之前确认现状符合预期，改之后确认真的改成功了
- **不含任何 token 或密码**

---

## 六、架构简图

```
容器 xitu_dds_linshi_project_1 (ruby:3.3)
  /workspace/project_files/dds_web_projection_1/al-folio   ← 源码工作区
         │
         │  git push main:main（经 clash 代理 192.168.2.144:7897）
         ▼
GitHub  dds131/dds131.github.io
  main 分支（al-folio 源码）
         │
         │  .github/workflows/deploy.yml
         │    Ruby 3.3.5 + Node 20 + Python 3.13 + imagemagick
         │    bundle exec jekyll build → _site/ → purgecss
         ▼
  gh-pages 分支（构建产物，303 文件 / 59.7 MB，含 .nojekyll）
         │
         │  GitHub Pages（发布源 = gh-pages / 根目录）
         │  因有 .nojekyll，原样发布，不再二次处理
         ▼
  https://dds131.github.io/   （HTTPS 强制开启）
```

**关键点**：绝不能让 GitHub Pages 直接构建 `main` 分支。
GitHub 内置 Jekyll 只支持 9 个白名单插件，而 al-folio 依赖 20 余个第三方插件，
直接构建必然失败（本项目实测印证过）。

---

## 七、相关文档

| 文档                   | 位置                                                             |
| ---------------------- | ---------------------------------------------------------------- |
| 备份与版本管理完整说明 | `/workspace/project_files/git_document.md`                       |
| 技术路线与实现方案     | [`docs/01_技术路线与实现方案.md`](docs/01_技术路线与实现方案.md) |
| **源码改动详细清单**   | [`docs/02_源码改动详细清单.md`](docs/02_源码改动详细清单.md)     |
| 部署操作手册           | [`docs/03_部署操作手册.md`](docs/03_部署操作手册.md)             |
| GitHub 官方要求对照    | [`docs/04_GitHub官方要求对照.md`](docs/04_GitHub官方要求对照.md) |
| 问题与排查记录         | [`docs/05_问题与排查记录.md`](docs/05_问题与排查记录.md)         |
| al-folio 上游文档      | 仓库内 `docs/INSTALL.md`、`docs/FAQ.md`、`docs/CONTRIBUTING.md`  |

---

_本文档最后更新：2026-07-30_
