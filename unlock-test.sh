#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.1 终端版
# IPv4 / IPv6 分离 + 评分 + 风险评级 + Adobe/Photoshop检测
# 直接在终端显示，不生成文件
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
  SCORE=0
  API_BLOCK=0

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
    SCORE=$((SCORE+20))
    log "  Netflix: 完整"
  elif [[ "$NF" == "404" ]]; then
    SCORE=$((SCORE+10))
    log "  Netflix: 仅自制"
  else
    log "  Netflix: 不可用"
  fi

  # ---------- Disney+ ----------
  DIS=$($CURL -I https://www.disneyplus.com 2>/dev/null | grep -qi unavailable; echo $?)
  [[ "$DIS" != "0" ]] && SCORE=$((SCORE+10)) && log "  Disney+: 可用" || log "  Disney+: 不可用"

  # ---------- YouTube ----------
  YT=$($CURL https://www.youtube.com/premium 2>/dev/null | grep -oP '"countryCode":"\K[A-Z]+' | head -1)
  [[ -n "$YT" ]] && SCORE=$((SCORE+10)) && log "  YouTube Premium: $YT" || log "  YouTube Premium: 未知"

  # ---------- TikTok ----------
  TT=$($CURL -o /dev/null -w "%{http_code}" https://www.tiktok.com 2>/dev/null)
  [[ "$TT" == "200" ]] && SCORE=$((SCORE+5)) && log "  TikTok: 可用" || log "  TikTok: 不可用"

  # ---------- ChatGPT ----------
  GPT=$($CURL -o /dev/null -w "%{http_code}" https://chat.openai.com 2>/dev/null)
  [[ "$GPT" == "200" || "$GPT" == "302" ]] && SCORE=$((SCORE+10)) && log "  ChatGPT: 可用" || log "  ChatGPT: 异常"

  # ---------- Firefly ----------
  FF=$($CURL -o /dev/null -w "%{http_code}" https://firefly.adobe.com 2>/dev/null)
  [[ "$FF" == "200" || "$FF" == "302" ]] && SCORE=$((SCORE+15)) && log "  Firefly: 可用" || log "  Firefly: 封锁"

  # ---------- Adobe / Photoshop ----------
  ADOBE_HEADER=$($CURL -I https://cc-api-data.adobe.io 2>/dev/null | grep HTTP)
  ADOBE_REGION=$($CURL -s https://cc-api-data.adobe.io 2>/dev/null | grep -oP '"country":"\K[A-Z]+' | head -1)
  if echo "$ADOBE_HEADER" | grep -q "200"; then
      SCORE=$((SCORE+10))
      log "  Adobe / Photoshop: 服务可用（区域: ${ADOBE_REGION:-未知}）"
  else
      SCORE=$((SCORE-5))
      log "  Adobe / Photoshop: 不可用或封锁"
  fi

  # ---------- ASN 风险 ----------
  if echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DO" >/dev/null; then
    SCORE=$((SCORE-10))
    log "  ASN 风险: 数据中心 (-10)"
  fi

  # ---------- 等级 ----------
  GRADE="C"
  if [[ "$SCORE" -ge 85 && "$API_BLOCK" -eq 0 ]]; then
    GRADE="A"
  elif [[ "$SCORE" -ge 60 ]]; then
    GRADE="B"
  fi

  log " "
  log " "
  log ""

  echo "$SCORE|$GRADE"
}

# =========================================================
# 主流程
# =========================================================
green "VPS 解锁评估报告 v3.1"
log "主机: $HOST"
log "时间: $DATE"
log ""

IPV4_RES=$(check_stack 4)
IPV6_RES=$(check_stack 6)

IPV4_SCORE=$(echo "$IPV4_RES" | cut -d'|' -f1)
# IPV4_GRADE=$(echo "$IPV4_RES" | cut -d'|' -f2)

IPV6_SCORE=$(echo "$IPV6_RES" | cut -d'|' -f1)
# IPV6_GRADE=$(echo "$IPV6_RES" | cut -d'|' -f2)

green "汇总："
log "$IPV4_GRADE"
log "$IPV6_GRADE"
