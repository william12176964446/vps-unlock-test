#!/bin/bash

# =========================================================
# VPS 解锁 & 质量评估脚本 v4.0
# 多 VPS 自动对比 + 综合评分 + HTML 榜单
# =========================================================

VPS_LIST="vps_list.txt"
HTML_OUT="vps_ranking.html"

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }

# =========================================================
# 检测函数（IPv4 / IPv6）
# =========================================================
check_stack() {
  SSH_CMD="$1"
  STACK="$2"   # 4 or 6
  SCORE=0
  API_BLOCK=0

  CURL="curl -$STACK -s -m 10 --connect-timeout 5"

  # IP信息
  IPINFO=$($SSH_CMD "$CURL https://ipinfo.io/json")
  IP=$(echo "$IPINFO" | grep '"ip"' | sed 's/.*"ip": "\(.*\)".*/\1/')
  ORG=$(echo "$IPINFO" | grep '"org"' | sed 's/.*"org": "\(.*\)".*/\1/')

  LOG="IPv$STACK: IP=$IP, ASN=$ORG"

  # Netflix
  NF=$($SSH_CMD "$CURL -o /dev/null -w '%{http_code}' https://www.netflix.com/title/80018499")
  if [[ "$NF" == "200" || "$NF" == "301" ]]; then
    SCORE=$((SCORE+20)); LOG="$LOG; Netflix=完整"
  elif [[ "$NF" == "404" ]]; then
    SCORE=$((SCORE+10)); LOG="$LOG; Netflix=仅自制"
  else
    LOG="$LOG; Netflix=不可用"
  fi

  # Disney+
  DIS=$($SSH_CMD "$CURL -I https://www.disneyplus.com | grep -qi unavailable; echo $?")
  if [[ "$DIS" != "0" ]]; then
    SCORE=$((SCORE+10)); LOG="$LOG; Disney+=可用"
  else
    LOG="$LOG; Disney+=不可用"
  fi

  # YouTube Premium
  YT=$($SSH_CMD "$CURL https://www.youtube.com/premium | grep -oP '\"countryCode\":\"\K[A-Z]+' | head -1")
  [[ -n "$YT" ]] && SCORE=$((SCORE+10)) && LOG="$LOG; YouTube=$YT" || LOG="$LOG; YouTube=未知"

  # TikTok
  TT=$($SSH_CMD "$CURL -o /dev/null -w '%{http_code}' https://www.tiktok.com")
  [[ "$TT" == "200" ]] && SCORE=$((SCORE+5)) && LOG="$LOG; TikTok=可用" || LOG="$LOG; TikTok=不可用"

  # ChatGPT
  GPT=$($SSH_CMD "$CURL -o /dev/null -w '%{http_code}' https://chat.openai.com")
  [[ "$GPT" == "200" || "$GPT" == "302" ]] && SCORE=$((SCORE+10)) && LOG="$LOG; ChatGPT=可用" || LOG="$LOG; ChatGPT=异常"

  # OpenAI API
  if [ -n "$OPENAI_API_KEY" ]; then
    API=$($SSH_CMD "$CURL -o /dev/null -w '%{http_code}' https://api.openai.com/v1/models -H \"Authorization: Bearer $OPENAI_API_KEY\"")
    if [[ "$API" == "200" ]]; then
      SCORE=$((SCORE+15)); LOG="$LOG; OpenAI API=可用"
    else
      API_BLOCK=1; LOG="$LOG; OpenAI API=封锁($API)"
    fi
  fi

  # Firefly
  FF=$($SSH_CMD "$CURL -o /dev/null -w '%{http_code}' https://firefly.adobe.com")
  [[ "$FF" == "200" || "$FF" == "302" ]] && SCORE=$((SCORE+15)) && LOG="$LOG; Firefly=可用" || LOG="$LOG; Firefly=封锁"

  # Adobe / Photoshop
  ADOBE_HEADER=$($SSH_CMD "$CURL -I https://cc-api-data.adobe.io | grep HTTP")
  ADOBE_REGION=$($SSH_CMD "$CURL -s https://cc-api-data.adobe.io | grep -oP '\"country\":\"\K[A-Z]+' | head -1")
  if echo "$ADOBE_HEADER" | grep -q "200"; then
      SCORE=$((SCORE+10)); LOG="$LOG; Adobe/Photoshop=${ADOBE_REGION:-未知}"
  else
      SCORE=$((SCORE-5)); LOG="$LOG; Adobe/Photoshop=不可用"
  fi

  # ASN 风险
  if echo "$ORG" | grep -Ei "AWS|Google|Azure|OVH|Hetzner|Linode|Vultr|DO" >/dev/null; then
    SCORE=$((SCORE-10)); LOG="$LOG; ASN风险=数据中心(-10)"
  fi

  # 等级
  GRADE="C"
  if [[ "$SCORE" -ge 85 && "$API_BLOCK" -eq 0 ]]; then
    GRADE="A"
  elif [[ "$SCORE" -ge 60 ]]; then
    GRADE="B"
  fi

  echo "$SCORE|$GRADE|$LOG"
}

# =========================================================
# 主流程：多 VPS
# =========================================================

# HTML 初始化
cat > "$HTML_OUT" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>VPS 网络质量评测榜单 v4.0</title>
<style>
body{font-family:sans-serif;margin:20px;background:#f9fafb;color:#111}
table{border-collapse:collapse;width:100%;background:#fff}
th,td{padding:8px 10px;border:1px solid #e5e7eb;text-align:left}
th{background:#f3f4f6}
.grade-A{color:#16a34a;font-weight:bold}
.grade-B{color:#ca8a04;font-weight:bold}
.grade-C{color:#dc2626;font-weight:bold}
</style>
</head>
<body>
<h1>VPS 网络质量评测榜单 v4.0</h1>
<table>
<thead>
<tr><th>主机</th><th>IPv4 分数</th><th>IPv4 等级</th><th>IPv6 分数</th><th>IPv6 等级</th><th>详情</th></tr>
</thead>
<tbody>
EOF

# 遍历 VPS
while IFS=, read -r NAME USER HOST_IP PORT
do
  [[ "$NAME" =~ ^# ]] && continue
  SSH_CMD="ssh -o StrictHostKeyChecking=no -p $PORT $USER@$HOST_IP"
  yellow "开始测试 $NAME ($HOST_IP)..."

  IPV4_RES=$(check_stack "$SSH_CMD" 4)
  IPV6_RES=$(check_stack "$SSH_CMD" 6 2>/dev/null)

  IPV4_SCORE=$(echo "$IPV4_RES" | cut -d'|' -f1)
  IPV4_GRADE=$(echo "$IPV4_RES" | cut -d'|' -f2)
  IPV4_LOG=$(echo "$IPV4_RES" | cut -d'|' -f3-)

  IPV6_SCORE=$(echo "$IPV6_RES" | cut -d'|' -f1)
  IPV6_GRADE=$(echo "$IPV6_RES" | cut -d'|' -f2)
  IPV6_LOG=$(echo "$IPV6_RES" | cut -d'|' -f3-)

  echo "[$NAME] IPv4=$IPV4_SCORE($IPV4_GRADE) IPv6=$IPV6_SCORE($IPV6_GRADE)"
  echo "IPv4: $IPV4_LOG"
  echo "IPv6: $IPV6_LOG"
  echo "------------------------------------"

  # 写入 HTML
  echo "<tr><td>$NAME</td><td>$IPV4_SCORE</td><td class='grade-$IPV4_GRADE'>$IPV4_GRADE</td><td>$IPV6_SCORE</td><td class='grade-$IPV6_GRADE'>$IPV6_GRADE</td><td>IPv4: $IPV4_LOG<br>IPv6: $IPV6_LOG</td></tr>" >> "$HTML_OUT"

done < "$VPS_LIST"

# HTML 尾部
cat >> "$HTML_OUT" <<EOF
</tbody>
</table>
<p>生成时间: $(date '+%Y-%m-%d %H:%M:%S')</p>
</body>
</html>
EOF

green "全部测试完成！"
green "HTML 榜单生成：$HTML_OUT"
