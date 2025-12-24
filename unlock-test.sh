#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.3 终端版（优化版）
# IPv4 / IPv6 分离 + 风险检测 + Adobe/Photoshop检测
# 直接在终端显示，不生成文件，不显示得分和等级
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

  CURL="curl -$STACK -s -L -m 10 -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'"

  IPINFO=$($CURL https://ipinfo.io/json 2>/dev/null)
  IP=$(echo "$IPINFO" | grep '"ip"' | sed 's/.*"ip": "\(.*\)".*/\1/')
  ORG=$(echo "$IPINFO" | grep '"org"' | sed 's/.*"org": "\(.*\)".*/\1/')

  log "IPv$STACK"
  log "  IP: ${IP:-N/A}"
  log "  ASN: ${ORG:-N/A}"

  # ---------- Netflix ----------
  NF_PAGE=$($CURL https://www.netflix.com/title/80018499 2>/dev/null)
  if echo "$NF_PAGE" | grep -q "Watch"; then
      log "  Netflix: 完整"
  elif echo "$NF_PAGE" | grep -q "titleNotAvailable"; then
      log "  Netflix: 仅自制"
  else
      log "  Netflix: 不可用"
  fi

  # ---------- Disney+ ----------
  DIS_PAGE=$($CURL https://www.disneyplus.com 2>/dev/null)
  if echo "$DIS_PAGE" | grep -qi "Disney+"; then
      log "  Disney+: 可用"
  else
      log "  Disney+: 不可用"
  fi

  # ---------- YouTube ----------
  YT_PAGE=$($CURL https://www.youtube.com/premium 2>/dev/null)
  if echo "$YT_PAGE" | grep -q "Premium"; then
      log "  YouTube Premium: 可用"
  else
      log "  YouTube Premium: 未知"
  fi

  # ---------- TikTok ----------
  TT_PAGE=$($CURL https://www.tiktok.com 2>/dev/null)
  if echo "$TT_PAGE" | grep -q "TikTok"; then
      log "  TikTok: 可用"
  else
      log "  TikTok: 不可用"
  fi

  # ---------- ChatGPT ----------
  GPT_PAGE=$($CURL https://chat.openai.com 2>/dev/null)
  if echo "$GPT_PAGE" | grep -q "OpenAI"; then
      log "  ChatGPT: 可用"
  else
      log "  ChatGPT: 异常"
  fi

  # ---------- Firefly ----------
  FF_PAGE=$($CURL https://firefly.adobe.com 2>/dev/null)
  if echo "$FF_PAGE" | grep -q "Adobe Firefly"; then
      log "  Firefly: 可用"
  else
      log "  Firefly: 封锁"
  fi

  # ---------- Adobe / Photoshop ----------
  ADOBE_PAGE=$($CURL https://cc-api-data.adobe.io 2>/dev/null)
  ADOBE_REGION=$(echo "$ADOBE_PAGE" | grep -oP '"country":"\K[A-Z]+' | head -1)
  if [[ -n "$ADOBE_PAGE" ]]; then
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
green "VPS 解锁评估报告 v3.3"
log "主机: $HOST"
log "时间: $DATE"
log ""

# IPv4 / IPv6 检测
check_stack 4
check_stack 6
