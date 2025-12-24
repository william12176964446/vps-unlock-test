#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.1 终端版
# IPv4 / IPv6 分离 + 评分 + 风险评级 + Adobe/Photoshop检测
# =========================================================

SUMMARY="summary.md"
HOST=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

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

  echo "### IPv$STACK"
  echo "IP：$IP"
  echo "ASN：$ORG"

  # ---------- Netflix ----------
  NF=$($CURL -o /dev/null -w "%{http_code}" https://www.netflix.com/title/80018499)
  if [[ "$NF" == "200" || "$NF" == "301" ]]; then
    SCORE=$((SCORE+20))
    echo "Netflix：完整"
  elif [[ "$NF" == "404" ]]; then
    SCORE=$((SCORE+10))
    echo "Netflix：仅自制"
  else
    echo "Netflix：不可用"
  fi

  # ---------- Disney+ ----------
  DIS=$($CURL -I https://www.disneyplus.com | grep -qi unavailable; echo $?)
  if [[ "$DIS" != "0" ]]; then
    SCORE=$((SCORE+10))
    echo "Disney+：可用"
  else
    echo "Disney+：不可用"
  fi

  # ---------- YouTube ----------
  YT=$($CURL https://www.youtube.com/premium | grep -oP '"countryCode":"\K[A-Z]+' | head -1)
  if [[ -n "$YT" ]]; then
    SCORE=$((SCORE+10))
    echo "YouTube Premium：$YT"
  else
    echo "YouTube Premium：未知"
  fi

  # ---------- TikTok ----------
  TT=$($CURL -o /dev/null -w "%{http_code}" https://www.tiktok.com)
  if [[ "$TT" == "200" ]]; then
    SCORE=$((SCORE+5))
    echo "TikTok：可用"
  else
    echo "TikTok：不可用"
  fi

  # ---------- ChatGPT ----------
  GPT=$($CURL -o /dev/null -w "%{http_code}" https://chat.openai.com)
  if [[ "$GPT" == "200" || "$GPT" == "302" ]]; then
    SCORE=$((SCORE+10))
    echo "ChatGPT：可用"
  else
    echo "ChatGPT：异常"
  fi

  # ---------- OpenAI API ----------
  if [ -n "$OPENAI_API_KEY" ]; then
    API=$($CURL -o /dev/null -w "%{http_code}" https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY")
    if [[ "$API" == "200" ]]; then
      SCORE=$((SCORE+15))
      echo "OpenAI API：可用"
    else
      API_BLOCK=1
      echo "OpenAI API：封锁 ($API)"
    fi
  fi

  # ---------- Firefly ----------
  FF=$($CURL -o /dev/null -w "%{http_code}" https://firefly.adobe.com)
  if [[ "$FF" == "200" || "$FF" == "302" ]]; then
    SCORE=$((SCORE+15))
    echo "Firefly：可用"
  else
    echo "Firefly：封锁"
  fi

  # ---------- Adobe / Photoshop ----------
  ADOBE_HEADER=$($CURL -I https://cc-api-data.adobe.io | grep HTTP)
  ADOBE_REGION=$($CURL -s https://cc-api-data.adobe.io | grep -oP '"country":"\K[A-Z]+' | head -1)
  if echo "$ADOBE_HEADER" | grep -q "200"; then
      SCORE=$((SCORE+10))
      echo "Adobe / Photoshop：服务可用（区域：${ADOBE_REGION:-未知}）"
  else
      SCORE=$((SCORE-5))
      echo "Adobe / Photoshop：不可用或封锁"
  fi

  # ---------- ASN 风险 ----------
  if echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DO" >/dev/null; then
    SCORE=$((SCORE-10))
    echo "ASN 风险：数据中心（-10）"
  fi

  # ---------- 等级 ----------
  GRADE="C"
  if [[ "$SCORE" -ge 85 && "$API_BLOCK" -eq 0 ]]; then
    GRADE="A"
  elif [[ "$SCORE" -ge 60 ]]; then
    GRADE="B"
  fi

  echo "得分：$SCORE"
  echo "等级：$GRADE"
  echo ""

  echo "$SCORE|$GRADE"
}

# =========================================================
# 主流程
# =========================================================
echo "========================================="
green "VPS 解锁评估报告 v3.1（终端版）"
echo "主机：$HOST"
echo "时间：$DATE"
echo "========================================="
echo ""

IPV4_RES=$(check_stack 4)
IPV6_RES=$(check_stack 6 2>/dev/null)

IPV4_SCORE=$(echo "$IPV4_RES" | cut -d'|' -f1)
IPV4_GRADE=$(echo "$IPV4_RES" | cut -d'|' -f2)

IPV6_SCORE=$(echo "$IPV6_RES" | cut -d'|' -f1)
IPV6_GRADE=$(echo "$IPV6_RES" | cut -d'|' -f2)

# =========================================================
# 汇总表
# =========================================================
echo "-----------------------------------------"
green "汇总表"
printf "| %-15s | %-8s | %-6s | %-8s | %-6s |\n" "主机" "IPv4分数" "IPv4等级" "IPv6分数" "IPv6等级"
printf "|%-17s|%-10s|%-8s|%-10s|%-8s|\n" "-----------------" "--------" "------" "--------" "------"
printf "| %-15s | %-8s | %-6s | %-8s | %-6s |\n" "$HOST" "$IPV4_SCORE" "$IPV4_GRADE" "${IPV6_SCORE:-N/A}" "${IPV6_GRADE:-N/A}"
echo "-----------------------------------------"
