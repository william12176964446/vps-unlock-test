#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.2 终端版
# IPv4 / IPv6 分离 + 手动输入 IP（可回车）
# =========================================================

HOST=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }

log(){ echo "$1"; }

# =========================================================
# 读取用户输入 IP（可直接回车）
# =========================================================
read -p "请输入 IPv4 地址（直接回车则使用当前 VPS IPv4）: " IPV4_INPUT
read -p "请输入 IPv6 地址（直接回车则使用当前 VPS IPv6）: " IPV6_INPUT

# =========================================================
# IP 信息查询（支持指定 IP 或本机）
# =========================================================
get_ipinfo() {
  if [[ -n "$1" ]]; then
    curl -s "https://ipinfo.io/$1/json"
  else
    curl -s "https://ipinfo.io/json"
  fi
}

# =========================================================
# 通用检测函数
# 参数1：4 / 6
# 参数2：手动输入 IP（可为空）
# =========================================================
check_stack() {
  STACK="$1"
  INPUT_IP="$2"

  CURL="curl -$STACK -s -m 10"

  IPINFO=$(get_ipinfo "$INPUT_IP")
  IP=$(echo "$IPINFO" | grep '"ip"' | sed 's/.*"ip": "\(.*\)".*/\1/')
  ORG=$(echo "$IPINFO" | grep '"org"' | sed 's/.*"org": "\(.*\)".*/\1/')
  COUNTRY=$(echo "$IPINFO" | grep '"country"' | sed 's/.*"country": "\(.*\)".*/\1/')

  log "IPv$STACK"
  log "  IP: ${IP:-N/A}"
  log "  ASN: ${ORG:-N/A}"
  log "  国家: ${COUNTRY:-N/A}"

  if [[ -n "$INPUT_IP" ]]; then
    yellow "  注意：此 IP 仅用于信息展示与风险判断"
    yellow "        解锁检测仍基于当前 VPS 出口"
  fi

  # ---------- Netflix ----------
  NF=$($CURL -o /dev/null -w "%{http_code}" https://www.netflix.com/title/80018499 2>/dev/null)
  if [[ "$NF" == "200" || "$NF" == "301" ]]; then
    log "  Netflix: 完整"
  elif [[ "$NF" == "404" ]]; then
    log "  Netflix: 仅自制"
  else
    log "  Netflix: 不可用"
  fi

  # ---------- Disney+ ----------
  DIS=$($CURL -I https://www.disneyplus.com 2>/dev/null | grep -qi unavailable; echo $?)
  [[ "$DIS" != "0" ]] && log "  Disney+: 可用" || log "  Disney+: 不可用"

  # ---------- YouTube ----------
  YT_PAGE=$($CURL https://www.youtube.com/premium 2>/dev/null)
  echo "$YT_PAGE" | grep -q "Premium" && log "  YouTube Premium: 可用" || log "  YouTube Premium: 未知"

  # ---------- TikTok ----------
  TT_CONTENT=$($CURL -L https://www.tiktok.com 2>/dev/null)
  echo "$TT_CONTENT" | grep -q "TikTok" && log "  TikTok: 可用" || log "  TikTok: 不可用"

  # ---------- ChatGPT ----------
  GPT=$($CURL -o /dev/null -w "%{http_code}" https://chat.openai.com 2>/dev/null)
  [[ "$GPT" == "200" || "$GPT" == "302" ]] && log "  ChatGPT: 可用" || log "  ChatGPT: 未知"

  # ---------- Firefly ----------
  FF=$($CURL -o /dev/null -w "%{http_code}" https://firefly.adobe.com 2>/dev/null)
  [[ "$FF" == "200" || "$FF" == "302" ]] && log "  Firefly: 可用" || log "  Firefly: 封锁"

  # ---------- Adobe / Photoshop ----------
  ADOBE_HEADER=$($CURL -I https://cc-api-data.adobe.io 2>/dev/null | grep HTTP)
  ADOBE_REGION=$($CURL -s https://cc-api-data.adobe.io 2>/dev/null | grep -oP '"country":"\K[A-Z]+' | head -1)
  if echo "$ADOBE_HEADER" | grep -q "200"; then
    log "  Adobe / Photoshop: 服务可用（区域: ${ADOBE_REGION:-未知}）"
  else
    log "  Adobe / Photoshop: 不可用或封锁"
  fi

  # ---------- ASN 风险 ----------
  if echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DO|DigitalOcean" >/dev/null; then
    yellow "  ASN 风险: 数据中心 IP"
  fi

  log ""
}

# =========================================================
# 主流程
# =========================================================
green "VPS 解锁评估报告 v3.2"
log "主机: $HOST"
log "时间: $DATE"
log ""

check_stack 4 "$IPV4_INPUT"
check_stack 6 "$IPV6_INPUT"
