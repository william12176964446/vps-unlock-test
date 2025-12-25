#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.3 终端版
# 支持：IPv4 / IPv6 分离 + 手动输入 IP 检测
# =========================================================

HOST=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

IPV4_INPUT="$1"
IPV6_INPUT="$2"

green(){ echo -e "\033[32m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }

log(){ echo "$1"; }

# =========================================================
# IP 信息查询（支持指定 IP）
# =========================================================
get_ipinfo() {
  local IP="$1"
  if [[ -n "$IP" ]]; then
    curl -s "https://ipinfo.io/$IP/json"
  else
    curl -s "https://ipinfo.io/json"
  fi
}

# =========================================================
# 通用检测函数
# 参数1：4 / 6
# 参数2：手动指定 IP（可空）
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
    yellow "  ⚠ 手动指定 IP，仅用于信息与风险判断"
    yellow "    实际解锁检测基于当前 VPS 出口"
  fi

  # ---------- Netflix ----------
  NF=$($CURL -o /dev/null -w "%{http_code}" https://www.netflix.com/title/80018499 2>/dev/null)
  [[ "$NF" == "200" || "$NF" == "301" ]] && log "  Netflix: 完整" \
    || [[ "$NF" == "404" ]] && log "  Netflix: 仅自制" \
    || log "  Netflix: 不可用"

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

  # ---------- Adobe / Firefly ----------
  FF=$($CURL -o /dev/null -w "%{http_code}" https://firefly.adobe.com 2>/dev/null)
  [[ "$FF" == "200" || "$FF" == "302" ]] && log "  Firefly: 可用" || log "  Firefly: 封锁"

  ADOBE_HEADER=$($CURL -I https://cc-api-data.adobe.io 2>/dev/null | grep HTTP)
  ADOBE_REGION=$($CURL -s https://cc-api-data.adobe.io 2>/dev/null | grep -oP '"country":"\K[A-Z]+' | head -1)
  echo "$ADOBE_HEADER" | grep -q "200" \
    && log "  Adobe / Photoshop: 可用（区域: ${ADOBE_REGION:-未知}）" \
    || log "  Adobe / Photoshop: 不可用"

  # ---------- ASN 风险 ----------
  echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DigitalOcean|DO" >/dev/null \
    && yellow "  ASN 风险: 数据中心 IP"

  log ""
}

# =========================================================
# 主流程
# =========================================================
green "VPS 解锁评估报告 v3.3"
log "主机: $HOST"
log "时间: $DATE"
log ""

check_stack 4 "$IPV4_INPUT"
check_stack 6 "$IPV6_INPUT"
