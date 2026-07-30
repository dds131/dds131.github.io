#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 00_env_proxy.sh —— 设置容器内访问 GitHub 所需的网络代理环境变量
#
# 用途 : 容器继承宿主机网络，通过局域网内的 clash 反向代理访问 GitHub。
# 用法 : source /workspace/project_files/dds_web_projection_1/al-folio/dds_custom/scripts/00_env_proxy.sh
# 注意 : 必须用 source 执行，直接 bash 执行不会影响当前 shell。
# ---------------------------------------------------------------------------

export PROXY_URL="${PROXY_URL:-http://192.168.2.144:7897}"

export HTTP_PROXY="${PROXY_URL}"
export HTTPS_PROXY="${PROXY_URL}"
export http_proxy="${PROXY_URL}"
export https_proxy="${PROXY_URL}"

# 局域网与本机地址不走代理
export NO_PROXY="localhost,127.0.0.1,::1"
export no_proxy="${NO_PROXY}"

echo "[00_env_proxy] 代理已设置: ${PROXY_URL}"
