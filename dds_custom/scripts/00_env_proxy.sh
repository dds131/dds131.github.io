#!/usr/bin/env bash
# =============================================================================
# 00_env_proxy.sh —— 设置容器内访问 GitHub 所需的网络代理环境变量
# =============================================================================
#
# 【目的】
#   容器内需要访问 github.com / api.github.com / codeload.github.com，
#   但这些域名在当前网络环境下无法直连。本脚本统一设置代理环境变量，
#   让 curl、git、npm 等所有遵循标准代理变量的工具都能正常联网。
#
# 【解决了什么问题】
#   如果不设置代理，会看到这类错误：
#     fatal: unable to access 'https://github.com/...': Failed to connect
#     curl: (28) Connection timed out after 30000 milliseconds
#
# 【网络拓扑】
#   容器  --(--network host，与宿主机共享网络栈)-->  宿主机 192.168.2.122
#         --(局域网)-->  clash 代理 192.168.2.144:7897  --> 互联网 --> GitHub
#   容器用 --network host 启动，直接继承宿主机网络，因此可以访问局域网内的 clash。
#
# 【使用方法】
#   必须用 source（或 .）执行，让变量进入当前 shell：
#     source /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/00_env_proxy.sh
#
#   ⚠️ 错误用法：bash 00_env_proxy.sh
#      直接 bash 执行会开一个子进程，变量只在子进程里生效，
#      子进程一退出变量就没了，当前 shell 完全不受影响。
#
# 【自定义代理地址】
#   PROXY_URL=http://其他地址:端口 source 00_env_proxy.sh
#   脚本用 ${PROXY_URL:-默认值} 的写法，外部已设置时优先用外部的值。
#
# 【验证代理是否生效】
#   curl -s -o /dev/null -w "%{http_code}\n" -m 25 https://github.com
#   期望输出 200。
#
# 【实测性能】2026-07-30
#   下行约 9.5 MB/s；git push 上行约 20 MB/s。
#
# 【回退】
#   不需要回退。本脚本只设置环境变量，不修改任何文件。
#   要取消代理，直接 unset 相关变量，或退出当前 shell 重新进入：
#     unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy
# =============================================================================

# 代理地址。用 ${VAR:-默认值} 语法：若调用者已在外部设置 PROXY_URL 则沿用，
# 否则使用局域网内 clash 的地址。这样脚本既有默认值又可被覆盖。
export PROXY_URL="${PROXY_URL:-http://192.168.2.144:7897}"

# 同时设置大写和小写两套变量。
# 原因：不同工具读取的变量名大小写不一致 ——
#   curl / wget 认小写 http_proxy、https_proxy
#   git / 部分 Ruby 和 Node 工具认大写 HTTP_PROXY、HTTPS_PROXY
# 两套都设置，覆盖面最广，避免"有的工具能联网、有的不能"的诡异情况。
export HTTP_PROXY="${PROXY_URL}"    # HTTP 请求走代理（大写）
export HTTPS_PROXY="${PROXY_URL}"   # HTTPS 请求走代理（大写）
export http_proxy="${PROXY_URL}"    # HTTP 请求走代理（小写）
export https_proxy="${PROXY_URL}"   # HTTPS 请求走代理（小写）

# 例外清单：访问本机地址时不走代理。
# 如果不设置这一项，访问 localhost 也会被转发给 192.168.2.144，
# 而那台机器上并没有对应服务，会导致本地回环请求失败。
# 典型场景：jekyll serve 起在 127.0.0.1:4000 时的本地预览。
export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="${NO_PROXY}"

# 打印确认信息，便于在长命令链中确认这一步确实执行了。
echo "[00_env_proxy] 代理已设置: ${PROXY_URL}"
