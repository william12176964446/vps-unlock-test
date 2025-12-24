#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.2 终端版
# IPv4 / IPv6 分离 + 风险检测 + Adobe/Photoshop检测
# =========================================================

HOST=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }

log(){ echo "$1"; }

# =========================================================
# 通用检测函数（IPv4 / IPv6 复用）
# =========================================================
check_stack() {
  STACK="$1"   # 4 or 6

  CURL="curl -$STACK -s -m 10"

  IPINFO=$($CURL https://ipinfo.io/json 2>/dev/null)
  IP=$(echo "$IPINFO" | grep '"ip"' | sed 's/.*"ip": "\(.*\)".*/\1/')
  ORG=$(echo "$IPINFO" | grep '"org"' | sed 's/.*"org": "\(.*\)".*/\1/')

  log "IPv$STACK"
  log "  IP: ${IP:-N/A}"
  log "  ASN: ${ORG:-N/A}"

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
  if echo "$YT_PAGE" | grep -q "Premium"; then
      log "  YouTube Premium: 可用"
  else
      log "  YouTube Premium: 未知"
  fi

  # ---------- TikTok（改进检测） ----------
  TT_CONTENT=$($CURL -L https://www.tiktok.com 2>/dev/null)
  if [[ -n "$TT_CONTENT" ]] && echo "$TT_CONTENT" | grep -q "TikTok"; then
      log "  TikTok: 可用"
  else
      log "  TikTok: 不可用"
  fi

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
  if echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DO" >/dev/null; then
    log "  ASN 风险: 数据中心"
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

# IPv4 / IPv6 检测
check_stack 4
check_stack 6
