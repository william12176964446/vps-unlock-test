#!/bin/bash

# ============================================
#   VPS 解锁 & 质量评估一体脚本
#   Author: Carl + Copilot
#   功能模块：
#   - IP 信息 / ASN / 地理位置 / 数据中心判断
#   - 流媒体解锁测试：Netflix / Disney+ / YouTube Premium / TikTok
#   - AI / 游戏 / 软件：ChatGPT / Steam / Adobe
#   - 网络质量：ping / 路由简查
#   - 速度测试：speedtest-cli
#   - 生成 Markdown 报告：report.md
#   - 预留 Telegram 推送结果
# ============================================

# ---------- 基础函数 ----------
green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }
blue(){ echo -e "\033[36m$1\033[0m"; }

REPORT_FILE="report.md"
> "$REPORT_FILE"   # 清空报告文件

log_report() {
  echo "$1" >> "$REPORT_FILE"
}

separator="-----------------------------------------"

echo "====================================="
echo "   VPS 解锁 & 质量评估一体脚本"
echo "====================================="

log_report "# VPS 解锁 & 质量评估报告"
log_report ""
log_report "- 生成时间：$(date '+%Y-%m-%d %H:%M:%S')"
log_report "- 主机名：$(hostname)"
log_report ""

# ---------- 依赖检查 ----------
yellow "🔍 检查基础依赖..."
deps=(curl ping)
missing=()

for d in "${deps[@]}"; do
  if ! command -v "$d" >/dev/null 2>&1; then
    missing+=("$d")
  fi
done

if [ ${#missing[@]} -ne 0 ]; then
  red "缺少依赖：${missing[*]}，请先安装后再运行。"
  exit 1
fi

# speedtest-cli 可选
if ! command -v speedtest-cli >/dev/null 2>&1; then
  yellow "未检测到 speedtest-cli，将尝试使用 Python 方式安装（如失败则跳过测速）..."
  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    pip3 install speedtest-cli >/dev/null 2>&1 || pip install speedtest-cli >/dev/null 2>&1
  fi
fi

echo

# ============================================
# 1. IP 信息 / ASN / 地理位置
# ============================================
yellow "📌 IP 基础信息"
echo "$separator"
IPINFO_JSON=$(curl -s https://ipinfo.io/json)
IP=$(echo "$IPINFO_JSON" | grep '"ip"' | sed 's/.*"ip": "\(.*\)".*/\1/')
COUNTRY=$(echo "$IPINFO_JSON" | grep '"country"' | sed 's/.*"country": "\(.*\)".*/\1/')
REGION=$(echo "$IPINFO_JSON" | grep '"region"' | sed 's/.*"region": "\(.*\)".*/\1/')
CITY=$(echo "$IPINFO_JSON" | grep '"city"' | sed 's/.*"city": "\(.*\)".*/\1/')
ORG=$(echo "$IPINFO_JSON" | grep '"org"' | sed 's/.*"org": "\(.*\)".*/\1/')

echo "IP 地址：$IP"
echo "国家：$COUNTRY"
echo "地区：$REGION"
echo "城市：$CITY"
echo "运营商/ASN：$ORG"
echo "$separator"
echo

log_report "## IP 信息"
log_report ""
log_report "- IP：$IP"
log_report "- 国家：$COUNTRY"
log_report "- 地区：$REGION"
log_report "- 城市：$CITY"
log_report "- 运营商/ASN：$ORG"
log_report ""

# 粗略判断是否数据中心 IP
if echo "$ORG" | grep -Ei "Google|Amazon|AWS|Alibaba|OVH|DigitalOcean|Hetzner|Microsoft|Azure|Linode|Vultr|Cloudflare" >/dev/null; then
  yellow "⚠ 检测为疑似数据中心 IP，部分流媒体/AI 可能受限。"
  log_report "- 粗略判断：疑似数据中心 IP（流媒体/AI 解锁风险较高）"
else
  green "✔ 未明显匹配常见数据中心 ASN，有一定概率为家宽/非典型机房 IP。"
  log_report "- 粗略判断：未匹配常见数据中心 ASN"
fi
log_report ""

# ============================================
# 2. 流媒体 / AI / 软件解锁测试
# ============================================
yellow "🎬 流媒体 / AI / 软件解锁测试"
echo "$separator"
log_report "## 流媒体 / AI / 软件解锁情况"
log_report ""

# ---------- Netflix ----------
yellow "Netflix 测试："
NF_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://www.netflix.com/title/80018499)

if [ "$NF_STATUS" == "200" ] || [ "$NF_STATUS" == "301" ]; then
  green "✔ 完整解锁 Netflix"
  log_report "- Netflix：**完整解锁**"
elif [ "$NF_STATUS" == "404" ]; then
  yellow "⚠ 仅解锁 Netflix 自制剧"
  log_report "- Netflix：仅自制剧"
else
  red "✘ Netflix 不可用"
  log_report "- Netflix：不可用"
fi
echo

# ---------- Disney+ ----------
yellow "Disney+ 测试："
DISNEY_HEADER=$(curl -s -I https://www.disneyplus.com)
if echo "$DISNEY_HEADER" | grep -qi "unavailable"; then
  red "✘ Disney+ 不可用"
  log_report "- Disney+：不可用"
else
  if echo "$DISNEY_HEADER" | grep -qi "200 OK\|301 Moved"; then
    green "✔ Disney+ 可用"
    log_report "- Disney+：可用"
  else
    yellow "⚠ Disney+ 无法明确判断，可能需要手动验证"
    log_report "- Disney+：状态不明，需手动验证"
  fi
fi
echo

# ---------- YouTube Premium ----------
yellow "YouTube Premium 测试："
YT_PAGE=$(curl -s https://www.youtube.com/premium)
YT_CC=$(echo "$YT_PAGE" | grep -oP '"countryCode":"\K[A-Z]+' | head -n1)

if [ -n "$YT_CC" ]; then
  green "✔ YouTube Premium 区域：$YT_CC"
  log_report "- YouTube Premium：可用（区域：$YT_CC）"
else
  red "✘ 无法获取 YouTube Premium 区域信息"
  log_report "- YouTube Premium：无法识别区域/可能不可用"
fi
echo

# ---------- TikTok ----------
yellow "TikTok 测试："
TT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://www.tiktok.com)

if [ "$TT_STATUS" == "200" ]; then
  green "✔ TikTok 可用"
  log_report "- TikTok：可用"
else
  red "✘ TikTok 不可用（HTTP $TT_STATUS）"
  log_report "- TikTok：不可用（HTTP $TT_STATUS）"
fi
echo

# ---------- ChatGPT / OpenAI ----------
yellow "ChatGPT 测试："
GPT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://chat.openai.com)

if [ "$GPT_STATUS" == "200" ] || [ "$GPT_STATUS" == "302" ]; then
  green "✔ ChatGPT 可用"
  log_report "- ChatGPT：可用"
elif [ "$GPT_STATUS" == "403" ]; then
  red "✘ ChatGPT 被封锁（403）"
  log_report "- ChatGPT：被封（403）"
else
  red "✘ ChatGPT 不可用（HTTP $GPT_STATUS）"
  log_report "- ChatGPT：不可用（HTTP $GPT_STATUS）"
fi
echo

# ---------- Steam ----------
yellow "Steam 商店区域测试："
STEAM_CC=$(curl -s https://store.steampowered.com/app/730 | grep -oP '"priceCurrency":"\K[A-Z]+' | head -n1)

if [ -n "$STEAM_CC" ]; then
  green "✔ Steam 货币区域：$STEAM_CC"
  log_report "- Steam 商店：可用（货币：$STEAM_CC）"
else
  red "✘ 无法检测 Steam 商店区域"
  log_report "- Steam 商店：无法检测区域"
fi
echo

# ---------- Adobe / Photoshop ----------
yellow "Adobe / Photoshop 区域测试："
ADOBE_HEADER=$(curl -s -I https://cc-api-data.adobe.io | grep HTTP)

if echo "$ADOBE_HEADER" | grep -q "200"; then
  green "✔ Adobe 服务可用（有较大概率可正常激活 Photoshop）"
  log_report "- Adobe / Photoshop：服务可用（具体授权情况以账号为准）"
else
  red "✘ Adobe 服务不可用（可能无法正常激活 Photoshop）"
  log_report "- Adobe / Photoshop：服务不可用"
fi
echo

# ============================================
# 3. 网络质量：延迟 / 路由简查
# ============================================
yellow "📡 网络质量测试（Ping / 路由简查）"
echo "$separator"
log_report "## 网络质量（基础）"
log_report ""

TARGETS=("8.8.8.8" "1.1.1.1")

for T in "${TARGETS[@]}"; do
  yellow "Ping $T (4 次)..."
  PING_RESULT=$(ping -c 4 -W 1 "$T" 2>/dev/null)
  if [ $? -eq 0 ]; then
    AVG_LAT=$(echo "$PING_RESULT" | grep "avg" | awk -F'/' '{print $5}')
    LOSS=$(echo "$PING_RESULT" | grep -oP '\d+(?=% packet loss)')
    green "✔ $T 平均延迟：${AVG_LAT}ms，丢包率：${LOSS}%"
    log_report "- Ping $T：平均延迟 ${AVG_LAT}ms，丢包率 ${LOSS}%"
  else
    red "✘ 无法 Ping 通 $T"
    log_report "- Ping $T：不可达"
  fi
  echo
done
log_report ""

# 路由简查（如果有 traceroute/mtr 可以扩展）
if command -v traceroute >/dev/null 2>&1; then
  yellow "路由简查（traceroute 8.8.8.8，前 10 跳）："
  traceroute -m 10 8.8.8.8 | sed -n '1,10p'
  log_report "（已执行 traceroute 8.8.8.8，前 10 跳，详见终端输出）"
  echo
fi

# ============================================
# 4. 速度测试（speedtest-cli）
# ============================================
yellow "🚀 速度测试（Speedtest）"
echo "$separator"
log_report "## 速度测试"
log_report ""

if command -v speedtest-cli >/dev/null 2>&1; then
  SPEEDTEST_OUTPUT=$(speedtest-cli --simple 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "$SPEEDTEST_OUTPUT"
    DOWNLOAD=$(echo "$SPEEDTEST_OUTPUT" | grep "Download" | awk '{print $2,$3}')
    UPLOAD=$(echo "$SPEEDTEST_OUTPUT" | grep "Upload" | awk '{print $2,$3}')
    PING_MS=$(echo "$SPEEDTEST_OUTPUT" | grep "Ping" | awk '{print $2,$3}')

    log_report "- Ping：$PING_MS"
    log_report "- 下行：$DOWNLOAD"
    log_report "- 上行：$UPLOAD"
  else
    red "✘ speedtest-cli 运行失败"
    log_report "- Speedtest：运行失败"
  fi
else
  red "✘ 未安装 speedtest-cli，跳过速度测试"
  log_report "- Speedtest：未安装 speedtest-cli，未测试"
fi
echo
log_report ""

# ============================================
# 5. 预留 Telegram 推送接口（可选）
# ============================================
# 使用方式：
#   事先在环境变量里设置：
#   export TG_BOT_TOKEN="xxxx"
#   export TG_CHAT_ID="123456"
#
#   然后本脚本会自动把 report.md 内容推送到 Telegram

if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
  yellow "📨 检测到 Telegram 配置，尝试推送报告..."
  TEXT=$(sed 's/$/%0A/' "$REPORT_FILE" | tr -d '\n')
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_CHAT_ID}" \
    -d "text=${TEXT}" \
    -d "parse_mode=Markdown" >/dev/null 2>&1

  if [ $? -eq 0 ]; then
    green "✔ Telegram 推送成功"
  else
    red "✘ Telegram 推送失败"
  fi
  echo
fi

# ============================================
# 结束
# ============================================
echo "====================================="
green "测试完成！"
echo "报告已保存为：$REPORT_FILE"
echo "====================================="
