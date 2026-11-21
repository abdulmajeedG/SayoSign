<p align="center">
  <img src="docs/assets/icon.png" width="128" alt="SayoSign 图标">
</p>

<h1 align="center">SayoSign</h1>

<p align="center">
  <b>可爱又强大的 iPhone 设备端 IPA 签名工具。</b><br>
  使用 .p12 或免费 Apple ID 签名，用自研 Hook 引擎注入插件，无需电脑离线安装。
</p>

<p align="center">
  <a href="https://github.com/murk-sus/SayoSign/actions"><img src="https://github.com/murk-sus/SayoSign/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/iOS-15%2B-ff7e8a" alt="iOS 15+">
  <img src="https://img.shields.io/badge/license-GPL--3.0-f0566e" alt="GPL-3.0">
  <a href="README.md"><img src="https://img.shields.io/badge/README-English-ffb3a7" alt="English"></a>
  <a href="README_RU.md"><img src="https://img.shields.io/badge/README-на%20русском-ffb3a7" alt="Russian"></a>
</p>

---

## ✨ 功能

- **设备端签名。** 签名引擎用 C 从零编写，不含 OpenSSL 和 zsign：支持 Mach-O（含 fat 二进制）、SHA-256 CodeDirectory、CMS 签名、XML 与 DER 权限、嵌套框架和扩展、`_CodeSignature/CodeResources`，以及 ZIP64 打包。
- **证书。** 导入 `.p12` 和 `.mobileprovision`，查看团队、有效期、设备和权限，并通过 **OCSP 实时检查证书是否被吊销**。
- **Apple ID 登录。** 直接使用免费或付费开发者账号。SayoSign 实现了 GrandSlam（SRP-6a，支持受信任设备或短信双重认证）和 Apple Developer Services，可自动注册设备、创建证书并为每个应用获取描述文件。
- **插件注入。** 支持 `.dylib`、`.deb`（gzip、xz、lzma 或 zstd，自带 zstd 解码器）和 `.framework`。Substrate、ElleKit、libhooker 和 substitute 依赖会被自动重定向。
- **SayoHook** 自研 Hook 框架，以 `CydiaSubstrate.framework` 形式内置，导出 `MSHookMessageEx`、`MSHookFunction`、`MSFindSymbol`、`MSGetImageByName`、`LHHookFunctions`、`LBHookMessage` 和 `substitute_*`。
- **离线安装。** 通过 `localhost` 上的小型 HTTPS 服务器和 `itms-services` 安装应用。信任来自设备上生成的证书颁发机构，私钥永不离开手机：没有泄露的密钥，也没有第三方服务器。
- **软件源。** 支持 AltStore、SideStore、Feather 和 ESign 源，可搜索、看截图、一键下载。
- **应用修改。** 修改名称、Bundle ID、版本、图标和最低 iOS；移除扩展、Watch 应用或 URL Scheme；启用文件共享；添加额外权限。
- **界面。** 粉珊瑚色设计配小蝴蝶结 🎀，iOS 26+ 支持 Liquid Glass，支持英文、俄文和简体中文。

## 📲 安装

1. 从 [Releases](https://github.com/murk-sus/SayoSign/releases) 下载 `SayoSign.ipa`（或从 [Actions](https://github.com/murk-sus/SayoSign/actions) 获取最新构建）。
2. 用任意方式签名一次：其他签名工具、Sideloadly、AltStore，或本仓库的 `sayosign` 命令行工具。
3. 打开 SayoSign → **设置 → 本地安装器设置**，按三个步骤操作。只需设置一次。

## 🛠 命令行签名

同一引擎可编译为桌面命令行工具（Linux 或 macOS，解析 p12 需要 OpenSSL）：

```sh
make
./build/sayosign sign -k cert.p12 -p 1234 -m profile.mobileprovision -i app.ipa -o signed.ipa \
    -n "My App" -l tweak.deb -H build/CydiaSubstrate.framework
./build/sayosign ocsp -k cert.p12 -p 1234
```

## 🧾 AltStore 软件源

将 `https://murk-sus.github.io/SayoSign/source.json` 添加到 AltStore、SideStore、Feather 或 SayoSign 本身。

## 💖 支持作者

SayoSign 免费且开源。如果它对你有帮助，欢迎打赏：

| 网络 | 地址 |
|---|---|
| USDT (TRC20) | `TCPD7jzSMtQ4zkoSxSbUZi6RFoVdKqv78w` |
| TON | `UQAVaWTuYuEF8A_qiVEcHnqhomp2UdYvW4fHxyhJVxFkQe1z` |
| BTC | `bc1qqvt25c9tzw2yfdpvf738gzzk4r5uyvkrrlz4z0` |
| ETH (ERC20) | `0xE7497CF78B691F84D2f1A2Dc30223BB53B3EF38D` |
| SOL | `DhcDnnqK23gwvkRRHtNd3TBXN9gHmT4V7LZrAPHgCR6n` |

带二维码的打赏页面：**[murk-sus.github.io/donate](https://murk-sus.github.io/donate/)** · Telegram 频道：[@jailbreak_IOS_and_tweaks](https://t.me/jailbreak_IOS_and_tweaks)

## ⚖️ 法律声明

SayoSign 使用**你自己的**证书为**你自己的**设备签名应用。请勿用于分发盗版软件。与 Apple 无关。

名称致敬 Sayori，未使用 *Doki Doki Literature Club* 的任何美术素材。图标使用 [Twemoji](https://github.com/jdecked/twemoji) 🎀 ✒️（CC-BY 4.0）。

基于 **GPL-3.0** 授权。
