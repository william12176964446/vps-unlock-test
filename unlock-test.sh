#!/bin/bash

# ================================
#   Carl 专用 VPS 流媒体解锁测试脚本
# ================================

green(){ echo -e "\033[32m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }

echo "====================================="
echo "   Carl 专用 VPS 流媒体解锁测试"
echo "====================================="

# ---------- 基础 IP 信息 ----------
echo
yellow "📌 IP 信息："
curl -s ipinfo.io
echo

# ---------- Netflix ----------
yellow "🎬 Netflix 测试："
NF_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://www.netflix.com/title/80018499)

if [ "$NF_STATUS" == "200" ] || [ "$NF_STATUS" == "301" ]; then
    green "✔ 完整解锁 Netflix"
elif [ "$NF_STATUS" == "404" ]; then
    yellow "⚠ 仅解锁 Netflix 自制剧（非完整）"
else
    red "✘ Netflix 不可用"
fi
echo

# ---------- Disney+ ----------
yellow "🧚 Disney+ 测试："
DISNEY=$(curl -s -I https://www.disneyplus.com | grep "location")

if echo "$DISNEY" | grep -q "unavailable"; then
    red "✘ Disney+ 不可用"
else
    green "✔ Disney+ 可用"
fi
echo

# ---------- YouTube Premium ----------
yellow "▶ YouTube Premium 测试："
YT=$(curl -s https://www.youtube.com/premium | grep "countryCode" | sed 's/.*"countryCode":"\([A-Z]*\)".*/\1/')

if [ -n "$YT" ]; then
    green "✔ YouTube Premium 区域：$YT"
else
    red "✘ 无法获取 YouTube Premium 信息"
fi
echo

# ---------- TikTok ----------
yellow "🎵 TikTok 测试："
TT=$(curl -s -o /dev/null -w "%{http_code}" https://www.tiktok.com)

if [ "$TT" == "200" ]; then
    green "✔ TikTok 可用"
else
    red "✘ TikTok 不可用"
fi
echo

# ---------- ChatGPT / OpenAI ----------
yellow "🤖 ChatGPT 测试："
GPT=$(curl -s -o /dev/null -w "%{http_code}" https://chat.openai.com)

if [ "$GPT" == "200" ] || [ "$GPT" == "302" ]; then
    green "✔ ChatGPT 可用"
elif [ "$GPT" == "403" ]; then
    red "✘ ChatGPT 被封锁（403）"
else
    red "✘ ChatGPT 不可用"
fi
echo

# ---------- Steam ----------
yellow "🎮 Steam 商店区域："
STEAM=$(curl -s https://store.steampowered.com/app/730 | grep "priceCurrency" | sed 's/.*"priceCurrency":"\([A-Z]*\)".*/\1/')

if [ -n "$STEAM" ]; then
    green "✔ Steam 区域货币：$STEAM"
else
    red "✘ 无法检测 Steam 区域"
fi
echo

# ---------- Adobe / Photoshop ----------
yellow "🖼 Adobe / Photoshop 区域测试："
ADOBE=$(curl -s -I https://cc-api-data.adobe.io | grep HTTP)

if echo "$ADOBE" | grep -q "200"; then
    green "✔ Adobe 服务可用（可正常激活 Photoshop）"
else
    red "✘ Adobe 服务不可用（可能无法激活 Photoshop）"
fi
echo

echo "====================================="
green "测试完成！"
echo "====================================="
