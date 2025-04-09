--[[
   mopowen v20250409
   
   Dynamic sleep time adjustment for KOReader
   Enhanced with adaptive sleep timing that learns from user's reading patterns
   
   Author: Ice Year

   Thanks to the original project: https://github.com/Codereamp/nopowen
   
   This script allows sending e-ink devices into Deep Sleep mode after every page turn
   with intelligent timing based on reading patterns. It significantly increases
   battery life by putting the device into minimum energy consumption between
   page turns while preserving the screen image.
--]]

-- Configuration (all time values in milliseconds for better performance)
local ActualSleep = true                  -- Set to false for debugging without actual sleep
local DS_DELAY_INTERCEPT = 4000           -- Initial delay when opening books (ms)
local SCHEDULED_SET_ALLOWED_UI_MESSAGE = true

-- Dynamic sleep parameters (milliseconds)
local ADAPTIVE_SLEEP = true               -- Master switch for adaptive sleep
local MIN_SLEEP_DELAY = 300               -- Minimum sleep delay (ms)
local MAX_SLEEP_DELAY = 60000             -- Maximum sleep delay (ms)
local ADAPTIVE_ALPHA = 0.3                -- Learning rate (0-1)
local INITIAL_READING_TIME = 30000        -- Initial assumed reading time (ms)
local FAST_READING_THRESHOLD = 2000       -- Fast reading threshold (ms)
local READING_TIME_DIVISOR = 10           -- Reading time divisor for proportional delay

-- Performance optimization settings
local LOG_LEVEL = 1                       -- 0: off, 1: important only, 2: verbose
local CACHE_TIMEOUT = 30                  -- System settings cache timeout (seconds)

-- State variables
local last_page_time = nil                -- Last page turn timestamp
local avg_reading_time = INITIAL_READING_TIME
local settings_cache = {}                 -- Cache for system settings
local settings_cache_timestamp = {}       -- Timestamp for cached settings

-- Required modules
local logger = require("logger")
local android = require("android")
local ffi = require("ffi")
local UIManager = require("ui/uimanager")
local UIManager_show_original = UIManager.show
local InfoMessage = require("ui/widget/infomessage")

-- Optimized logging function with levels
local function loclog(msg, level)
    level = level or 1
    if logger ~= nil and level <= LOG_LEVEL then
        logger.info('KRP: '..msg)
    end
end

-- Exception handler with reduced logging
function JniExceptCheck(jni)
    if jni.env[0].ExceptionCheck(jni.env) == ffi.C.JNI_TRUE then 
        loclog('Java exception occurred', 1)
        jni.env[0].ExceptionDescribe(jni.env)
        jni.env[0].ExceptionClear(jni.env)
        return true
    end
    return false
end

-- JNI method with exception handling
function JniChecked_CallStaticBooleanMethod(jni, class, method, signature, ...)
    local clazz = jni.env[0].FindClass(jni.env, class)
    local methodID = jni.env[0].GetStaticMethodID(jni.env, clazz, method, signature)
    local res = jni.env[0].CallStaticBooleanMethod(jni.env, clazz, methodID, ...)
    local ExceptionOccured = JniExceptCheck(jni)
    jni.env[0].DeleteLocalRef(jni.env, clazz)
    if ExceptionOccured then res = false end
    return res, ExceptionOccured
end

function JniChecked_CallStaticIntMethod(jni, class, method, signature, ...)
    local clazz = jni.env[0].FindClass(jni.env, class)
    local methodID = jni.env[0].GetStaticMethodID(jni.env, clazz, method, signature)
    local res = jni.env[0].CallStaticIntMethod(jni.env, clazz, methodID, ...)
    local ExceptionOccured = JniExceptCheck(jni)
    jni.env[0].DeleteLocalRef(jni.env, clazz)
    return res, ExceptionOccured
end

-- Cached system settings access
local android_settings_system_set_int = function(setting_name, value)
    -- Update cache first to avoid unnecessary JNI calls
    settings_cache[setting_name] = value
    settings_cache_timestamp[setting_name] = os.time()
    
    if android == nil or android.jni == nil or android.app == nil then return false end
    
    return android.jni:context(android.app.activity.vm, function(jni)
        loclog('Setting ['..setting_name..'] to ['..value..']', 2)   
        local arg_object = jni:callObjectMethod(
            android.app.activity.clazz,
            "getContentResolver",
            "()Landroid/content/ContentResolver;"
        )
        local arg_name = jni.env[0].NewStringUTF(jni.env, setting_name)
        local arg_value = ffi.cast("int32_t", value)
        local ACallRes, ExceptionOccured = JniChecked_CallStaticBooleanMethod(jni,               
            "android/provider/Settings$System",
            "putInt",
            "(Landroid/content/ContentResolver;Ljava/lang/String;I)Z",
            arg_object,
            arg_name,
            arg_value
        )            
        return ACallRes, ExceptionOccured    
    end)
end

local android_settings_system_get_int = function(setting_name, defvalue)
    -- Check cache first to reduce JNI calls
    local current_time = os.time()
    if settings_cache[setting_name] ~= nil and 
       settings_cache_timestamp[setting_name] ~= nil and
       current_time - settings_cache_timestamp[setting_name] < CACHE_TIMEOUT then
        loclog('Using cached value for ['..setting_name..']', 2)
        return settings_cache[setting_name]
    end
    
    if android == nil or android.jni == nil or android.app == nil then return defvalue end
    
    return android.jni:context(android.app.activity.vm, function(jni)
        loclog('Getting ['..setting_name..'] (default: '..defvalue..')', 2)   
        local arg_object = jni:callObjectMethod(
          android.app.activity.clazz,
          "getContentResolver",
          "()Landroid/content/ContentResolver;"
        )
        local arg_name = jni.env[0].NewStringUTF(jni.env, setting_name)
        local arg_defvalue = ffi.cast("int32_t", defvalue)
        
        local retValue, ExceptionOccured = JniChecked_CallStaticIntMethod(jni,
            "android/provider/Settings$System",
            "getInt",
            "(Landroid/content/ContentResolver;Ljava/lang/String;I)I",
            arg_object,
            arg_name,
            arg_defvalue
        )
            
        if ExceptionOccured then   
            retValue = defvalue
        else
            -- Update cache
            settings_cache[setting_name] = retValue
            settings_cache_timestamp[setting_name] = current_time
        end
            
        loclog('Got: '..retValue, 2)
        return retValue, ExceptionOccured    
    end)
end

-- Streamlined power_enhance_enable handler
local power_enhance_enable_set = function(value, allow_ui_error_message)
    local ok = ActualSleep and android_settings_system_set_int("power_enhance_enable", value) or true
    
    if not ok and allow_ui_error_message then 
        loclog('Failed to set power_enhance_enable, showing UI message', 1)
        pcall(UIManager_show_original, UIManager, 
          InfoMessage:new{text = "KRP: setting power_enhance_enable failed, make sure you set 'Modify system settings' to 'allowed'"})
    end
    
    return ok
end

-- Optimized sleep functions
local function deepsleep_reset(allow_ui_error_message)
    loclog('Resetting deep sleep', 1)
    return power_enhance_enable_set(0, allow_ui_error_message)
end

local function delayed_deepsleep(allow_ui_error_message)
    loclog('Going to deep sleep', 1)
    return power_enhance_enable_set(1, allow_ui_error_message)
end

local function deepsleep_schedule(ms)
    UIManager:unschedule(delayed_deepsleep)
    -- Convert milliseconds to seconds only for the UIManager (API expects seconds)
    local seconds = ms / 1000
    loclog('Scheduling sleep in: '..ms..'ms', 1)
    UIManager:scheduleIn(seconds, delayed_deepsleep, SCHEDULED_SET_ALLOWED_UI_MESSAGE)  
end

-- Calculate optimal sleep delay with memoization support
local last_calculated_delay = nil
local last_avg_reading_time = nil
local function calculate_sleep_delay(avg_time_ms)
    -- Return cached result if input hasn't changed significantly
    if last_calculated_delay ~= nil and last_avg_reading_time ~= nil and
       math.abs(last_avg_reading_time - avg_time_ms) < 100 then
        return last_calculated_delay
    end
    
    local sleep_delay
    if not ADAPTIVE_SLEEP then
        sleep_delay = MIN_SLEEP_DELAY
    elseif avg_time_ms < FAST_READING_THRESHOLD then
        sleep_delay = MAX_SLEEP_DELAY
        loclog('Fast page turning detected: ' .. sleep_delay .. 'ms', 1)
    else
        -- Integer division
        sleep_delay = avg_time_ms / READING_TIME_DIVISOR
        -- Apply min/max bounds
        if sleep_delay < MIN_SLEEP_DELAY then 
            sleep_delay = MIN_SLEEP_DELAY
        elseif sleep_delay > MAX_SLEEP_DELAY then
            sleep_delay = MAX_SLEEP_DELAY
        end
        loclog('Normal reading pace: ' .. sleep_delay .. 'ms', 2)
    end
    
    -- Ensure sleep_delay is an integer
    sleep_delay = math.floor(sleep_delay)
    
    -- Cache result
    last_calculated_delay = sleep_delay
    last_avg_reading_time = avg_time_ms
    
    return sleep_delay
end

-- Main page handler interceptor
local function InterceptReaderWidget(Widget)
    local pageHandler = Widget.paging or Widget.rolling
    if not pageHandler then
        loclog('No compatible page handler found', 1)
        return
    end
    
    loclog('Intercepting page handler', 1)
    local pageHandler_onGotoViewRel_original = pageHandler.onGotoViewRel
    
    pageHandler.onGotoViewRel = function(self, diff)
        -- Use millisecond timestamps for better precision
        local current_time_ms = os.time() * 1000
        
        -- Reset power enhancer first for responsiveness
        deepsleep_reset(false)
        
        -- Update reading time statistics
        if last_page_time ~= nil then
            local reading_time_ms = current_time_ms - last_page_time
            -- Only update if time seems reasonable (prevent outliers)
            if reading_time_ms >= 0 and reading_time_ms < 3600000 then
                -- Integer arithmetic where possible
                avg_reading_time = math.floor((ADAPTIVE_ALPHA * reading_time_ms) + 
                                  ((1 - ADAPTIVE_ALPHA) * avg_reading_time))
                loclog('Reading time: ' .. reading_time_ms .. 'ms, avg: ' .. 
                       avg_reading_time .. 'ms', 2)
            end
        end
        
        last_page_time = current_time_ms
        
        -- Call original function
        pageHandler_onGotoViewRel_original(self, diff)
        
        -- Calculate and schedule sleep with optimized function
        local sleep_delay_ms = calculate_sleep_delay(avg_reading_time)
        deepsleep_schedule(sleep_delay_ms)
    end
    
    -- Initial deep sleep after opening book
    loclog('Initial deep sleep after book open', 1)
    deepsleep_reset(false)    
    deepsleep_schedule(DS_DELAY_INTERCEPT)
end

-- UI manager hook with reduced logging
UIManager.show = function(self, widget, refreshtype, refreshregion, x, y, refreshdither)
    local title = widget.id or widget.name or tostring(widget)
    local originalShowRes = UIManager_show_original(self, widget, refreshtype, refreshregion, x, y, refreshdither)
    
    if title == 'ReaderUI' then
        loclog('ReaderUI detected, intercepting', 1)
        InterceptReaderWidget(widget)
    end
    
    return originalShowRes  
end

-- Log startup message
loclog('mopowen dynamic sleep initialized (v20250409)', 1)