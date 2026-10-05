# IPLense CLI

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
| `-l zh\|en` | 输出语言（默认按 `LANG`） |
| `-j` | 输出 JSON |
| `-o 文件` | 同时把输出保存到文件（不含颜色） |
| `-h` / `-V` | 帮助 / 版本 |

只需要 bash 与 curl，不需要 root，不安装任何软件，除 `-o` 指定的文件外不写文件。只在终端里输出颜色；设置 `NO_COLOR=1` 可关闭。

## 检测内容

- **本机出口 IP**（来自 iplense.cc）：ASN、运营公司与位置；IPLense 评分、纯净度风险值与网络类型；各数据源的位置、使用类型、公司类型、风险值与风险因子。
- **本地检测**（从本机发起；双栈机器走 IPv4）：
  - ChatGPT 与 Claude：平台看到的地区，对照官方支持地区名单；
  - Gemini、Netflix、Disney+、YouTube Premium、TikTok、Prime Video、Reddit：是否可用及地区；
  - 出站 25 端口：公开邮件服务器（Gmail MX）是否应答。

  拿不到明确答复的项写“检测失败”，不做猜测。

## 会发送什么

- **iplense.cc**：每个协议族收到一次请求，带请求头 `X-IPLense-CLI: 1`、`X-IPLense-Family`（4 或 6）与 User-Agent `IPLense-CLI/<版本>`。服务器只查询请求来源的地址，不接收本机的其他任何信息。
- **数据源**：iplense.cc 就该地址向 IP 数据服务查询，与在网站上查询相同。
- **被检测的平台**：
  - 各收到 1–3 次常规请求（桌面浏览器 User-Agent），对方看到本机 IP；
  - 脚本不登录、不提交账号信息；
  - Disney+ 检测会向 Disney 的服务注册一个匿名设备，只提交通用的设备描述（浏览器、Chrome、Windows），做法与下方致谢的开源脚本相同。
- **25 端口**：只与 Gmail 的邮件服务器建立一次连接，读到问候后发送 `QUIT`，不发送任何邮件。
- 本地检测结果只显示在本机，不上传。

iplense.cc 如何处理查询，见 [IPLense 隐私政策](https://iplense.cc/zh/privacy)。

## 频率限制

- 自检每个 IP 每 10 分钟 3 次、每天 10 次。
- 同一 IP 的结果保留 1 小时，期间重复运行返回同一结果，不再查询数据服务。
- 达到限制时，脚本会说明多久后可以再试。

## 示例

示例输出，使用文档保留地址（`203.0.113.0/24`）：

```text
IPLense 自检  1.0.0

IPv4  203.0.113.45
  AS64500 · Example Cloud Networks · IDC
  运营公司  Example Cloud Networks LLC · IDC
  Japan · Tokyo

  评分 72    IP 纯净度 风险值 18/100    原生 · 机房

  数据源         位置                               使用类型  公司类型  风险值
  IPLocate       JP · Tokyo                         机房      商业          35
  ipapi.is       JP · Shinagawa                     机房      机房           8
  IPGeolocation  本次额度暂不可用
  ...

  完整结果  https://iplense.cc/zh/ip/203.0.113.45

本地检测 · IPv4
  ChatGPT           支持地区  CA
  Claude            支持地区  CA
  Netflix           可用      CA
  ...
  出站 25 端口      可用
```

## 开发

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
