# 🌐 VPS 解锁 & 网络质量评估脚本

Carl 专用的一键脚本，用于评估 VPS 的 IP 解锁能力和网络质量。支持流媒体、AI、软件服务、IP 信息分析、测速、Telegram 推送等功能。

---

## 🚀 功能模块

- ✅ 流媒体解锁检测：
  - Netflix（是否完整解锁）
  - Disney+
  - YouTube Premium（区域识别）
  - TikTok

- 🤖 AI / 软件服务检测：
  - ChatGPT / OpenAI
  - Adobe / Photoshop 激活区域
  - Steam 商店货币区域

- 🌍 IP 信息分析：
  - 国家 / 地区 / 城市
  - ASN / 运营商
  - 是否疑似数据中心 IP

- 📡 网络质量测试：
  - Ping 延迟 / 丢包率
  - 路由简查（traceroute）

- 🚄 速度测试：
  - Speedtest CLI（下行 / 上行 / Ping）

---

## 🧑‍💻 使用方法

### 一键运行：

```bash
bash <(curl -sSL https://raw.githubusercontent.com/william12176964446/vps-unlock-test/main/unlock-test.sh)
