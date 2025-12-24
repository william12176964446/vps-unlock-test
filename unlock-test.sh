#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v3.3 终端版
# IPv4 / IPv6 横向展示 + 评分 + 风险评级 + Adobe/Photoshop检测
# =========================================================

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }

declare -A VPS_SUMMARY

# =========================================================
# 通用检测函数（IPv4 / IPv6）
# =========================================================
check_stack() {
  HOST="$1"
  STACK="$2"   # 4 or 6
  SCORE=0
  API_BLOCK=0
  CURL="curl -$STACK -s -m 10"

  IPINFO=$($CURL https://ipinfo.io/json 2>/dev/null)
  IP=$(echo "$IPINFO" | grep '"ip"' | sed 's/.*"ip": "\(.*\)".*/\1/')
  ORG=$(echo "$IPINFO" | grep '"org"' | sed 's/.*"org": "\(.*\)".*/\1/')

  # ---------- 检测项目 ----------
  NF=$($CURL -o /dev/null -w "%{http_code}" https://www.netflix.com/title/80018499 2>/dev/null)
  if [[ "$NF" == "200" || "$NF" == "301" ]]; then NF_RES="完整"; SCORE=$((SCORE+20))
  elif [[ "$NF" == "404" ]]; then NF_RES="仅自制"; SCORE=$((SCORE+10))
  else NF_RES="不可用"; fi

  DIS=$($CURL -I https://www.disneyplus.com 2>/dev/null | grep -qi unavailable; echo $?)
  [[ "$DIS" != "0" ]] && DIS_RES="可用" && SCORE=$((SCORE+10)) || DIS_RES="不可用"

  YT=$($CURL https://www.youtube.com/premium 2>/dev/null | grep -oP '"countryCode":"\K[A-Z]+' | head -1)
  [[ -n "$YT" ]] && YT_RES="$YT" && SCORE=$((SCORE+10)) || YT_RES="未知"

  TT=$($CURL -o /dev/null -w "%{http_code}" https://www.tiktok.com 2>/dev/null)
  [[ "$TT" == "200" ]] && TT_RES="可用" && SCORE=$((SCORE+5)) || TT_RES="不可用"

  GPT=$($CURL -o /dev/null -w "%{http_code}" https://chat.openai.com 2>/dev/null)
  [[ "$GPT" == "200" || "$GPT" == "302" ]] && GPT_RES="可用" && SCORE=$((SCORE+10)) || GPT_RES="异常"

  FF=$($CURL -o /dev/null -w "%{http_code}" https://firefly.adobe.com 2>/dev/null)
  [[ "$FF" == "200" || "$FF" == "302" ]] && FF_RES="可用" && SCORE=$((SCORE+15)) || FF_RES="封锁"

  ADOBE_HEADER=$($CURL -I https://cc-api-data.adobe.io 2>/dev/null | grep HTTP)
  ADOBE_REGION=$($CURL -s https://cc-api-data.adobe.io 2>/dev/null | grep -oP '"country":"\K[A-Z]+' | head -1)
  if echo "$ADOBE_HEADER" | grep -q "200"; then
      ADOBE_RES="服务可用(${ADOBE_REGION:-未知})"
      SCORE=$((SCORE+10))
  else
      ADOBE_RES="不可用或封锁"
      SCORE=$((SCORE-5))
  fi

  if echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DO" >/dev/null; then
    SCORE=$((SCORE-10))
    ASN_RISK="是"
  else
    ASN_RISK="否"
  fi

  # 等级
  GRADE="C"
  if [[ "$SCORE" -ge 85 && "$API_BLOCK" -eq 0 ]]; then GRADE="A"
  elif [[ "$SCORE" -ge 60 ]]; then GRADE="B"; fi

  # 保存结果
  VPS_SUMMARY["$HOST|IPv$STACK"]="$IP|$ORG|$NF_RES|$DIS_RES|$YT_RES|$TT_RES|$GPT_RES|$FF_RES|$ADOBE_RES|$SCORE|$GRADE|$ASN_RISK"
}

# =========================================================
# 多 VPS 配置
# =========================================================
VPS_LIST=("localhost")  # 可自行增加 VPS 列表

for VPS in "${VPS_LIST[@]}"; do
  check_stack "$VPS" 4
  check_stack "$VPS" 6
done

# =========================================================
# 打印整齐汇总表（IPv4/IPv6横向展示）
# =========================================================
echo "=================================================================================================================================="
green "VPS 解锁评估汇总表（IPv4/IPv6横向展示）"
printf "| %-15s | %-15s | %-10s | %-8s | %-8s | %-6s | %-6s | %-6s | %-18s | %-5s | %-5s | %-5s | %-15s | %-10s | %-8s | %-8s | %-6s | %-6s | %-6s | %-18s | %-5s | %-5s | %-5s |\n" \
"主机" "IPv4 IP" "IPv4 ASN" "NF" "DIS" "YT" "TT" "GPT" "FF/Adobe" "Score" "Grade" "ASN风险" \
"IPv6 IP" "IPv6 ASN" "NF" "DIS" "YT" "TT" "GPT" "FF/Adobe" "Score" "Grade" "ASN风险"
echo "|-----------------|-----------------|----------|--------|--------|------|------|------|------------------|-------|------|--------|-----------------|----------|--------|--------|------|------|------|------------------|-------|------|--------|"

for VPS in "${VPS_LIST[@]}"; do
    KEY4="$VPS|IPv4"
    VALUE4=${VPS_SUMMARY[$KEY4]}
    IFS='|' read -r IP4 ORG4 NF4 DIS4 YT4 TT4 GPT4 FF4 ADOBE4 SCORE4 GRADE4 ASN_RISK4 <<< "$VALUE4"

    KEY6="$VPS|IPv6"
    VALUE6=${VPS_SUMMARY[$KEY6]}
    IFS='|' read -r IP6 ORG6 NF6 DIS6 YT6 TT6 GPT6 FF6 ADOBE6 SCORE6 GRADE6 ASN_RISK6 <<< "$VALUE6"

    printf "| %-15s | %-15s | %-10s | %-8s | %-8s | %-6s | %-6s | %-6s | %-18s | %-5s | %-5s | %-5s | %-15s | %-10s | %-8s | %-8s | %-6s | %-6s | %-6s | %-18s | %-5s | %-5s | %-5s |\n" \
    "$VPS" "$IP4" "$ORG4" "$NF4" "$DIS4" "$YT4" "$TT4" "$GPT4" "$FF4/$ADOBE4" "$SCORE4" "$GRADE4" "$ASN_RISK4" \
    "$IP6" "$ORG6" "$NF6" "$DIS6" "$YT6" "$TT6" "$GPT6" "$FF6/$ADOBE6" "$SCORE6" "$GRADE6" "$ASN_RISK6"
done
echo "=================================================================================================================================="
