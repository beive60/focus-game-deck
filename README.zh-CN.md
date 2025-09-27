# **Focus Game Deck 🚀**

[日本語](./README.JP.md) | [English](./README.md) | **中文简体**

**一个PowerShell脚本，从开始到结束自动化您的游戏会话，专为竞技PC玩家设计。**

此脚本处理游戏前的繁琐环境设置（禁用热键、关闭后台应用等）并在游戏结束后自动恢复所有设置。这让您可以专注于游戏本身。

## **✨ 功能特性**

* **🎮 游戏特定环境自动化**：根据您的配置为每个游戏自动设置和拆除自定义环境。
* **🔧 通用应用程序管理**：通过可配置的启动和关闭操作灵活控制任何应用程序。
* **🔄 易于扩展**：只需编辑配置文件即可添加新的应用程序管理 - 无需更改代码。
* **🛡️ 稳固设计**：包含全面的配置验证和清理过程，确保即使脚本被中断（例如Ctrl+C），您的环境也能恢复正常。
* **⚙️ 特殊集成**：内置支持：
  * **Clibor**：切换热键开/关。
  * **NoWinKey**：禁用Windows键以防止意外按压。
  * **AutoHotkey**：停止运行脚本并在游戏关闭后恢复。
  * **OBS Studio**：启动OBS并在游戏开始/结束时自动启动/停止重播缓冲区。
  * **VTube Studio**：Steam和独立版本支持，自动游戏模式切换和流媒体恢复。
  * **Discord**：游戏模式自动切换、Rich Presence显示和覆盖控制，优化专注环境。
  * **Wallpaper Engine**：使用官方命令行界面在游戏期间暂停壁纸播放以提高性能。

## **🛠️ 前置要求**

要使用此脚本，您需要安装以下软件：

* **PowerShell**：Windows标准配置。
* **Steam**
* **OBS Studio**：[官方网站](https://obsproject.com/)
  * **obs-websocket插件**：OBS v28及更高版本默认包含。请确保在设置中启用。
* **[可选] Clibor**：剪贴板工具。
* **[可选] NoWinKey**：禁用Windows键的工具。
* **[可选] AutoHotkey**：自动化脚本语言。
* **[可选] VTube Studio**：VTuber头像管理软件。
* **[可选] Discord**：游戏玩家通讯平台。
* **[可选] Wallpaper Engine**：动态壁纸应用程序。通过在游戏期间暂停壁纸播放来提高游戏性能。
* **[可选] Luna**：（或您希望管理的任何其他后台应用程序）。

## **💻 安装选项**

Focus Game Deck提供灵活的安装方法以满足不同用户偏好：

### **选项1：可执行文件分发（推荐）**

从[GitHub Releases](https://github.com/beive60/focus-game-deck/releases)下载预构建的数字签名可执行文件：

* **Focus-Game-Deck.exe** - 主应用程序（单文件，无需PowerShell）
* **Focus-Game-Deck-Config-Editor.exe** - GUI配置编辑器
* **Focus-Game-Deck-MultiPlatform.exe** - 扩展平台支持版本

**优势：**

* ✅ 无PowerShell执行策略问题
* ✅ 数字签名确保安全性和可信度
* ✅ 单文件分发
* ✅ 适用于PowerShell策略受限的系统

### **选项2：PowerShell脚本（开发/高级用户）**

克隆或下载仓库以直接执行PowerShell：

```bash
git clone https://github.com/beive60/focus-game-deck.git
cd focus-game-deck
```

**优势：**

* ✅ 完全的源代码可见性
* ✅ 易于定制和修改
* ✅ 访问最新开发功能

## **🏗️ 架构与设计**

Focus Game Deck采用**轻量、可维护、可扩展**的设计理念构建：

### **核心原则**

* **🪶 轻量化**：使用Windows原生PowerShell + WPF，无需额外运行时
* **🔧 配置驱动**：所有行为通过`config.json`控制 - 无需代码更改即可定制
* **🌐 国际化就绪**：JSON外部资源模式，支持正确的日文字符显示
* **📦 单文件分发**：可使用ps2exe编译为单个可执行文件

### **技术栈**

* **核心引擎**：具有全面错误处理的PowerShell脚本
* **GUI模块**：基于JSON国际化的PowerShell + WPF
* **配置**：基于JSON的设置，包含验证和示例模板
* **集成**：原生Windows API和应用程序特定协议

详细架构信息请参见[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)。

### **构建系统与分发**

Focus Game Deck具有全面的三层构建系统：

* **📦 自动可执行文件生成**：基于ps2exe的编译为独立可执行文件
* **🔐 数字签名基础设施**：扩展验证证书支持，自动签名
* **🚀 生产就绪流水线**：完整的开发和生产构建工作流程
* **📋 发布包管理**：自动化签名分发包创建

**构建脚本：**

* `Master-Build.ps1` - 完整构建编排（开发/生产工作流程）
* `build-tools/Build-FocusGameDeck.ps1` - 核心可执行文件生成和构建管理
* `Sign-Executables.ps1` - 数字签名管理和证书操作

详细构建系统文档请参见[docs/BUILD-SYSTEM.md](./docs/BUILD-SYSTEM.md)。

## **🚀 设置与配置**

1. **下载仓库**：克隆或下载此仓库的ZIP文件。
2. **创建配置文件**：
   * 复制config.json.sample并将副本重命名为config.json，放在同一目录中。
3. **编辑config.json**：
   * 在文本编辑器中打开config.json并更新路径和设置以匹配您的系统。

```json
{
      "obs": {
          "websocket": {
              "host": "localhost",
              "port": 4455,
              "password": "" // 在此设置您的OBS WebSocket服务器密码
          },
          "replayBuffer": true
      },
      "managedApps": {
          "noWinKey": {
              "path": "C:\\\\Apps\\\\NoWinKey\\\\NoWinKey.exe",
              "processName": "NoWinKey",
              "startupAction": "start",
              "shutdownAction": "stop",
              "arguments": ""
          },
          "autoHotkey": {
              "path": "",
              "processName": "AutoHotkeyU64|AutoHotkey|AutoHotkey64",
              "startupAction": "stop",
              "shutdownAction": "start",
              "arguments": ""
          },
          "clibor": {
              "path": "C:\\\\Apps\\\\clibor\\\\Clibor.exe",
              "processName": "Clibor",
              "startupAction": "none",
              "shutdownAction": "none",
              "arguments": "/hs"
          },
          "luna": {
              "path": "",
              "processName": "Luna",
              "startupAction": "stop",
              "shutdownAction": "none",
              "arguments": ""
          }
      },
      "games": {
          "apex": { // ← "apex" 是GameId
              "name": "Apex Legends",
              "steamAppId": "1172470", // 在Steam商店页面URL中找到此ID
              "processName": "r5apex\*", // 在任务管理器中查看（支持通配符\*）
              "appsToManage": ["noWinKey", "autoHotkey", "luna", "obs", "clibor"]
          },
          "dbd": {
              "name": "Dead by Daylight",
              "steamAppId": "381210",
              "processName": "DeadByDaylight-Win64-Shipping\*",
              "appsToManage": ["obs", "clibor"]
          }
          // ... 在此添加其他游戏 ...
      },
      "paths": {
          // ↓↓↓ 将这些更改为您PC上的正确可执行文件路径 ↓↓↓
          "steam": "C:\\\\Program Files (x86)\\\\Steam\\\\steam.exe",
          "obs": "C:\\\\Program Files\\\\obs-studio\\\\bin\\\\64bit\\\\obs64.exe"
      }
  }
```

* **managedApps**：
* 定义您要管理的所有应用程序。每个应用程序具有：
  * `path`：可执行文件的完整路径（如果仅需进程管理可为空）
  * `processName`：停止进程的进程名（支持使用|的通配符）
  * `startupAction`：游戏启动时的操作（"start"、"stop"或"none"）
  * `shutdownAction`：游戏结束时的操作（"start"、"stop"或"none"）
  * `arguments`：可选的命令行参数
* **games**：
* 为您要管理的游戏添加条目。键（例如"apex"、"dbd"）将在稍后用作-GameId参数。
* 设置`appsToManage`数组以指定每个游戏应管理哪些应用程序。
* **paths**：
* 设置Steam和OBS的路径。其他应用程序路径现在在`managedApps`中定义。

## **🎬 使用方法**

### **使用可执行文件版本（推荐）**

只需从命令提示符或PowerShell运行可执行文件：

```cmd
# 命令提示符
Focus-Game-Deck.exe apex

# PowerShell
.\Focus-Game-Deck.exe apex
```

### **使用PowerShell脚本版本**

打开PowerShell终端，导航到脚本目录，并运行以下命令：

```powershell
# 示例：启动Apex Legends
.\Invoke-FocusGameDeck.ps1 -GameId apex

# 示例：启动Dead by Daylight
.\Invoke-FocusGameDeck.ps1 -GameId dbd
```

### **一般使用说明**

* 将您在config.json中配置的GameId（例如"apex"、"dbd"）指定为参数。
* 应用程序将自动应用您配置的设置并通过Steam启动游戏。
* 退出游戏后，应用程序将检测到进程已结束并自动将您的环境恢复到原始状态。
* **GUI配置**：使用`Focus-Game-Deck-Config-Editor.exe`进行用户友好的配置编辑。

## **➕ 添加新应用程序**

新架构使添加新的应用程序管理变得极其简单。只需将它们添加到`managedApps`部分：

```json
{
  "managedApps": {
    "discord": {
      "path": "C:\\Users\\Username\\AppData\\Local\\Discord\\app-1.0.9012\\Discord.exe",
      "processName": "Discord",
      "startupAction": "stop",
      "shutdownAction": "start",
      "arguments": ""
    },
    "spotify": {
      "path": "C:\\Users\\Username\\AppData\\Roaming\\Spotify\\Spotify.exe",
      "processName": "Spotify",
      "startupAction": "stop",
      "shutdownAction": "none",
      "arguments": ""
    }
  },
  "games": {
    "apex": {
      "appsToManage": ["noWinKey", "autoHotkey", "discord", "spotify", "obs", "clibor"]
    }
  }
}
```

**就是这样！**无需更改PowerShell脚本。系统自动处理在`managedApps`中定义的任何应用程序。

## **🔧 故障排除**

1. **如果脚本执行失败：**
   * 检查PowerShell执行策略
   * 尝试以管理员权限运行

2. **如果进程停止/启动失败：**
   * 验证`managedApps`中的路径设置是否正确
   * 确保应用程序已正确安装
   * 检查进程名是否正确（使用任务管理器验证）

3. **如果游戏无法启动：**
   * 验证Steam AppID是否正确
   * 确保Steam正在运行

4. **如果OBS重播缓冲区未启动：**
   * 验证OBS WebSocket服务器已启用
   * 检查WebSocket设置（主机、端口、密码）是否正确
   * 确保在OBS中配置了重播缓冲区

5. **配置验证错误：**
   * 检查`appsToManage`中引用的所有应用程序是否存在于`managedApps`中
   * 确保必需属性（path、processName、startupAction、shutdownAction）存在
   * 验证操作值是否为："start"、"stop"、"none"之一

## **📜 许可证**

此项目根据**MIT许可证**授权。详情请参阅LICENSE文件。

## ❤️ 表达您的支持

我真诚地希望这个工具能让您的竞技游戏体验更加舒适和专注。

如果您喜欢使用它，我将非常感激您能在X.com（原Twitter）等社交媒体上分享您在使用它的消息。您的声音可以帮助其他可能正在寻找类似解决方案的游戏玩家。

当您分享时，请随意使用话题标签**`#GameLauncherWatcher`**。看到您的帖子将是我的巨大喜悦！

知道这个工具正在帮助人们是我持续改进它的最大动力。

## **🗺️ 项目路线图**

想了解即将推出的功能？查看我们的[详细路线图](./docs/ROADMAP.md)，了解计划功能、时间线和Focus Game Deck未来发展的战略愿景。

## **📦 版本管理与发布**

Focus Game Deck遵循**[语义化版本](https://semver.org/)**（SemVer）进行一致的版本管理。

### 当前版本

**v1.2.0** - 构建系统和数字签名基础设施已完成

### 发布渠道

* **Alpha**：核心功能验证的有限测试版本
* **Beta**：供更广泛反馈的公开测试版
* **Stable**：供所有用户使用的生产就绪版本

### 面向开发者

如果您要为项目做贡献，请查看我们的综合文档：

* **[架构与实现指南](./docs/ARCHITECTURE.md)** - **字符编码最佳实践**、技术架构和开发标准
* **[版本管理规范](./docs/VERSION-MANAGEMENT.md)** - SemVer实施详情
* **[GitHub发布指南](./docs/GITHUB-RELEASES-GUIDE.md)** - 发布操作程序
* **[开发者发布指南](./docs/DEVELOPER-RELEASE-GUIDE.md)** - 逐步发布流程

> **⚠️ 贡献者重要提示**：字符编码问题一直是此项目的反复挑战。在进行代码贡献之前，请查看[字符编码指南](./docs/ARCHITECTURE.md#character-encoding-and-console-compatibility-guidelines)。

### 下载与安装

* **最新版本**：可从[GitHub Releases](https://github.com/beive60/focus-game-deck/releases/latest)获取
* **可执行文件版本**：预构建、签名的可执行文件，可立即使用
* **源代码**：面向开发者和高级用户的完整PowerShell源代码
* **安全性**：所有版本均使用扩展验证证书进行数字签名，确保最大信任度
* **构建系统**：完整的自动化构建和签名基础设施已实现
