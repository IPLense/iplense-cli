# IPLense 命令行

1.2.0 默认脱敏 IP，并生成保留 30 天的报告。使用 `-p` 让本地检测结果只留在本机。

[English](README.md)

在终端里检测本机出口 IP：从 [IPLense](https://iplense.cc) 取得归属、网络类型、纯净度风险值与多源风险，并在本机检测 AI 平台、流媒体与邮件服务器的可用情况。

```bash
bash <(curl -sL https://iplense.cc/cli)
```

运行前如需核对脚本，先比对摘要：

```bash
curl -sL https://iplense.cc/cli -o iplense.sh && curl -sL https://iplense.cc/cli/sha256
```

```bash
sha256sum iplense.sh
```

一致后运行 `bash iplense.sh`。每个 release 附同一文件与 `SHA256SUMS`。

## 参数

| 参数 | 作用 |
| --- | --- |
| `-4` / `-6` | 只检测 IPv4 或 IPv6（默认两者都测） |
| `-l zh\|en` | 输出语言，`cn` 同 `zh`（默认按 `LANG`） |
| `-f` | 显示完整 IP、网段（含名称）与反向解析 |
| `-p` | 不生成报告，不上传本地检测结果 |
| `-j` | 输出 JSON，不上传报告 |
| `-o 文件` | 同时把输出保存到文件（不含颜色） |
| `-h` / `-V` | 帮助 / 版本 |

只需要 bash 与 curl，不需要 root，不安装任何软件，除 `-o` 指定的文件外不写文件。只在终端里输出颜色；设置 `NO_COLOR=1` 可关闭。`-o` 保存的文件与 JSON 输出不带颜色。

## 颜色

每种颜色都取自 IPLense 网站自身（网站代码 `code/assets`），按色相换成最接近的 ANSI 基本 16 色，常见终端都能显示。类型、等级与检测结果以底色标签显示（白字，黄底为黑字）；数字与标记直接着色。

| 显示内容 | 网站样式（颜色） | 终端 |
| --- | --- | --- |
| 家宽类型、原生、住宅 / 家宽、可用、支持地区 | `.type-badge.state-isp`、`.semantic-badge.state-success`（`#08754b`）、`.outbound-ai-region.is-supported`（`--green` `#12885a`） | 绿底（42） |
| 机房类型、机房、其他非原生、获取失败、不可用、不在支持地区 | `.type-badge.state-idc`（`--red` `#b72f3d`）、`.state-error`（`#a82332`）、`.outbound-ai-region.is-unsupported` | 红底（41） |
| 商业类型、广播、专业模式“其他”类型、Netflix 仅自制内容 | `.type-badge.state-business`、`.semantic-badge.state-warning`、`.pro-type-table .canonical-badge.state-unknown`、`.tool-state.is-warning`（`--amber` `#a15c08`） | 黄底（43） |
| 快速模式“Unknown”类型、检测失败 | `.semantic-badge.state-unknown`（`#596779`）、`.mini-cell.is-failed`（淡化） | 亮黑底（100） |
| IPLense 评分：80 及以上 / 60–79 / 60 以下 | `.score-ring.score-high` / `medium` / `low`（`query_controller.ts`） | 绿 / 黄 / 红（32 / 33 / 31），附同样分段的 20 格刻度和结果页的等级词（优秀 / 良好 / 较低） |
| 风险值：20 及以下 / 21–50 / 50 以上（纯净度与各数据源） | `.pro-risk-number.is-low` / `medium` / `high`（`query_controller.ts`）、`.purity-segment-*`（`QuickPurityCalculator`） | 绿 / 黄 / 红；纯净度附刻度与等级字 |
| 风险因子：命中 / 未命中 / 不提供 | `.risk-cell.is-detected` / `.is-clear` / `.is-none` | 红 / 绿 / 亮黑（31 / 32 / 90） |
| 额度暂不可用 / 调用失败 | `.pro-state[data-state="quota"]` / `[data-state="error"]` | 黄 / 红（33 / 31） |
| 分节标题与报告头边框 | `--blue`（`#1769e0`） | 粗体亮蓝（94） |

色相：绿（约 155°）最接近 ANSI 绿，红（约 355°）为 ANSI 红，琥珀（约 33°）为 ANSI 黄，蓝（215°）离 ANSI 蓝比青色近；石板灰几乎没有色相，取亮黑。蓝色取亮色版本，深色背景下也能看清。

## 检测内容

- **本机出口 IP**（来自 iplense.cc）：ASN、运营公司与位置、ASN 人类 / 自动化流量构成与注册机构；IPLense 评分、纯净度风险值与网络类型；各数据源的位置、使用类型、公司类型、风险值与风险因子。
- **本地检测**（从本机发起，每个可达协议族分别检测；JSON 沿用首个协议族的本地结果对象）：
  - ChatGPT 与 Claude：平台看到的地区，对照官方支持地区名单；
  - Gemini、Netflix、Disney+、YouTube Premium、TikTok、Prime Video、Reddit：是否可用及地区；
  - 出站 25 端口：是否读到 Gmail MX 的 `220` 问候。先解析，再连接；连接被拒、连接超过 5 秒或连接后 5 秒内没有 `220` 为不可用；无法解析服务器或 Bash 不支持网络重定向为检测失败。

  拿不到明确答复的项写“检测失败”，不做猜测。

## 会发送什么

- **iplense.cc**：每个协议族收到一次请求，带请求头 `X-IPLense-CLI: 1`、`X-IPLense-Family`（4 或 6）与 User-Agent `IPLense-CLI/<版本>`。服务器只查询请求来源的地址，不接收本机的其他任何信息。
- **数据源**：iplense.cc 就该地址向 IP 数据服务查询，与在网站上查询相同。
- **被检测的平台**：
  - 每个协议族各收到 1–3 次常规请求（桌面浏览器 User-Agent），对方看到本机 IP；
  - 脚本不登录、不提交账号信息；
  - Disney+ 检测会向 Disney 的服务注册一个匿名设备，只提交通用的设备描述（浏览器、Chrome、Windows），做法与下方致谢的开源脚本相同。
- **25 端口**：只与 Gmail 的邮件服务器建立一次连接，读到问候后发送 `QUIT`，不发送任何邮件。
- **报告**：默认发送自检令牌、客户端版本、语言、九个平台的状态与地区、25 端口状态，以及出口是否不同和脱敏后的出口 IP。本站只保存脱敏报告，保留 30 天，持有链接者可查看。`-p` 或 `-j` 不生成报告，本地检测结果不上传；`-f` 也不会在报告请求中发送完整 IP。
- **反向解析**：`-f` 通过系统 DNS 查询检测 IP 的 PTR 记录。

iplense.cc 如何处理查询，见 [IPLense 隐私政策](https://iplense.cc/zh/privacy)。

## 频率限制

- 自检每个 IP 每 10 分钟 20 次，不限每日次数。
- 同一 IP 的结果保留 1 小时，期间重复运行返回同一结果，不再查询数据服务。
- 达到限制时，脚本会说明多久后可以再试。

## 示例

五节示例输出，使用脱敏文档保留地址，位置与平台地区均为 JP，只检测 IPv4，80 列：

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                             IPLense 本机 IP 体检                             │
└──────────────────────────────────────────────────────────────────────────────┘
  203.0.*.* · 命令行 1.2.0 · 2026-10-05 01:00 UTC

一、基础信息
  ASN           AS64500 · Example Cloud Networks   IDC
  运营公司      Example Cloud Networks LLC   IDC
  位置          Japan · Tokyo
  IP 注册地区   JP · APNIC
  ASN 流量构成  人类流量 82%  ━━━━━━━━━━━━━━━━┃━━━  自动化流量 18%
  IP 属性        原生   机房

二、多源 IP 类型
  数据源         位置                 使用类型   公司类型
  IPLocate       JP · Tokyo           机房       商业
  ipapi.is       JP · Shinagawa       机房       机房
  ipdata         JP · Higashi-Ōsaka   机房       商业
  Abstract API   JP · Tokyo           机房       –
  IPinfo         JP · Tokyo           机房       –
  Proxycheck     JP · Tokyo           商业       –
  IPGeolocation  本次额度暂不可用
  Ipregistry     本次调用失败

三、风险评分与风险因子
  IPLense 评分          72  ━━━━━━━━━━━━━━┃━━━━━  良好
  IP 纯净度 风险值  18/100  ━━━┃━━━━━━━━━━━━━━━━  低

  数据源        风险值  托管  代理  VPN  Tor  中转  滥用  机器人
  IPLocate      35      ●     ·     ·    ·    –     ·     –
  ipapi.is      8       ●     ·     ·    ·    –     ·     –
  ipdata        62      ●     ●     –    ·    ·     ●     –
  Abstract API  中      ●     ·     ·    ·    ·     –     –
  Proxycheck    0       –     ·     ·    –    –     –     –
  AbuseIPDB     0       –     –     –    –    –     ·     –
  ● 命中  · 未命中  – 该来源不提供

四、AI 与流媒体
        ChatGPT   Claude    Gemini
  状态  支持地区  支持地区  可用
  地区  JP        JP        JP

        Netflix  Disney+  YouTube Premium  TikTok  Prime Video  Reddit
  状态  可用     可用     可用             可用    可用         可用
  地区  JP       JP       JP               JP      JP           JP

五、出站 25 端口
   可用

────────────────────────────────────────────────────────────────────────────────
  报告链接    https://iplense.cc/r/AAAAAAAAAAAAAAAAAAAAAA.svg （保留 30 天）
  关于命令行  https://iplense.cc/zh/cli
```

## 开发

测试还需要 Python 3（宽度与脱敏断言）及 shellcheck。

- `iplense.sh` 支持 bash 3.2 及以上。
- 测试使用桩版 `curl` 与固定数据，不访问网络：

```bash
shellcheck iplense.sh tests/run.sh tests/stub/curl
```

```bash
bash tests/run.sh
```

有意修改输出后，用 `UPDATE=1 bash tests/run.sh` 重写快照。

## 致谢

部分本地检测沿用 [xykt/IPQuality](https://github.com/xykt/IPQuality) 与 [lmc999/RegionRestrictionCheck](https://github.com/lmc999/RegionRestrictionCheck)（均为 AGPL-3.0）的判定标记，脚本中每项都注明出处。

## 许可证

[GNU Affero General Public License v3.0](LICENSE)。Copyright © 2026 IPLense。
