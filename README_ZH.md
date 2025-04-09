<div align="center">

# 💤 KOReader 动态休眠插件

<a title="hits" target="_blank" href="https://github.com/iceyear/mopowen"><img src="https://hits.b3log.org/iceyear/mopowen.svg" ></a> ![GitHub contributors](https://img.shields.io/github/contributors/iceyear/mopowen) ![GitHub License](https://img.shields.io/github/license/iceyear/mopowen)

</div>

## 📚 概述

本插件通过实现自适应深度休眠机制来延长 Mobiscribe 电纸书的电池寿命。与使用固定休眠延迟的 [原始 nopowen 脚本](https://github.com/Codereamp/nopowen) 不同，这个增强版本会根据您的实际阅读模式动态调整休眠时间。

## 🔋 背景

屏幕和 CPU 是常规设备中最耗电的部分。电子墨水设备具有特殊优势：它们可以在不消耗电量的情况下保持图像显示。当与深度休眠模式结合时，这创造了一个独特的机会，使设备可以在翻页之间保留当前页面内容，同时最大限度地降低功耗。

Mobiscribe 与许多基于 Android 的电子阅读器一样，有一个名为 `power_enhance_enable` 的系统设置（参见[此处](https://github.com/webpad/eNote-SDK?tab=readme-ov-file#appendix)）。通过切换此设置（先设为 `0`，然后设为 `1`），我们可以在保持当前屏幕内容的同时触发深度休眠模式。这种方法也存在于 Nook 设备中，可能也适用于其他由 `Netronix` 开发的电子阅读器固件（[XDA 帖子](https://xdaforums.com/t/some-new-information-regarding-glowlight-4-deep-sleep-and-possibly-other-eink-devices.4630059/)）。

## ✨ 特点

- 🔄 **动态休眠时间**：学习您的阅读速度并相应调整。
- 🔋 **电池优化**：延长电池寿命，每次充电可翻阅数千页。
- 📖 **无缝体验**：在休眠期间保持屏幕内容，翻页时立即唤醒。
- 🧠 **阅读模式检测**：自动区分快速翻页与深入阅读。
- 🔍 **自适应算法**：使用指数移动平均算法平滑不同阅读模式之间的转换。
- ⚡ **性能优化**：使用整数毫秒而非浮点秒，提高计算效率。
- 🗃️ **设置缓存**：通过智能缓存 Android 设置减少系统调用。
- 📊 **资源管理**：通过优化算法最小化内存使用和 CPU 负载。

## 📥 安装

1. 将 Mobiscribe 连接到电脑或使用其他方式访问文件系统。
2. 导航到 KOReader 插件目录：`/sdcard/koreader/patches/`（如果不存在 `patches` 文件夹，请创建它）。
3. 将 `2111-mopowen-patch.lua` 文件复制到此文件夹。
4. 如果默认未启用，请在 Android 设置中为 KOReader 启用"修改系统设置"权限。
5. 完全重启 KOReader（使用菜单中的"退出"选项）。

## ⚙️ 工作原理

该插件分几个阶段工作：

1. 拦截 KOReader 中的翻页事件。
2. 当翻页时，记录时间并计算您在上一页停留了多长时间。
3. 使用指数移动平均算法适应您的阅读节奏：
   - 对于深入阅读（每页时间较长），减少睡眠前的延迟；
   - 对于快速翻页，增加延迟以避免频繁的睡眠/唤醒循环。
4. 切换 Android `power_enhance_enable` 设置以触发深度休眠。
5. 当您翻到下一页时，设备立即唤醒。

## 🛠️ 配置

您可以在脚本文件顶部调整设置：

```lua
-- 所有时间值使用毫秒单位以提高性能
local ADAPTIVE_SLEEP = true               -- 启用/禁用动态休眠
local MIN_SLEEP_DELAY = 300               -- 最小休眠延迟(毫秒)
local MAX_SLEEP_DELAY = 60000             -- 最大休眠延迟(毫秒)
local ADAPTIVE_ALPHA = 0.3                -- 新数据权重(0-1)，越高适应越快
local INITIAL_READING_TIME = 30000        -- 初始假设的阅读时间(毫秒)
local FAST_READING_THRESHOLD = 2000       -- 快速阅读阈值(毫秒)

-- 性能优化设置
local LOG_LEVEL = 1                       -- 0: 关闭, 1: 仅重要信息, 2: 详细
local CACHE_TIMEOUT = 30                  -- 系统设置缓存超时(秒)
```

## 🚀 性能优化

最新版本包含多项性能增强：

1. **整数算术**：使用毫秒整数而非浮点秒，实现更快的计算和更低的内存使用。

2. **JNI 缓存**：实现智能缓存系统减少 JNI 调用，这些调用是相对昂贵的操作。

3. **存储计算**：缓存计算结果，在阅读模式稳定时避免重复处理。

4. **分层日志**：可配置的日志级别，在故障排除需求和性能之间取得平衡。

5. **内存管理**：减少对象创建和优化字符串处理，最小化垃圾回收开销。

这些优化对处理能力有限的电子阅读器特别有益，最大化电池节省效果。

## 🔍 如何检查是否正常工作

几种验证插件是否正常工作的方法：

1. **时钟方法**：在状态栏中启用时钟。翻几页并放置设备后，检查时钟是否在激活深度休眠时停止更新。

2. **电池百分比**：监控电池百分比。如果设备"开启"后长时间内电池消耗极小，则深度休眠正在工作。

3. **响应延迟**：设备闲置一段时间后，翻页时可能会注意到轻微延迟 - 这是设备从深度休眠中唤醒的表现。

4. **日志条目**：设置 `LOG_LEVEL = 1` 或更高，检查 KOReader 日志中以 "KRP:" 开头的条目，显示休眠调度事件。

## ⚠️ 已知限制和副作用

- **前光**：插件应该可以与前光一起工作，但比关闭前光时耗电更多。

- **Wi-Fi**：不确定 Wi-Fi 是否与深度休眠兼容。系统可能会自动禁用它，但有时会意外重新启用。

- **状态栏时钟**：时钟仅在出现新页面时更新，因此可能显示不正确的时间。

- **大型 PDF**：对于图像密集的文档，设备可能感觉反应较慢，因为它需要更多处理时间。

- **多页翻转**：对于 PDF 和 DjVu 文件，硬件按钮有时可能一次翻转多页。

- **非阅读活动**：深度休眠仅在页到页阅读期间激活。菜单导航和其他活动不会触发休眠模式。

## 🔍 故障排除

- 如果设备似乎没有响应或遇到其他问题，尝试设置 `ActualSleep = false` 以在调试时禁用实际休眠。
- 对于性能问题，调整 `LOG_LEVEL = 0` 以最小化日志开销。
- 如果遇到过度耗电，请确保脚本有修改系统设置的权限。
- 要查看日志，请在 KOReader logcat 中查找以 "KRP:" 开头的条目。

## 🙏 致谢

- Nook Glowlight 4/4e 上 KOReader 的 [原始脚本](https://github.com/Codereamp/nopowen)。
- [KOReader](https://github.com/koreader/koreader)，自由的电子书阅读应用。
