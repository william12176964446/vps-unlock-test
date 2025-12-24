#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.0
# IPv4 / IPv6 分离 + 评分 + 风险评级 + 汇总
# =========================================================

REPORT="report.md"
SUMMARY="summary.md"
HOST=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

> "$REPORT"

log(){ echo "$1" >> "$REPORT"; }

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }

# =========================================================
# 通用检测函数（IPv4 / IPv6 复用）
# =========================================================
check_stack() {
  STACK="$1"   # 4 or 6
  SCORE=0
  API_BLOCK=0

  CURL="curl -$STACK -s -m 10"

  IPINFO=$($CURL https://ipinfo.io/json)
  IP=$(echo "$IPINFO" | grep '"ip"' | sed 's/.*"ip": "\(.*\)".*/\1/')
  ORG=$(echo "$IPINFO" | grep '"org"' | sed 's/.*"org": "\(.*\)".*/\1/')

  log "### IPv$STACK"
  log "- IP：$IP"
  log "- ASN：$ORG"

  # ---------- Netflix ----------
  NF=$($CURL -o /dev/null -w "%{http_code}" https://www.netflix.com/title/80018499)
  if [[ "$NF" == "200" || "$NF" == "301" ]]; then
    SCORE=$((SCORE+20))
    log "- Netflix：完整"
  elif [[ "$NF" == "404" ]]; then
    SCORE=$((SCORE+10))
    log "- Netflix：仅自制"
  else
    log "- Netflix：不可用"
  fi

  # ---------- Disney+ ----------
  DIS=$($CURL -I https://www.disneyplus.com | grep -qi unavailable; echo $?)
  [[ "$DIS" != "0" ]] && SCORE=$((SCORE+10)) && log "- Disney+：可用" || log "- Disney+：不可用"

  # ---------- YouTube ----------
  YT=$($CURL https://www.youtube.com/premium | grep -oP '"countryCode":"\K[A-Z]+' | head -1)
  [[ -n "$YT" ]] && SCORE=$((SCORE+10)) && log "- YouTube Premium：$YT" || log "- YouTube Premium：未知"

  # ---------- TikTok ----------
  TT=$($CURL -o /dev/null -w "%{http_code}" https://www.tiktok.com)
  [[ "$TT" == "200" ]] && SCORE=$((SCORE+5)) && log "- TikTok：可用" || log "- TikTok：不可用"

  # ---------- ChatGPT ----------
  GPT=$($CURL -o /dev/null -w "%{http_code}" https://chat.openai.com)
  [[ "$GPT" == "200" || "$GPT" == "302" ]] && SCORE=$((SCORE+10)) && log "- ChatGPT：可用" || log "- ChatGPT：异常"

  # ---------- OpenAI API ----------
  if [ -n "$OPENAI_API_KEY" ]; then
    API=$($CURL -o /dev/null -w "%{http_code}" https://api.openai.com/v1/models \
      -H "Authorization: Bearer $OPENAI_API_KEY")
    if [ "$API" == "200" ]; then
      SCORE=$((SCORE+15))
      log "- OpenAI API：可用"
    else
      API_BLOCK=1
      log "- OpenAI API：封锁 ($API)"
    fi
  fi

  # ---------- Firefly ----------
  FF=$($CURL -o /dev/null -w "%{http_code}" https://firefly.adobe.com)
  [[ "$FF" == "200" || "$FF" == "302" ]] && SCORE=$((SCORE+15)) && log "- Firefly：可用" || log "- Firefly：封锁"

  # ---------- ASN 风险 ----------
  if echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DO" >/dev/null; then
    SCORE=$((SCORE-10))
    log "- ASN 风险：数据中心（-10）"
  fi

  # ---------- 等级 ----------
  GRADE="C"
  if [ "$SCORE" -ge 85 ] && [ "$API_BLOCK" -eq 0 ]; then
    GRADE="A"
  elif [ "$SCORE" -ge 60 ]; then
    GRADE="B"
  fi

  log "- 得分：$SCORE"
  log "- 等级：$GRADE"
  log ""

  echo "$SCORE|$GRADE"
}

# =========================================================
# 主流程
# =========================================================
log "# VPS 解锁评估报告 v3.0"
log "- 主机：$HOST"
log "- 时间：$DATE"
log ""

IPV4_RES=$(check_stack 4)
IPV6_RES=$(check_stack 6 2>/dev/null)

IPV4_SCORE=$(echo "$IPV4_RES" | cut -d'|' -f1)
IPV4_GRADE=$(echo "$IPV4_RES" | cut -d'|' -f2)

IPV6_SCORE=$(echo "$IPV6_RES" | cut -d'|' -f1)
IPV6_GRADE=$(echo "$IPV6_RES" | cut -d'|' -f2)

# =========================================================
# 汇总表
# =========================================================
if [ ! -f "$SUMMARY" ]; then
  echo "| 主机 | IPv4 分数 | IPv4 等级 | IPv6 分数 | IPv6 等级 |" > "$SUMMARY"
  echo "|----|----|----|----|----|" >> "$SUMMARY"
fi

echo "| $HOST | $IPV4_SCORE | $IPV4_GRADE | ${IPV6_SCORE:-N/A} | ${IPV6_GRADE:-N/A} |" >> "$SUMMARY"

green "测试完成"
echo "报告：$REPORT"
echo "汇总：$SUMMARY"
