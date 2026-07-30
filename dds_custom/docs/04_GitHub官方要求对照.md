# GitHub 官方要求逐条对照

> 核对日期：2026-07-30
> 核对对象：`dds131/dds131.github.io` → <https://dds131.github.io/>

---

## 参考的官方文档

| 文档 | 地址 |
| --- | --- |
| About GitHub Pages | <https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages> |
| Configuring a publishing source | <https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site> |
| GitHub Pages limits | <https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits> |
| About GitHub Pages and Jekyll | <https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll> |

---

## 一、站点类型与命名规则

**官方规定**

> 用户/组织站点需要「a repository named `<owner>.github.io`, where `<owner>` is the personal or organization account name」
> 默认地址：用户/组织站 `http(s)://<owner>.github.io`；项目站 `http(s)://<owner>.github.io/<repositoryname>`
> 「Maximum of one pages site per account」（用户/组织站每账号最多一个）

**本项目对照**

| 项 | 值 | 结论 |
| --- | --- | --- |
| 账号名 | `dds131` | —— |
| 仓库名 | `dds131.github.io` | ✅ 精确等于 `<owner>.github.io` |
| 判定类型 | 用户主页站 | ✅ |
| `_config.yml` `url` | `https://dds131.github.io` | ✅ |
| `_config.yml` `baseurl` | 留空 | ✅ 主页站根路径为 `/` |
| 实际地址 | <https://dds131.github.io/> | ✅ |

**曾排除的陷阱**：最初的候选仓库 `dds131/dds-1-github.github.io` 虽然名字以 `.github.io` 结尾，但前缀 `dds-1-github` ≠ 用户名 `dds131`，会被判定为**项目站**，实际地址是 `https://dds131.github.io/dds-1-github.github.io/`，且 `baseurl` 必须填写。已改用正确的仓库。

---

## 二、使用限制

**官方规定**

> 「GitHub Pages source repositories have a recommended limit of 1 GB.」
> 「Published GitHub Pages sites may be no larger than 1 GB.」
> 「GitHub Pages sites have a *soft* bandwidth limit of 100 GB per month.」
> 「GitHub Pages sites have a *soft* limit of 10 builds per hour.」

**本项目对照**

| 官方限制 | 上限 | 实测值 | 余量 | 结论 |
| --- | --- | --- | --- | --- |
| 源仓库大小 | 建议 ≤ 1 GB | 约 355 MB（含 1096 个 commit 的上游完整历史） | 64% | ✅ |
| 发布站点大小 | ≤ 1 GB（硬限） | **59.7 MB**（303 个文件） | 94% | ✅ |
| 月带宽 | 100 GB（软限） | 个人主页，量级远低于此 | —— | ✅ |
| 每小时构建次数 | 10 次（软限） | 2026-07-30 当天共 4 次 | —— | ✅ |

发布产物中最大的几个文件（均为 al-folio 官方 demo 素材）：

| 大小 | 文件 |
| --- | --- |
| 24.79 MB | `assets/video/tutorial_al_folio.mp4` |
| 13.72 MB | `assets/img/prof_pic_color.png` |
| 4.04 MB | `assets/plotly/demo.html` |
| 2.20 MB | `assets/img/prof_pic.jpg` |
| 1.57 MB | `assets/img/rhino.png` |

> **提示**：这几个 demo 素材占了发布体积的约 78%。若将来要压缩站点体积，替换或删除它们收益最大。当前远未触及限制，无需处理。

---

## 三、禁止用途

**官方规定**

GitHub Pages 不得用于：
1. 运营商业业务或电商站点
2. 提供商业 SaaS 服务
3. 处理敏感金融数据 —— 「GitHub Pages sites shouldn't be used for sensitive transactions like sending passwords or credit card numbers.」
4. 「get-rich-quick schemes, sexually obscene content, and violent or threatening content or activity」

**本项目对照**

| 项 | 结论 |
| --- | --- |
| 站点性质 | 个人学术主页（al-folio 官方 demo 内容） | ✅ 合规 |
| 是否有商业交易 | 无 | ✅ |
| 是否收集敏感数据 | 无表单、无支付、无登录 | ✅ |
| 内容合规性 | 官方 demo 内容 | ✅ |

---

## 四、发布源配置

**官方规定**

> 「The source branch can be any branch in your repository.」
> 文件夹可选根目录 `/` 或 `/docs`
> 外部 CI 通常「committing the build output to the `gh-pages` branch」并且「include a `.nojekyll` file」，
> 此时 GitHub Actions「will detect the state that the branch does not need a build step」，直接进入部署。
> 「Commits from workflows using `GITHUB_TOKEN` don't trigger builds」

**本项目对照**

| 项 | 值 | 结论 |
| --- | --- | --- |
| 发布源分支 | `gh-pages` | ✅ |
| 发布源目录 | `/`（根目录） | ✅ |
| 构建方式 | 外部 CI（GitHub Actions `deploy.yml`）构建后推产物到 `gh-pages` | ✅ 符合官方描述的标准模式 |
| `.nojekyll` | **已补齐** | ✅ 见下节 |
| HTTPS 强制 | `https_enforced: true` | ✅ |

---

## 五、Jekyll 处理规则与 `.nojekyll` —— 本次发现并修正的不合规项

**官方规定**

> GitHub Pages 默认会用 Jekyll 处理站点。默认启用 9 个插件且不可禁用：
> `jekyll-coffeescript`、`jekyll-default-layout`、`jekyll-gist`、`jekyll-github-metadata`、
> `jekyll-optional-front-matter`、`jekyll-paginate`、`jekyll-readme-index`、
> `jekyll-titles-from-headings`、`jekyll-relative-links`
>
> 「GitHub Pages cannot build sites using unsupported plugins.」
>
> 「By default, Jekyll doesn't build files or folders that... Start with `_`, `.`, or `#`」

### 5.1 推论一：绝不能让 Pages 直接构建 `main` 分支

al-folio 依赖 `jekyll-scholar`、`jekyll-imagemagick`、`jekyll-minifier`、`jekyll-paginate-v2`、
`jekyll-toc`、`jekyll-jupyter-notebook` 等 20 余个插件，**全部不在白名单内**。

**实测印证**：在把发布源设为 `main` 分支的阶段，`pages build and deployment #2` 构建**失败**。
切换到 `gh-pages` 后 `#3`、`#4` 均成功。

✅ 已通过「发布源 = `gh-pages`（构建产物）」规避。

### 5.2 推论二：`gh-pages` 上必须有 `.nojekyll`（本次修正）

| 阶段 | 情况 |
| --- | --- |
| **发现问题** | `gh-pages` 分支上没有 `.nojekyll`，而 Pages 的 `build_type` 是 `legacy`，意味着 GitHub 会对**已经构建好的产物**再跑一遍内置 Jekyll |
| **问题实证** | al-folio 的构建产物根目录含 `_pages/`（下划线开头）。按官方规则会被丢弃。实测 `https://dds131.github.io/_pages/dropdown/` 返回 **404** |
| **上游线索** | al-folio 的 `_config.yml` 第 243-245 行本就有 `keep_files: [CNAME, .nojekyll]`，说明上游**预期该文件存在**并保护它不被清理，但仓库里从未真正创建过（`find . -name .nojekyll` 结果为空）。这是 al-folio 自身的一个缺口 |
| **修正做法** | ① 仓库根目录新建空文件 `.nojekyll`；② `_config.yml` 的 `include: ["_pages"]` → `include: ["_pages", ".nojekyll"]`（必需，否则 Jekyll 不会把点开头文件复制进 `_site`） |
| **修正验证** | `https://dds131.github.io/_pages/dropdown/` 从 **404 → 200**；`/.nojekyll` 返回 200；全站 20 项回归测试 **0 失败** |

### 5.3 附带收益：解决 Pages 不自动刷新的问题

官方明确写明「Commits from workflows using `GITHUB_TOKEN` don't trigger builds」。

`deploy.yml` 使用 `GITHUB_TOKEN` 把产物推到 `gh-pages`，因此 Pages 构建可能不会被自动触发。
本项目在补齐 `.nojekyll` 之前，确实需要手动 `POST /pages/builds` 才能让站点更新。

带上 `.nojekyll` 后，GitHub 识别出该分支无需构建步骤，直接进入部署，流程更快也更可靠。
补齐后的那次推送实测**自动触发**了 `Deploy site #2` 与 `pages build and deployment #4`，均成功。

---

## 六、最终合规性结论

| # | 官方要求 | 结论 |
| --- | --- | --- |
| 1 | 用户站仓库名必须为 `<owner>.github.io` | ✅ |
| 2 | `url` / `baseurl` 与站点类型匹配 | ✅ |
| 3 | 源仓库 ≤ 1 GB（建议） | ✅ 355 MB |
| 4 | 发布站点 ≤ 1 GB（硬限） | ✅ 59.7 MB |
| 5 | 带宽 ≤ 100 GB/月（软限） | ✅ |
| 6 | 构建 ≤ 10 次/小时（软限） | ✅ |
| 7 | 不用于商业/SaaS/敏感交易/违规内容 | ✅ |
| 8 | 发布源分支与目录合法 | ✅ `gh-pages` + `/` |
| 9 | 不使用 Pages 不支持的插件构建 | ✅ 改用 Actions 外部构建 |
| 10 | 外部 CI 发布应含 `.nojekyll` | ✅ **本次修正** |
| 11 | HTTPS | ✅ `https_enforced: true` |

**全部 11 项合规。**

---

## 七、遗留的非合规性问题（不影响站点）

| 项 | 说明 | 处理建议 |
| --- | --- | --- |
| `Lighthouse Badger` workflow 失败 | 上游可选的性能评分徽章工具，需要仓库 secret `LIGHTHOUSE_BADGER_TOKEN`，未配置故在 `actions/checkout` 步骤失败 | 与网站本身无关。要么配置该 secret，要么禁用该 workflow。本项目按「最小改动」原则未处理 |
| 仓库 Secret Scanning 未开启 | GitHub 的凭据泄漏检测未启用 | 建议开启 Secret Scanning + Push Protection，可防止将来误提交凭据。属于纯防护性设置，不改代码 |
