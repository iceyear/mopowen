<div align="center">

# 💤 Dynamic Sleep Plugin for KOReader

<a title="hits" target="_blank" href="https://github.com/iceyear/mopowen"><img src="https://hits.b3log.org/iceyear/mopowen.svg" ></a> ![GitHub contributors](https://img.shields.io/github/contributors/iceyear/mopowen) ![GitHub License](https://img.shields.io/github/license/iceyear/mopowen)

English &nbsp;&nbsp;|&nbsp;&nbsp; [简体中文](README_CN.md)

</div>

## 📚 Overview

This KOReader plugin enhances battery life on Mobiscribe e-readers by implementing an adaptive deep sleep mechanism. Unlike the [original nopowen script](https://github.com/Codereamp/nopowen) that uses fixed sleep delay, this enhanced version dynamically adjusts the sleep timing based on your actual reading patterns.

## 🔋 Background

The screen and CPU are the most power-hungry parts of a conventional device. E-ink devices have a special advantage: they can maintain an image without power consumption. When combined with Deep Sleep mode, this creates a unique opportunity where the device can preserve the current page while consuming minimal power between page turns.

The Mobiscribe, like many Android-based e-readers, has a system setting called `power_enhance_enable` (see [here](https://github.com/webpad/eNote-SDK?tab=readme-ov-file#appendix)). By toggling this setting (first to `0`, then to `1`), we can trigger the Deep Sleep mode while keeping the current screen content. This method is also found in Nook devices and potentially other e-reader firmware developed by `Netronix`([XDA Post](https://xdaforums.com/t/some-new-information-regarding-glowlight-4-deep-sleep-and-possibly-other-eink-devices.4630059/)).

## ✨ Features

- 🔄 **Dynamic Sleep Timing**: Learns your reading speed and adjusts accordingly.
- 🔋 **Battery Optimization**: Extends battery life to thousands of page turns per charge.
- 📖 **Seamless Experience**: Maintains screen contents during sleep, waking instantly when you turn pages.
- 🧠 **Reading Pattern Detection**: Automatically detects fast page flipping vs. careful reading.
- 🔍 **Adaptive Algorithm**: Uses exponential moving average to smooth transitions between different reading patterns.
- ⚡ **Performance Optimized**: Uses integer milliseconds instead of floating-point seconds for better efficiency.
- 🗃️ **Settings Cache**: Reduces system calls with intelligent caching of Android settings.
- 📊 **Resource Management**: Minimizes memory usage and CPU load with optimized algorithms.

## 📥 Installation

1. Connect your Mobiscribe to a computer or other ways to access the file system.
2. Navigate to the KOReader plugins directory: `/sdcard/koreader/patches/` (create the `patches` folder if it doesn't exist)
3. Copy the `2111-mopowen-patch.lua` file to this folder
4. Enable "Modify System Settings" permission for KOReader in your Android settings if not enabled by default.
5. Restart KOReader completely (use the 'Exit' option from the menu)

## ⚙️ How It Works

The plugin works in several stages:

1. It intercepts page turn events in KOReader.
2. When a page is turned, it records the time and calculates how long you spent on the previous page.
3. It uses an Exponential Moving Average algorithm to adapt to your reading pace:
   - For slow reading (longer time per page), it reduces the delay before sleep;
   - For fast page flipping, it increases the delay to avoid frequent sleep/wake cycles.
4. It toggles the Android `power_enhance_enable` setting to trigger Deep Sleep.
5. The device wakes instantly when you turn to the next page.

## 🛠️ Configuration

You can adjust the settings at the top of the script file:

```lua
-- All time values in milliseconds for better performance
local ADAPTIVE_SLEEP = true               -- Enable/Disable dynamic sleep
local MIN_SLEEP_DELAY = 300               -- Minimum sleep delay (ms)
local MAX_SLEEP_DELAY = 60000             -- Maximum sleep delay (ms)
local ADAPTIVE_ALPHA = 0.3                -- Weight for new data (0-1), higher = faster adaptation
local INITIAL_READING_TIME = 30000        -- Initial assumed reading time (ms)
local FAST_READING_THRESHOLD = 2000       -- Fast reading threshold (ms)

-- Performance optimization settings
local LOG_LEVEL = 1                       -- 0: off, 1: important only, 2: verbose
local CACHE_TIMEOUT = 30                  -- System settings cache timeout (seconds)
```

## 🚀 Performance Optimizations

The latest version includes several performance enhancements:

1. **Integer Arithmetic**: Uses milliseconds integers instead of floating-point seconds for faster computation and lower memory usage.

2. **Settings Cache**: Implements a smart caching system for Android settings to reduce JNI calls, which are relatively expensive operations.

3. **Memoization**: Caches calculation results to avoid redundant processing when reading patterns are stable.

4. **Tiered Logging**: Configurable logging levels allow balancing between troubleshooting needs and performance.

5. **Memory Management**: Reduced object creation and optimized string handling to minimize garbage collection overhead.

These optimizations are especially beneficial for e-readers with limited processing power, ensuring the plugin itself consumes minimal battery while maximizing the battery saving benefits.

## 🔍 How to Check if It's Working

Several methods to verify the plugin is working correctly:

1. **Clock Method**: Enable the clock in the status bar. After turning a few pages and leaving the device, check if the clock has frozen at the time when Deep Sleep was activated.

2. **Battery Percentage**: Monitor the battery percentage. If the battery drain is minimal after extended periods with the device "on", the Deep Sleep is working.

3. **Response Delay**: After the device has been idle for a while, you might notice a slight delay when turning the page - this is the device waking from Deep Sleep.

4. **Log Entries**: With `LOG_LEVEL = 1` or higher, check the KOReader logs for entries starting with "KRP:" that show sleep scheduling events.

## ⚠️ Known Limitations & Side Effects

- **Frontlight**: The plugin should work with frontlight on, but it will drain more battery than with frontlight off.

- **Wi-Fi**: Not sure if Wi-Fi is compatible with Deep Sleep. The system may automatically disable it, but sometimes re-enables it unexpectedly.

- **Status Bar Clock**: The clock will only update when a new page appears, so it may show incorrect time.

- **Heavy PDFs**: With image-heavy documents, the device might feel less responsive as it needs more processing time.

- **Multiple Page Turns**: For PDFs and DjVu files, hardware buttons may sometimes turn more than one page at once.

- **Non-reading Activities**: Deep Sleep only activates during page-to-page reading. Menu navigation and other activities won't trigger sleep mode.

## 🔍 Troubleshooting

- If the device seems unresponsive or you meet other issues, try setting `ActualSleep = false` to disable actual sleeping while debugging.
- For performance issues, adjust `LOG_LEVEL = 0` to minimize logging overhead.
- If you experience excessive battery drain, ensure the script has permission to modify system settings.
- For logs, check the KOReader logcat for entries starting with "KRP:"

## 🙏 Credits

- [Original script](https://github.com/Codereamp/nopowen) for KOReader on Nook Glowlight 4/4e.
- [KOReader](https://github.com/koreader/koreader), a FOSS e-book reader application.
