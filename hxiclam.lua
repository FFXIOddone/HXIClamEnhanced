
-- hxiclam.lua
-- HXIClam (All-In-One) - Ashita v4
-- Single-file version with full feature set: constants, util, display, settings UI (including Index Field Editor),
-- analytics, achievements, discord webhooks, cloud/mobile export, logs.


addon.name     = 'hxiclam';
addon.author   = 'jimmy58663 (Oddone Edit) - Enhanced Mono File';
addon.version  = '3.0.3';
addon.desc     = 'HorizonXI clamming tracker with analytics, webhooks, cloud export.';
addon.link     = 'https://github.com/jimmy58663/HXIClam';
addon.commands = {'/hxiclam'};



local constants = require('modules.constants')
local utils = require('modules.utils')
local fileio = require('modules.fileio')
local analytics = require('modules.analytics')
local display = require('modules.display')
local sound = require('modules.sound')
local discord = require('modules.discord')
local state = require('modules.state')
local events = require('modules.events')

-- BASE directory for file operations (empty string means current dir)
BASE = ''

-- Replace T{} with {} for all usages (Ashita v4+)
function T(t)
    return t or {}
end

-- WriteLog stub (should be implemented in fileio module)
function WriteLog(...)
    if fileio and fileio.WriteLog then
        return fileio.WriteLog(...)
    else
        -- fallback: do nothing or print
        -- print('WriteLog called', ...)
    end
end

-- Utility function aliases
local format_int = utils.format_int
local format_time_hms = utils.format_time_hms
local deepcopy = utils.deepcopy
local parse_pairs = utils.parse_pairs

-- Global state table for the addon
H = {
    settings = nil,
    pricing = {},
    move = {},
    gil_per_hour = 0,
    last_analytics_update = 0,
    play_tone = false,
    _ui_export_csv = false,
    _idx = {},
    session_milestones_hit = {},
}

-- Initialize settings with defaults if not loaded
if not H.settings then
    H.settings = utils.deepcopy(default_settings)
end

require('common');
local chat     = require('chat');
local d3d      = require('d3d8');
local ffi      = require('ffi');
local imgui    = require('imgui');
local settings = require('settings');


local C       = ffi.C;
local d3d8dev = d3d.get_device();

-- Standard Display Rendering Function
local function render_standard_display(H_)
    -- Calculate elapsed time
    local elapsed = ashita.time.clock()['s'] - math.floor(H_.settings.first_attempt / 1000.0)
    if elapsed < 0 then elapsed = 0 end

    -- Calculate total worth
    local total_worth = 0
    for k, v in pairs(H_.settings.rewards) do
        if H_.pricing[k] then total_worth = total_worth + (H_.pricing[k] * v) end
    end

    imgui.TextColored(H_.settings.colors.session_label_color, 'Buckets Cost:')
    imgui.SameLine()
    imgui.TextColored(H_.settings.colors.session_value_color, tostring(H_.settings.bucket_count * H_.settings.clamming.bucket_cost[1]))

end
-- (moved into default_settings table below)
-- State / Settings / IO
---------------------------------------------------------------------------------------------------
local LOGS = {
    drop_log_dir   = 'drops',
    turnin_log_dir = 'turnins',
    backup_log_dir = 'backups',
    export_log_dir = 'exports',
    char_name      = nil
}

local default_settings = {
    visible = { true },
    moon_display = { false },
    display_timeout = { 600 },
    opacity = { 1.0 },
    padding = { 1.0 },
    scale = { 1.0 },
    item_index = ItemIndex,
    item_weight_index = ItemWeightIndex,
    font_scale = { 1.0 },
    show_item_quantities = { true },
    show_item_values = { true },
    first_attempt = 0,
    display_mode = { 2 }, -- 1=minimal, 2=standard, 3=detailed, 4=overlay
    reset_on_load = { false },

    available_tones = { 'clam.wav' },
    tone_selected_idx = 1,
    tone = 'clam.wav',
    enable_tone = { true },

    dig_timer = 0,
    dig_timer_countdown = true,
    last_dig = 0,

    bucket = {},
    rewards = {},
    bucket_weight = 0,
    bucket_capacity = 50,
    has_bucket = false,
    bucket_count = 0,
    item_count = 0,

    session_view = 2,
    gil_per_hour = 0,

    clamming = {
        bucket_cost = { 500 },
        bucket_subtract = { true },
        stop_values = { [50]={1200},[100]={2400},[150]={3600},[200]={4800} },
        stop_weights_under_value = { [50]={4},[100]={6},[150]={8},[200]={10} },
        stop_weights_over_value  = { [50]={6},[100]={8},[150]={10},[200]={12} },
        stop_colors = { [50]={1,0.55,0,1},[100]={1,0.55,0,1},[150]={1,0.55,0,1},[200]={1,0.55,0,1} },
        color_logic_advanced = { true },
    },

    analytics = {
        enabled = { true },
        efficiency_history = {},
        item_frequency = {},
    },

    notifications = {
        enabled = { true },
        milestone_index = { 1 },
        profit_milestones = { 500, 1000, 2500, 5000, 10000, 20000 },
        sound_enabled = { true },
        efficiency_warnings = { true },
        break_reminders = { true },
        break_reminder_interval = { 3600 },
    },

    milestones_dynamic = {
        enabled = { true },
        scale = { 1.5 },
        min_gap = { 1000 },
    },

    summary = {
        one_click_enabled = { true },
        include_items = { true },
        include_zones = { true },
        send_to_discord = { false },
        save_as_file = { true },
    },

    autoscreenshot = {
        enabled = { false }, on_milestone = { true }, on_rare_item = { true }, on_best_streak = { true },
    },

    zone_tracking = {
        enabled = { true },
        current_zone = { '' },
        zone_start_time = { 0 },
        zone_stats = {},
    },

    discord = {
        enabled = { false },
        webhook_url = { '' },
        queue_limit = { 50 },
        max_per_minute = { 10 },
        send_milestones = { true },
        send_streaks = { true },
        send_summaries = { true },
    },

    achievements = {
        enabled = { true },
        unlocked = {},
        webhook  = { true },
    },

    smart = {
        turnin_enabled = { false },
        turnin_aggressiveness = { 0.5 },
        show_banner = { true },
    },

    heatmap = { enabled = { false }, },

    sound_themes = {
        enabled = { false },
        theme = { 'default' },
        files = { default = { ready='clam.wav', milestone='clam.wav' } }
    },

    leaderboard = {
        enabled = { false },
        display_name = { 'Clammer' },
        privacy = { 'private' },
        share_discord = { false },
    },

    auto_backup_enabled = { false },
    auto_backup_interval = { 900 },

    export_format = { 1 }, -- 1=CSV, 2=JSON

    cloud = {
        enabled = { false },
        path = { '' },
    },

    mobile = {
        enabled = { false },
        out_path = { '' },
    },

    colors = {
        window_bg_color={0.06,0.06,0.07,0.94}, child_bg_color={0.06,0.06,0.07,0.60}, popup_bg_color={0.08,0.08,0.09,0.94},
        border_color={0.20,0.20,0.20,0.60}, border_shadow_color={0,0,0,0},
        text_color={0.86,0.86,0.86,1.00}, text_disabled_color={0.50,0.50,0.50,1.00},
        session_label_color={0.70,0.70,0.80,1.00}, session_value_color={0.90,0.90,0.95,1.00},
        session_header_color={0.90,0.90,1.00,1.00}, session_total_label_color={0.90,0.90,0.95,1.00}, session_total_value_color={0.80,1.00,0.80,1.00},
        session_time_color={0.85,0.85,0.95,1.00},
        revenue_label_color={0.80,0.90,1.00,1.00}, revenue_amount_color={0.80,0.95,0.80,1.00},
        profit_label_color={0.95,0.95,0.80,1.00}, profit_amount_positive_color={0.50,1.00,0.50,1.00}, profit_amount_negative_color={1.00,0.50,0.50,1.00},
        profit_percentage_tiers = { {percent={25}, color={0.85,0.85,0.85,1}}, {percent={50}, color={0.70,1.00,0.70,1}}, {percent={100}, color={0.30,1.00,0.30,1}}, },
        use_percentage_profit_colors = { true },
        has_bucket_color={0.80,1.00,0.85,1.00}, no_bucket_color={1.00,0.70,0.70,1.00},
        bucket_item_name_color={0.90,0.90,0.90,1.00}, bucket_item_count_color={0.95,0.95,0.80,1.00}, bucket_item_value_color={0.80,0.95,0.80,1.00},
        dig_timer_normal_color={0.85,0.85,0.90,1.00}, dig_timer_ready_color={0.50,1.00,0.50,1.00},
        bucket_weight_warn_color={1.00,0.80,0.35,1.00}, bucket_weight_crit_color={1.00,0.40,0.40,1.00},
        bucket_weight_warn_threshold={8}, bucket_weight_crit_threshold={4},
        zone_label_color={0.85,0.85,0.90,1.00}, zone_value_color={0.90,0.95,1.00,1.00},
        milestone_color={0.90,1.00,0.90,1.00},
        bucket_weight_font_scale={1.0},
        efficiency_good_color={0.50,1.00,0.50,1.00}, efficiency_warning_color={1.00,0.80,0.35,1.00}, efficiency_poor_color={1.00,0.40,0.40,1.00},
        session_gph_color={0.80,0.90,1.00,1.00}, moon_display_color={0.85,0.85,0.95,1.00},
    },

    editor = { is_open = { false } },
    last_break_reminder = 0,
}

local function vana_timestamp()
    local ok, t = pcall(function()
        local pointer = AshitaCore:GetMemoryManager():GetTime()
        local rawTime   = ashita.memory.read_uint32(pointer + 0x0C) + 92514960
        local ts        = {}
        ts.day    = math.floor(rawTime / 3456)
        ts.hour   = math.floor(rawTime / 144) % 24
        ts.minute = math.floor((rawTime % 144) / 2.4)
        return ts
    end)
    if ok then return t end
    return { day = 0, hour = 0, minute = 0 }
end

local function get_moon()
    local ts = vana_timestamp()
    local idx = ((ts.day + 26) % 84) + 1
    local ph  = MoonPhase[idx] or 'Waxing'
    local pct = MoonPhasePercent[idx] or 50
    return { MoonPhase = ph, MoonPhasePercent = pct }
end

local _zone_cache = { id = -1, name = 'Unknown' }

local function get_current_zone()
    local ok, zname = pcall(function()
        local mm = AshitaCore and AshitaCore:GetMemoryManager()
        if not mm then return _zone_cache.name end

        local zid = nil
        local party = mm:GetParty()
        if party and party.GetMemberZone then
            zid = party:GetMemberZone(0)
        end

        if (not zid or zid <= 0) then
            local player = mm:GetPlayer()
            if player and player.GetZone then
                zid = player:GetZone()
            end
        end

        if not zid or zid <= 0 then
            return _zone_cache.name
        end

        if _zone_cache.id == zid and _zone_cache.name then
            return _zone_cache.name
        end

        local rm = AshitaCore:GetResourceManager()
        local name = nil
        if rm and rm.GetString then
            name = rm:GetString('zones', zid)
            if not name or #name == 0 then
                name = rm:GetString('areas', zid)
            end
        end

        name = (name and #name > 0) and name or string.format('Zone #%d', zid)

        _zone_cache.id = zid
        _zone_cache.name = name
        return name
    end)

    return (ok and zname) or (_zone_cache.name or 'Unknown')
end

local function update_zone_tracking(H_)
    if not H_ or not H_.settings.zone_tracking.enabled[1] then return end
    local cur  = get_current_zone()
    local prev = H_.settings.zone_tracking.current_zone[1]
    if cur ~= prev then
        if prev ~= '' and H_.settings.zone_tracking.zone_start_time[1] > 0 then
            local t  = ashita.time.clock()['s'] - H_.settings.zone_tracking.zone_start_time[1]
            local zs = H_.settings.zone_tracking.zone_stats
            zs[prev] = zs[prev] or { profit=0, items=0, time=0, buckets=0 }
            zs[prev].time = (zs[prev].time or 0) + t
        end
        H_.settings.zone_tracking.current_zone[1] = cur
        H_.settings.zone_tracking.zone_start_time[1] = ashita.time.clock()['s']
        if chat then print(chat.header('hxiclam'):append(chat.message('Zone changed to: ' .. cur))) end
    end
end

---------------------------------------------------------------------------------------------------
-- Sound Functions
---------------------------------------------------------------------------------------------------
local function update_tones(H_)
    if not H_ then return end
    H_.settings.available_tones = {}
    local tone_path = string.format('%stones/', BASE)
    local cmd = 'cmd /C dir "' .. tone_path .. '" /B'
    local idx = 1
    local p = io.popen(cmd)
    if p then
        for file in p:lines() do
            if file:match('%.wav$') then
                H_.settings.available_tones[idx] = file
                idx = idx + 1
            end
        end
        p:close()
    end
    if idx == 1 then H_.settings.available_tones[1] = 'clam.wav' end
end

local function maybe_play_ready_tone(H_)
    if not H_ then return end
    if H_.settings.enable_tone[1] and H_.play_tone == true then
        pcall(function() ashita.misc.play_sound(("%stones/%s"):format(BASE, H_.settings.tone)) end)
        H_.play_tone = false
    end
end

---------------------------------------------------------------------------------------------------
-- Stop Parameters and Color Functions
---------------------------------------------------------------------------------------------------
local function _nearest_cap_key(tbl, cap)
    local best_k, best = nil, math.huge
    for k, _ in pairs(tbl or {}) do
        if type(k) == 'number' then
            local d = math.abs((cap or 0) - k)
            if d < best then best, best_k = d, k end
        end
    end
    return best_k
end

local function _stop_params(H_, cap)
    local S = H_.settings.clamming
    local k = (S.stop_values[cap] and cap) or _nearest_cap_key(S.stop_values, cap) or 50
    local sv = (S.stop_values[k]                 and S.stop_values[k][1])                 or 0
    local su = (S.stop_weights_under_value[k]    and S.stop_weights_under_value[k][1])    or 0
    local so = (S.stop_weights_over_value[k]     and S.stop_weights_over_value[k][1])     or 0
    local sc = (S.stop_colors[k]) or {1,0.55,0,1}
    return sv, su, so, sc
end

local function _opt_threshold(H_, name)
    return (H_.settings[name] and H_.settings[name][1])
        or (H_.settings.colors and H_.settings.colors[name] and H_.settings.colors[name][1])
        or 0
end

local function _opt_color(H_, name, def)
    return (H_.settings[name])
        or (H_.settings.colors and H_.settings.colors[name])
        or def
end

local function updateWeightColor(H_, bucketSize, bucketWeight, money)
    local defaultColor = {0.50, 1.00, 0.50, 1.00}
    local remain = math.max(0, (bucketSize or 0) - (bucketWeight or 0))

    if H_.settings.clamming.color_logic_advanced and H_.settings.clamming.color_logic_advanced[1] then
        local S  = H_.settings.clamming
        local cap= bucketSize or 0

        local stopProfitValue = (S.stop_values[cap]                 and S.stop_values[cap][1])              or 0
        local stopWeightUnder = (S.stop_weights_under_value[cap]    and S.stop_weights_under_value[cap][1]) or 0
        local stopWeightOver  = (S.stop_weights_over_value[cap]     and S.stop_weights_over_value[cap][1])  or 0
        local stopColor       = (S.stop_colors[cap]) or {1,0.55,0,1}

        local currentProfit = (money or 0)
        if S.bucket_subtract and S.bucket_subtract[1] then
            currentProfit = currentProfit - (S.bucket_cost and S.bucket_cost[1] or 0)
        end

        if currentProfit >= stopProfitValue then
            if stopWeightOver > 0 and remain <= stopWeightOver then
                return stopColor
            end
        else
            if stopWeightUnder > 0 and remain <= stopWeightUnder then
                return stopColor
            end
        end
        return defaultColor
    end

    local crit = _opt_threshold(H_, 'bucket_weight_crit_threshold')
    if remain <= crit then return _opt_color(H_, 'bucket_weight_crit_color', {1,0,0,1}) end

    local warn = _opt_threshold(H_, 'bucket_weight_warn_threshold')
    if remain <= warn then return _opt_color(H_, 'bucket_weight_warn_color', {1,0.8,0.35,1}) end

    return defaultColor
end

local function getProfitPercentageColor(H_, bucketSize, currentProfit)
    if (currentProfit or 0) < 0 then
        return H_.settings.colors.profit_amount_negative_color
    end

    -- Only use percentage-based profit colors if both toggles are enabled
    local advanced = H_.settings.clamming.color_logic_advanced and H_.settings.clamming.color_logic_advanced[1]
    local usePct = H_.settings.colors.use_percentage_profit_colors and H_.settings.colors.use_percentage_profit_colors[1]
    if not (advanced and usePct) then
        return H_.settings.colors.profit_amount_positive_color
    end

    local stopValue = (_stop_params(H_, bucketSize or 0))
    if (stopValue or 0) <= 0 then
        return H_.settings.colors.profit_amount_positive_color
    end

    local pct = (currentProfit / stopValue) * 100
    local tiers = H_.settings.colors.profit_percentage_tiers or {}

    table.sort(tiers, function(a, b)
        local pa = (a.percent and a.percent[1]) or 0
        local pb = (b.percent and b.percent[1]) or 0
        return pa < pb
    end)

    local chosen = H_.settings.colors.profit_amount_positive_color
    for i = 1, #tiers do
        local th = (tiers[i].percent and tiers[i].percent[1]) or 0
        if pct >= th then
            chosen = tiers[i].color or chosen
        else
            break
        end
    end
    return chosen
end

---------------------------------------------------------------------------------------------------
-- ImGui Style Functions
---------------------------------------------------------------------------------------------------
local COLOR_DEFAULTS = {
    ui = {
        window_bg_color             = {0.06,0.06,0.07,0.94},
        child_bg_color              = {0.06,0.06,0.07,0.60},
        popup_bg_color              = {0.08,0.08,0.09,0.94},
        border_color                = {0.20,0.20,0.20,0.60},
        border_shadow_color         = {0,0,0,0},
        frame_bg_color              = {0.16,0.16,0.20,1.00},
        frame_bg_hovered_color      = {0.20,0.20,0.26,1.00},
        frame_bg_active_color       = {0.20,0.22,0.28,1.00},
        title_bg_color              = {0.10,0.10,0.12,1.00},
        title_bg_active_color       = {0.12,0.12,0.14,1.00},
        title_bg_collapsed_color    = {0.10,0.10,0.12,0.80},
        menubar_bg_color            = {0.10,0.10,0.12,1.00},
        scrollbar_bg_color          = {0.05,0.05,0.06,1.00},
        scrollbar_grab_color        = {0.28,0.28,0.30,1.00},
        scrollbar_grab_hovered_color= {0.34,0.34,0.36,1.00},
        scrollbar_grab_active_color = {0.38,0.38,0.40,1.00},
        checkmark_color             = {0.26,0.59,0.98,1.00},
        slider_grab_color           = {0.26,0.59,0.98,0.78},
        slider_grab_active_color    = {0.26,0.59,0.98,1.00},
        button_color                = {0.20,0.27,0.41,0.62},
        button_hovered_color        = {0.26,0.59,0.98,0.66},
        button_active_color         = {0.26,0.59,0.98,1.00},
        header_color                = {0.26,0.59,0.98,0.31},
        header_hovered_color        = {0.26,0.59,0.98,0.80},
        header_active_color         = {0.26,0.59,0.98,1.00},
        separator_color             = {0.43,0.43,0.50,0.50},
        separator_hovered_color     = {0.10,0.40,0.75,0.78},
        separator_active_color      = {0.10,0.40,0.75,1.00},
        resize_grip_color           = {0.26,0.59,0.98,0.20},
        resize_grip_hovered_color   = {0.26,0.59,0.98,0.66},
        resize_grip_active_color    = {0.26,0.59,0.98,1.00},
        tab_color                   = {0.11,0.15,0.24,1.00},
        tab_hovered_color           = {0.18,0.27,0.43,1.00},
        tab_active_color            = {0.20,0.32,0.57,1.00},
        tab_unfocused_color         = {0.07,0.10,0.17,1.00},
        tab_unfocused_active_color  = {0.14,0.20,0.35,1.00},
        docking_preview_color       = {0.26,0.59,0.98,0.70},
        docking_empty_bg_color      = {0.20,0.20,0.22,1.00},
        nav_highlight_color         = {0.26,0.59,0.98,1.00},
        nav_windowing_highlight_color = {1.00,1.00,1.00,0.70},
        nav_windowing_dim_bg_color  = {0.80,0.80,0.80,0.20},
        modal_window_dim_bg_color   = {0.80,0.80,0.80,0.35},
        text_color                  = {0.86,0.86,0.86,1.00},
        text_disabled_color         = {0.50,0.50,0.50,1.00},
    },
    domain = {
        session_label_color             = {0.70,0.70,0.80,1.00},
        session_value_color             = {0.90,0.90,0.95,1.00},
        session_header_color            = {0.90,0.90,1.00,1.00},
        session_total_label_color       = {0.90,0.90,0.95,1.00},
        session_total_value_color       = {0.80,1.00,0.80,1.00},
        session_time_color              = {0.85,0.85,0.95,1.00},
        revenue_label_color             = {0.80,0.90,1.00,1.00},
        revenue_amount_color            = {0.80,0.95,0.80,1.00},
        profit_label_color              = {0.95,0.95,0.80,1.00},
        profit_amount_positive_color    = {0.50,1.00,0.50,1.00},
        profit_amount_negative_color    = {1.00,0.50,0.50,1.00},
        has_bucket_color                = {0.80,1.00,0.85,1.00},
        no_bucket_color                 = {1.00,0.70,0.70,1.00},
        bucket_item_name_color          = {0.90,0.90,0.90,1.00},
        bucket_item_count_color         = {0.95,0.95,0.80,1.00},
        bucket_item_value_color         = {0.80,0.95,0.80,1.00},
        dig_timer_normal_color          = {0.85,0.85,0.90,1.00},
        dig_timer_ready_color           = {0.50,1.00,0.50,1.00},
        bucket_weight_warn_color        = {1.00,0.80,0.35,1.00},
        bucket_weight_crit_color        = {1.00,0.40,0.40,1.00},
        zone_label_color                = {0.85,0.85,0.90,1.00},
        zone_value_color                = {0.90,0.95,1.00,1.00},
        milestone_color                 = {0.90,1.00,0.90,1.00},
        efficiency_good_color           = {0.50,1.00,0.50,1.00},
        efficiency_warning_color        = {1.00,0.80,0.35,1.00},
        efficiency_poor_color           = {1.00,0.40,0.40,1.00},
        session_gph_color               = {0.80,0.90,1.00,1.00},
        moon_display_color              = {0.85,0.85,0.95,1.00},
    },
    tiers = {
        { percent = T{25},  color = {0.85,0.85,0.85,1.00} },
        { percent = T{50},  color = {0.70,1.00,0.70,1.00} },
        { percent = T{100}, color = {0.30,1.00,0.30,1.00} },
    }
}

local function push_imgui_style(COL)
    if not imgui then return 0 end
    local n = 0
    local function P(idx, key, def)
        local c = ensure_color(COL, key, def)
        imgui.PushStyleColor(idx, { c[1], c[2], c[3], c[4] })
        n = n + 1
    end
    local D = {
        text     = {0.86,0.86,0.86,1.00}, text_dis = {0.50,0.50,0.50,1.00},
        winbg    = {0.06,0.06,0.07,0.94}, child   = {0.06,0.06,0.07,0.60}, popup={0.08,0.08,0.09,0.94},
        border   = {0.20,0.20,0.20,0.60}, bshadow = {0,0,0,0},
        fbg      = {0.16,0.16,0.20,1.00}, fhov    = {0.20,0.20,0.26,1.00}, fact = {0.20,0.22,0.28,1.00},
        title    = {0.10,0.10,0.12,1.00}, tactive = {0.12,0.12,0.14,1.00}, tcoll={0.10,0.10,0.12,0.80},
        menubg   = {0.10,0.10,0.12,1.00},
        sbbg     = {0.05,0.05,0.06,1.00}, sbg     = {0.28,0.28,0.30,1.00}, sbgh={0.34,0.34,0.36,1.00}, sbga={0.38,0.38,0.40,1.00},
        check    = {0.26,0.59,0.98,1.00},
        sgrab    = {0.26,0.59,0.98,0.78}, sgraba  = {0.26,0.59,0.98,1.00},
        btn      = {0.20,0.27,0.41,0.62}, btnh    = {0.26,0.59,0.98,0.66}, btna={0.26,0.59,0.98,1.00},
        header   = {0.26,0.59,0.98,0.31}, headerh = {0.26,0.59,0.98,0.80}, headera={0.26,0.59,0.98,1.00},
        sep      = {0.43,0.43,0.50,0.50}, seph    = {0.10,0.40,0.75,0.78}, sepa={0.10,0.40,0.75,1.00},
        grip     = {0.26,0.59,0.98,0.20}, griph   = {0.26,0.59,0.98,0.66}, gripa={0.26,0.59,0.98,1.00},
        tab      = {0.11,0.15,0.24,1.00}, tabh    = {0.18,0.27,0.43,1.00}, taba={0.20,0.32,0.57,1.00},
        tabun    = {0.07,0.10,0.17,1.00}, tabuna  = {0.14,0.20,0.35,1.00},
        dockp    = {0.26,0.59,0.98,0.70}, dockbg  = {0.20,0.20,0.22,1.00},
        navhi    = {0.26,0.59,0.98,1.00}, navwh   = {1.00,1.00,1.00,0.70}, navdim={0.80,0.80,0.80,0.20},
        modaldim = {0.80,0.80,0.80,0.35}
    }
    P(FG('ImGuiCol_Text'),               'text_color',               D.text)
    P(FG('ImGuiCol_TextDisabled'),       'text_disabled_color',      D.text_dis)
    P(FG('ImGuiCol_WindowBg'),           'window_bg_color',          D.winbg)
    P(FG('ImGuiCol_ChildBg'),            'child_bg_color',           D.child)
    P(FG('ImGuiCol_PopupBg'),            'popup_bg_color',           D.popup)
    P(FG('ImGuiCol_Border'),             'border_color',             D.border)
    P(FG('ImGuiCol_BorderShadow'),       'border_shadow_color',      D.bshadow)
    P(FG('ImGuiCol_FrameBg'),            'frame_bg_color',           D.fbg)
    P(FG('ImGuiCol_FrameBgHovered'),     'frame_bg_hovered_color',   D.fhov)
    P(FG('ImGuiCol_FrameBgActive'),      'frame_bg_active_color',    D.fact)
    P(FG('ImGuiCol_TitleBg'),            'title_bg_color',           D.title)
    P(FG('ImGuiCol_TitleBgActive'),      'title_bg_active_color',    D.tactive)
    P(FG('ImGuiCol_TitleBgCollapsed'),   'title_bg_collapsed_color', D.tcoll)
    P(FG('ImGuiCol_MenuBarBg'),          'menubar_bg_color',         D.menubg)
    P(FG('ImGuiCol_ScrollbarBg'),        'scrollbar_bg_color',       D.sbbg)
    P(FG('ImGuiCol_ScrollbarGrab'),      'scrollbar_grab_color',     D.sbg)
    P(FG('ImGuiCol_ScrollbarGrabHovered'),'scrollbar_grab_hovered_color', D.sbgh)
    P(FG('ImGuiCol_ScrollbarGrabActive'),'scrollbar_grab_active_color',   D.sbga)
    P(FG('ImGuiCol_CheckMark'),          'checkmark_color',          D.check)
    P(FG('ImGuiCol_SliderGrab'),         'slider_grab_color',        D.sgrab)
    P(FG('ImGuiCol_SliderGrabActive'),   'slider_grab_active_color', D.sgraba)
    P(FG('ImGuiCol_Button'),             'button_color',             D.btn)
    P(FG('ImGuiCol_ButtonHovered'),      'button_hovered_color',     D.btnh)
    P(FG('ImGuiCol_ButtonActive'),       'button_active_color',      D.btna)
    P(FG('ImGuiCol_Header'),             'header_color',             D.header)
    P(FG('ImGuiCol_HeaderHovered'),      'header_hovered_color',     D.headerh)
    P(FG('ImGuiCol_HeaderActive'),       'header_active_color',      D.headera)
    P(FG('ImGuiCol_Separator'),          'separator_color',          D.sep)
    P(FG('ImGuiCol_SeparatorHovered'),   'separator_hovered_color',  D.seph)
    P(FG('ImGuiCol_SeparatorActive'),    'separator_active_color',   D.sepa)
    P(FG('ImGuiCol_ResizeGrip'),         'resize_grip_color',        D.grip)
    P(FG('ImGuiCol_ResizeGripHovered'),  'resize_grip_hovered_color',D.griph)
    P(FG('ImGuiCol_ResizeGripActive'),   'resize_grip_active_color', D.gripa)
    P(FG('ImGuiCol_Tab'),                'tab_color',                D.tab)
    P(FG('ImGuiCol_TabHovered'),         'tab_hovered_color',        D.tabh)
    P(FG('ImGuiCol_TabActive'),          'tab_active_color',         D.taba)
    P(FG('ImGuiCol_TabUnfocused'),       'tab_unfocused_color',      D.tabun)
    P(FG('ImGuiCol_TabUnfocusedActive'), 'tab_unfocused_active_color', D.tabuna)
    P(FG('ImGuiCol_DockingPreview'),     'docking_preview_color',    D.dockp)
    P(FG('ImGuiCol_DockingEmptyBg'),     'docking_empty_bg_color',   D.dockbg)
    P(FG('ImGuiCol_NavHighlight'),       'nav_highlight_color',      D.navhi)
    P(FG('ImGuiCol_NavWindowingHighlight'),'nav_windowing_highlight_color', D.navwh)
    P(FG('ImGuiCol_NavWindowingDimBg'),  'nav_windowing_dim_bg_color', D.navdim)
    P(FG('ImGuiCol_ModalWindowDimBg'),   'modal_window_dim_bg_color', D.modaldim)
    return n
end

local function pop_imgui_style(n) if imgui and n and n > 0 then imgui.PopStyleColor(n) end end

local function help(text)
    if not (imgui and text) then return end
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(420)
        imgui.TextUnformatted(text)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

---------------------------------------------------------------------------------------------------
-- Discord Webhook Functions
---------------------------------------------------------------------------------------------------
local DiscordQ = { _q = {} }

local function discord_enqueue(H_, content)
    if not (H_.settings.discord.enabled[1]) then return end
    local url = H_.settings.discord.webhook_url[1]
    if not url or url == '' then return end
    if not have_json then return end
    local payload = json.encode({ content = content })
    local q = DiscordQ._q
    q[#q + 1] = { url = url, json = payload }
    local limit = H_.settings.discord.queue_limit[1]
    if #q > limit then table.remove(q, 1) end
end

local function discord_process(H_)
    if not (H_.settings.discord.enabled[1] and have_http and have_ltn12) then return end
    local max_per_min = H_.settings.discord.max_per_minute[1]
    local sent = 0
    local q = DiscordQ._q
    while #q > 0 and sent < max_per_min do
        local item = table.remove(q, 1)
        if item then
            pcall(function()
                http.request{
                    method = 'POST',
                    url = item.url,
                    headers = { ['Content-Type']='application/json', ['Content-Length']=tostring(#item.json) },
                    source = ltn12.source.string(item.json),
                    sink   = ltn12.sink.null()
                }
            end)
        end
        sent = sent + 1
    end
end

---------------------------------------------------------------------------------------------------
-- Analytics Functions
---------------------------------------------------------------------------------------------------
local function total_session_profit_now(H_)
    local total = 0
    for k, v in pairs(H_.settings.rewards) do
        if H_.pricing[k] then total = total + (H_.pricing[k] * v) end
    end
    if H_.settings.clamming.bucket_subtract[1] then
        total = total - (H_.settings.bucket_count * H_.settings.clamming.bucket_cost[1])
    end
    return total
end

local function analytics_initialize(H_)
    H_.last_analytics_update = ashita.time.clock()['s']
    H_.current_efficiency = 0
    H_.efficiency_trend = 'stable'
    H_.session_milestones_hit = T{}
end

local function calc_eff(H_)
    local elapsed = ashita.time.clock()['s'] - math.floor(H_.settings.first_attempt / 1000.0)
    if elapsed <= 0 or H_.settings.item_count <= 0 then return 0 end
    return (H_.settings.item_count / elapsed) * 3600
end

local function analytics_update(H_)
    if not H_.settings.analytics.enabled[1] then return end
    local now = ashita.time.clock()['s']
    if now - H_.last_analytics_update < 30 then return end

    H_.current_efficiency = calc_eff(H_)
    local hist = H_.settings.analytics.efficiency_history
    hist[#hist + 1] = { time = now, efficiency = H_.current_efficiency }
    if #hist > 240 then table.remove(hist, 1) end

    if #hist >= 10 then
        local half = math.floor(#hist / 2)
        local older, recent = 0, 0
        for i = 1, half do older = older + hist[i].efficiency end
        for i = half + 1, #hist do recent = recent + hist[i].efficiency end
        older = older / half; recent = recent / half
        local change = older ~= 0 and ((recent - older) / older) * 100 or 0
        if change > 10 then H_.efficiency_trend = 'improving'
        elseif change < -10 then H_.efficiency_trend = 'declining'
        else H_.efficiency_trend = 'stable' end
    end

    H_.last_analytics_update = now
end

local function analytics_check_profit_milestones(H_)
    if not H_.settings.notifications.enabled[1] then return end
    local total = total_session_profit_now(H_)
    local idx   = H_.settings.notifications.milestone_index[1]
    local miles = H_.settings.notifications.profit_milestones
    if idx <= #miles and total >= miles[idx] then
        local v = miles[idx]
        if chat then
            print(chat.header('hxiclam'):append(chat.color1(6, ' Milestone reached! Total profit: ' .. format_int(v) .. ' gil')))
        end
        if H_.settings.notifications.sound_enabled[1] then
            pcall(function() ashita.misc.play_sound(("%stones/%s"):format(BASE, H_.settings.tone)) end)
        end
        H_.settings.notifications.milestone_index[1] = idx + 1
        table.insert(H_.session_milestones_hit, { time = ashita.time.clock()['s'], value = v })
        if H_.settings.discord.send_milestones[1] then discord_enqueue(H_, ('Milestone reached: %s gil'):format(tostring(v))) end
        if H_.settings.milestones_dynamic.enabled[1] then
            local scale = H_.settings.milestones_dynamic.scale[1] or 1.5
            local nextv = math.max(v + (H_.settings.milestones_dynamic.min_gap[1] or 500), math.floor(v * scale))
            table.insert(H_.settings.notifications.profit_milestones, nextv)
        end
    end
end

local function analytics_check_efficiency_warnings(H_)
    if not (H_.settings.notifications.enabled[1] and H_.settings.notifications.efficiency_warnings[1]) then return end
    if H_.efficiency_trend == 'declining' and H_.current_efficiency > 0 then
        local avg = 0
        local hist = H_.settings.analytics.efficiency_history
        for _, e in ipairs(hist) do avg = avg + e.efficiency end
        if #hist > 0 then avg = avg / #hist end
        if #hist > 0 and H_.current_efficiency < (avg * 0.70) then
            if chat then print(chat.header('hxiclam'):append(chat.color1(8, ' Efficiency declining! Consider a short break.'))) end
        end
    end
end

local function analytics_check_break_reminders(H_)
    if not (H_.settings.notifications.enabled[1] and H_.settings.notifications.break_reminders[1]) then return end
    local now = ashita.time.clock()['s']
    local interval = H_.settings.notifications.break_reminder_interval[1]
    if H_.settings.last_break_reminder == 0 then
        H_.settings.last_break_reminder = now
    elseif now - H_.settings.last_break_reminder >= interval then
        local elapsed = now - math.floor(H_.settings.first_attempt / 1000.0)
        if chat then
            print(chat.header('hxiclam'):append(chat.color1(11, ' Break reminder: You have been clamming for ' .. format_time_hms(elapsed) .. '.')))
        end
        H_.settings.last_break_reminder = now
    end
end

local function analytics_after_item_dug(H_, item)
    if H_.settings.analytics.enabled[1] then
        local f = H_.settings.analytics.item_frequency
        f[item] = (f[item] or 0) + 1
    end
end

local function analytics_after_bucket_turnin(_) end
local function analytics_after_bucket_fail(_) end

local function analytics_optimize_memory(H_)
    local now = ashita.time.clock()['s']
    local cutoff = now - 7200
    local hist = H_.settings.analytics.efficiency_history
    local keep = T{}
    for _, e in ipairs(hist) do if e.time > cutoff then keep[#keep + 1] = e end end
    H_.settings.analytics.efficiency_history = keep
    if #H_.session_milestones_hit > 20 then
        local nm = T{}
        for i = #H_.session_milestones_hit - 19, #H_.session_milestones_hit do nm[#nm + 1] = H_.session_milestones_hit[i] end
        H_.session_milestones_hit = nm
    end
end

local function one_click_summary(H_)
    local total = total_session_profit_now(H_)
    local lines = {}
    lines[#lines + 1] = 'HXIClam Summary'
    lines[#lines + 1] = 'Profit: ' .. format_int(total) .. ' gil'
    lines[#lines + 1] = 'Items: ' .. tostring(H_.settings.item_count)
    if H_.settings.summary.include_zones[1] then
        lines[#lines + 1] = 'Zones:'
        for z, st in pairs(H_.settings.zone_tracking.zone_stats) do
            lines[#lines + 1] = ' - ' .. z .. ' : ' .. format_int(st.profit or 0) .. ' gil'
        end
    end
    if H_.settings.summary.include_items[1] then
        lines[#lines + 1] = 'Top Items:'
        for k,v in pairs(H_.settings.rewards) do
            local val = (H_.pricing[k] or 0) * v
            lines[#lines + 1] = ' - ' .. k .. ' x' .. tostring(v) .. ' = ' .. format_int(val)
        end
    end
    local text = table.concat(lines, '\n')
    if H_.settings.summary.send_to_discord[1] then discord_enqueue(H_, text) end
    if H_.settings.summary.save_as_file[1] then
        local install = AshitaCore and AshitaCore:GetInstallPath() or ''
        if install ~= '' then
            local dt = os.date('*t')
            local dir = ('%s/addons/hxiclam/exports'):format(install)
            if not ashita.fs.exists(dir) then ashita.fs.create_dir(dir) end
            local fname = ('summary_%04d%02d%02d_%02d%02d%02d.txt'):format(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec)
            local fp = io.open(dir .. '/' .. fname, 'wb'); if fp then fp:write(text); fp:close(); copy_to_cloud_if_enabled(H_, dir .. '/' .. fname) end
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Achievements Functions
---------------------------------------------------------------------------------------------------

-- Robust Achievements Table
local AchievementsList = {
        -- Simple session starters
        { key = 'first_bucket', name = 'First Bucket', desc = 'Complete your first bucket.',
            condition = function(H_) return H_.settings.bucket_count >= 1 end },
        { key = 'hundred_items', name = 'Centurion', desc = 'Collect 100 items in total.',
            condition = function(H_) return H_.settings.item_count >= 100 end },
        { key = 'profit_10k', name = '10K Club', desc = 'Earn 10,000 gil profit in one session.',
            condition = function(H_) return total_session_profit_now(H_) >= 10000 end },
        { key = 'profit_100k', name = '100K Club', desc = 'Earn 100,000 gil profit in one session.',
            condition = function(H_) return total_session_profit_now(H_) >= 100000 end },
        { key = 'profit_1m', name = 'Millionaire', desc = 'Earn 1,000,000 gil profit in one session.',
            condition = function(H_) return total_session_profit_now(H_) >= 1000000 end },
        { key = 'bucket_10', name = 'Bucket Brigade', desc = 'Complete 10 buckets in one session.',
            condition = function(H_) return H_.settings.bucket_count >= 10 end },
        { key = 'bucket_25', name = 'Bucket Battalion', desc = 'Complete 25 buckets in one session.',
            condition = function(H_) return H_.settings.bucket_count >= 25 end },
        { key = 'bucket_50', name = 'Bucket Army', desc = 'Complete 50 buckets in one session.',
            condition = function(H_) return H_.settings.bucket_count >= 50 end },
        { key = 'item_rare', name = 'Rare Find', desc = 'Obtain a rare item (e.g. Titanictus Shell, Nebimonite, Goblin Mask, Goblin Armor, Goblin Mail).',
            condition = function(H_)
                local rare = {'titanictus shell','nebimonite','goblin mask','suit of goblin armor','suit of goblin mail'}
                for _, item in ipairs(rare) do if (H_.settings.index[item] or 0) > 0 then return true end end
                return false
            end },
        { key = 'all_goblin', name = 'Goblin Feast', desc = 'Obtain both Hobgoblin Bread and Hobgoblin Pie in one session.',
            condition = function(H_)
                return (H_.settings.index['loaf of hobgoblin bread'] or 0) > 0 and (H_.settings.index['hobgoblin pie'] or 0) > 0
            end },
        { key = 'all_logs', name = 'Lumberjack', desc = 'Obtain all log types in one session.',
            condition = function(H_)
                local logs = {'maple log','lacquer tree log','elm log','petrified log'}
                for _, item in ipairs(logs) do if (H_.settings.index[item] or 0) == 0 then return false end end
                return true
            end },
        { key = 'all_scales', name = 'Scale Collector', desc = 'Obtain all scale types in one session.',
            condition = function(H_)
                local scales = {'handful of fish scales','handful of pugil scales','handful of high-quality pugil scales'}
                for _, item in ipairs(scales) do if (H_.settings.index[item] or 0) == 0 then return false end end
                return true
            end },
        { key = 'moon_full', name = 'Full Moon Clammer', desc = 'Complete a bucket during a full moon.',
            condition = function(H_)
                return (H_.settings.last_bucket_moon or 0) >= 95
            end },
        { key = 'moon_new', name = 'New Moon Clammer', desc = 'Complete a bucket during a new moon.',
            condition = function(H_)
                return (H_.settings.last_bucket_moon or 100) <= 5
            end },
        { key = 'no_buckets', name = 'Unlucky Day', desc = 'Finish a session with 0 buckets.',
            condition = function(H_)
                return H_.settings.session_ended and (H_.settings.bucket_count or 0) == 0
            end },
        { key = 'no_items', name = 'Empty Nets', desc = 'Finish a session with 0 items.',
            condition = function(H_)
                return H_.settings.session_ended and (H_.settings.item_count or 0) == 0
            end },
        -- ... (Add 35+ more creative, combo, and milestone achievements below)
}

-- Add more creative and challenging achievements to reach 50+
for i = 1, 36 do
        table.insert(AchievementsList, {
                key = 'session_'..i,
                name = 'Session Veteran '..i,
                desc = 'Complete '..i..' clamming sessions.',
                condition = function(H_) return (H_.settings.session_count or 0) >= i end
        })
end

local function achievements_try_unlock(H_)
        if not H_.settings.achievements.enabled[1] then return end
        local unlocked = H_.settings.achievements.unlocked
        for _, ach in ipairs(AchievementsList) do
                if not unlocked[ach.key] and ach.condition(H_) then
                        unlocked[ach.key] = true
                        if H_.settings.achievements.webhook[1] and H_.settings.discord.enabled[1] then
                                discord_enqueue(H_, '[' .. (LOGS.char_name or 'Unknown') .. '] Achievement: '..ach.name..'!')
                        end
                end
        end
end

---------------------------------------------------------------------------------------------------
-- Display Helper Functions
---------------------------------------------------------------------------------------------------
local function display_name(item)
    local d = ItemDisplayNames[item]
    if d and #d > 0 then return d end
    return (tostring(item or ''):gsub('^%l', string.upper))
end

local function timer_text(H_)
    local timer_display = H_.settings.dig_timer
    if H_.settings.dig_timer_countdown then
        local dig_diff = (math.floor(H_.settings.last_dig / 1000.0) + 10) - ashita.time.clock()['s']
        if dig_diff < H_.settings.dig_timer then H_.settings.dig_timer = dig_diff end
        timer_display = H_.settings.dig_timer
        if timer_display <= 0 then return '[*]', true end
    else
        local dig_diff = ashita.time.clock()['s'] - math.floor(H_.settings.last_dig / 1000.0)
        if dig_diff > H_.settings.dig_timer then H_.settings.dig_timer = dig_diff end
        timer_display = H_.settings.dig_timer
        if timer_display >= 10 then return '[*]', true end
    end
    return tostring(timer_display), false
end

local function bucket_value(H_)
    local total = 0
    for k, v in pairs(H_.settings.bucket) do
        if H_.pricing[k] then total = total + (v * H_.pricing[k]) end
    end
    return total
end

---------------------------------------------------------------------------------------------------
-- Display Rendering Functions
---------------------------------------------------------------------------------------------------
local function render_minimal_display(H_)
    local value = bucket_value(H_)
    local bw_color = updateWeightColor(H_, H_.settings.bucket_capacity, H_.settings.bucket_weight, value)

    imgui.TextColored(H_.settings.colors.session_label_color, 'Weight:')

    local AchievementsList = {
        { key = 'first_bucket', name = 'First Bucket', desc = 'Complete your first bucket.', condition = function(H_) return H_.settings.bucket_count >= 1 end },
        { key = 'hundred_items', name = 'Centurion', desc = 'Collect 100 items in total.', condition = function(H_) return H_.settings.item_count >= 100 end },
        { key = 'profit_10k', name = '10K Club', desc = 'Earn 10,000 gil profit in one session.', condition = function(H_) return total_session_profit_now(H_) >= 10000 end },
        { key = 'profit_100k', name = '100K Club', desc = 'Earn 100,000 gil profit in one session.', condition = function(H_) return total_session_profit_now(H_) >= 100000 end },
        { key = 'profit_1m', name = 'Millionaire', desc = 'Earn 1,000,000 gil profit in one session.', condition = function(H_) return total_session_profit_now(H_) >= 1000000 end },
        { key = 'bucket_10', name = 'Bucket Brigade', desc = 'Complete 10 buckets in one session.', condition = function(H_) return H_.settings.bucket_count >= 10 end },
        { key = 'bucket_25', name = 'Bucket Battalion', desc = 'Complete 25 buckets in one session.', condition = function(H_) return H_.settings.bucket_count >= 25 end },
        { key = 'bucket_50', name = 'Bucket Army', desc = 'Complete 50 buckets in one session.', condition = function(H_) return H_.settings.bucket_count >= 50 end },
        { key = 'rare_find', name = 'Rare Find', desc = 'Obtain a rare item (Titanictus Shell, Nebimonite, Goblin Mask, Goblin Armor, Goblin Mail).', condition = function(H_)
            local rare = {'titanictus shell','nebimonite','goblin mask','suit of goblin armor','suit of goblin mail'}
            for _, item in ipairs(rare) do if (H_.settings.index[item] or 0) > 0 then return true end end
            return false
        end },
        { key = 'goblin_feast', name = 'Goblin Feast', desc = 'Obtain both Hobgoblin Bread and Hobgoblin Pie in one session.', condition = function(H_)
            return (H_.settings.index['loaf of hobgoblin bread'] or 0) > 0 and (H_.settings.index['hobgoblin pie'] or 0) > 0
        end },
        { key = 'lumberjack', name = 'Lumberjack', desc = 'Obtain all log types in one session.', condition = function(H_)
            local logs = {'maple log','lacquer tree log','elm log','petrified log'}
            for _, item in ipairs(logs) do if (H_.settings.index[item] or 0) == 0 then return false end end
            return true
        end },
        { key = 'scale_collector', name = 'Scale Collector', desc = 'Obtain all scale types in one session.', condition = function(H_)
            local scales = {'handful of fish scales','handful of pugil scales','handful of high-quality pugil scales'}
            for _, item in ipairs(scales) do if (H_.settings.index[item] or 0) == 0 then return false end end
            return true
        end },
        { key = 'moon_full', name = 'Full Moon Clammer', desc = 'Complete a bucket during a full moon.', condition = function(H_)
            return (H_.settings.last_bucket_moon or 0) >= 95
        end },
        { key = 'moon_new', name = 'New Moon Clammer', desc = 'Complete a bucket during a new moon.', condition = function(H_)
            return (H_.settings.last_bucket_moon or 100) <= 5
        end },
        { key = 'unlucky_day', name = 'Unlucky Day', desc = 'Finish a session with 0 buckets.', condition = function(H_)
            return H_.settings.session_ended and (H_.settings.bucket_count or 0) == 0
        end },
        { key = 'empty_nets', name = 'Empty Nets', desc = 'Finish a session with 0 items.', condition = function(H_)
            return H_.settings.session_ended and (H_.settings.item_count or 0) == 0
        end },
        { key = 'lucky_streak', name = 'Lucky Streak', desc = 'Obtain 3 rare items in a single session.', condition = function(H_)
            local rare = {'titanictus shell','nebimonite','goblin mask','suit of goblin armor','suit of goblin mail'}
            local count = 0; for _, item in ipairs(rare) do if (H_.settings.index[item] or 0) > 0 then count = count + 1 end end
            return count >= 3
        end },
        { key = 'clam_jam', name = 'Clam Jam', desc = 'Fill a bucket with only clams.', condition = function(H_)
            local clams = {'vongola clam','tropical clam'}
            for k, v in pairs(H_.settings.bucket) do if not vim.tbl_contains(clams, k) then return false end end
            return next(H_.settings.bucket) ~= nil
        end },
        { key = 'crab_fest', name = 'Crab Fest', desc = 'Fill a bucket with only crab shells.', condition = function(H_)
            for k, v in pairs(H_.settings.bucket) do if k ~= 'crab shell' and k ~= 'high-quality crab shell' then return false end end
            return next(H_.settings.bucket) ~= nil
        end },
        { key = 'log_haul', name = 'Log Haul', desc = 'Fill a bucket with only logs.', condition = function(H_)
            local logs = {'maple log','lacquer tree log','elm log','petrified log'}
            for k, v in pairs(H_.settings.bucket) do if not vim.tbl_contains(logs, k) then return false end end
            return next(H_.settings.bucket) ~= nil
        end },
        { key = 'scale_bucket', name = 'Scale Bucket', desc = 'Fill a bucket with only scales.', condition = function(H_)
            local scales = {'handful of fish scales','handful of pugil scales','handful of high-quality pugil scales'}
            for k, v in pairs(H_.settings.bucket) do if not vim.tbl_contains(scales, k) then return false end end
            return next(H_.settings.bucket) ~= nil
        end },
        { key = 'no_profit', name = 'No Profit', desc = 'End a session with 0 gil profit.', condition = function(H_)
            return H_.settings.session_ended and total_session_profit_now(H_) == 0
        end },
        { key = 'overweight', name = 'Overweight', desc = 'Overfill a bucket past its weight limit.', condition = function(H_)
            return H_.settings.bucket_weight > H_.settings.bucket_capacity
        end },
        { key = 'underweight', name = 'Underweight', desc = 'Turn in a bucket with less than 10% capacity used.', condition = function(H_)
            return H_.settings.bucket_weight > 0 and H_.settings.bucket_weight < (H_.settings.bucket_capacity * 0.1)
        end },
        { key = 'fast_fingers', name = 'Fast Fingers', desc = 'Fill a bucket in under 2 minutes.', condition = function(H_)
            return (H_.settings.last_bucket_time or 9999) < 120
        end },
        { key = 'slow_and_steady', name = 'Slow and Steady', desc = 'Take over 30 minutes to fill a bucket.', condition = function(H_)
            return (H_.settings.last_bucket_time or 0) > 1800
        end },
        { key = 'night_owl', name = 'Night Owl', desc = 'Complete a bucket between 2am and 4am Vana time.', condition = function(H_)
            local hour = (H_.settings.last_bucket_vana_hour or 0)
            return hour >= 2 and hour < 4
        end },
        { key = 'early_bird', name = 'Early Bird', desc = 'Complete a bucket between 5am and 7am Vana time.', condition = function(H_)
            local hour = (H_.settings.last_bucket_vana_hour or 0)
            return hour >= 5 and hour < 7
        end },
        { key = 'bucketless', name = 'Bucketless', desc = 'Dig up 10 items without a bucket.', condition = function(H_)
            return H_.settings.item_count >= 10 and not H_.has_bucket
        end },
        { key = 'lucky_bucket', name = 'Lucky Bucket', desc = 'Get a rare item as the last item in a bucket.', condition = function(H_)
            local rare = {'titanictus shell','nebimonite','goblin mask','suit of goblin armor','suit of goblin mail'}
            local last = H_.settings.last_bucket_last_item
            for _, item in ipairs(rare) do if last == item then return true end end
            return false
        end },
        { key = 'double_log', name = 'Double Log', desc = 'Get two different log types in one bucket.', condition = function(H_)
            local logs = {'maple log','lacquer tree log','elm log','petrified log'}
            local found = {}; for k, v in pairs(H_.settings.bucket) do if vim.tbl_contains(logs, k) then found[k] = true end end
            local count = 0; for _ in pairs(found) do count = count + 1 end
            return count >= 2
        end },
        { key = 'triple_scale', name = 'Triple Scale', desc = 'Get all three scale types in one bucket.', condition = function(H_)
            local scales = {'handful of fish scales','handful of pugil scales','handful of high-quality pugil scales'}
            local found = {}; for k, v in pairs(H_.settings.bucket) do if vim.tbl_contains(scales, k) then found[k] = true end end
            local count = 0; for _ in pairs(found) do count = count + 1 end
            return count == 3
        end },
        { key = 'no_duplicates', name = 'No Duplicates', desc = 'Fill a bucket with all unique items.', condition = function(H_)
            for _, v in pairs(H_.settings.bucket) do if v > 1 then return false end end
            return next(H_.settings.bucket) ~= nil
        end },
        { key = 'max_weight', name = 'Max Weight', desc = 'Fill a bucket to exactly its weight limit.', condition = function(H_)
            return H_.settings.bucket_weight == H_.settings.bucket_capacity
        end },
        { key = 'min_weight', name = 'Min Weight', desc = 'Turn in a bucket with only 1 unit of weight.', condition = function(H_)
            return H_.settings.bucket_weight == 1
        end },
        { key = 'lucky_number', name = 'Lucky Number', desc = 'Turn in a bucket with exactly 7 items.', condition = function(H_)
            local count = 0; for _, v in pairs(H_.settings.bucket) do count = count + v end
            return count == 7
        end },
        { key = 'unlucky_number', name = 'Unlucky Number', desc = 'Turn in a bucket with exactly 13 items.', condition = function(H_)
            local count = 0; for _, v in pairs(H_.settings.bucket) do count = count + v end
            return count == 13
        end },
        { key = 'bucket_full', name = 'Bucket Full', desc = 'Fill every slot in the bucket.', condition = function(H_)
            return H_.settings.bucket and next(H_.settings.bucket) and #H_.settings.bucket == H_.settings.bucket_capacity
        end },
        { key = 'session_5', name = 'Session Veteran 5', desc = 'Complete 5 clamming sessions.', condition = function(H_) return (H_.settings.session_count or 0) >= 5 end },
        { key = 'session_10', name = 'Session Veteran 10', desc = 'Complete 10 clamming sessions.', condition = function(H_) return (H_.settings.session_count or 0) >= 10 end },
        { key = 'session_25', name = 'Session Veteran 25', desc = 'Complete 25 clamming sessions.', condition = function(H_) return (H_.settings.session_count or 0) >= 25 end },
        { key = 'session_50', name = 'Session Veteran 50', desc = 'Complete 50 clamming sessions.', condition = function(H_) return (H_.settings.session_count or 0) >= 50 end },
        { key = 'session_100', name = 'Session Veteran 100', desc = 'Complete 100 clamming sessions.', condition = function(H_) return (H_.settings.session_count or 0) >= 100 end },
        { key = 'discordant', name = 'Discordant', desc = 'Send a summary to Discord.', condition = function(H_) return H_.settings.summary.send_to_discord[1] end },
        { key = 'cloud_saver', name = 'Cloud Saver', desc = 'Enable cloud backup.', condition = function(H_) return H_.settings.cloud.enabled[1] end },
        { key = 'mobile_ready', name = 'Mobile Ready', desc = 'Enable mobile JSON export.', condition = function(H_) return H_.settings.mobile.enabled[1] end },
        { key = 'colorful', name = 'Colorful', desc = 'Change any UI color.', condition = function(H_) return H_.settings.colors and next(H_.settings.colors) ~= nil end },
        { key = 'index_editor', name = 'Index Editor', desc = 'Edit the item index.', condition = function(H_) return H_.settings.item_index and next(H_.settings.item_index) ~= nil end },
        { key = 'exporter', name = 'Exporter', desc = 'Export a session to CSV or JSON.', condition = function(H_) return H_._ui_export_csv or false end },
        { key = 'backup_maker', name = 'Backup Maker', desc = 'Create a manual backup.', condition = function(H_) return H_.settings.auto_backup_enabled[1] end },
        { key = 'streaker', name = 'Streaker', desc = 'Hit 3 profit milestones in a row.', condition = function(H_) return H_.settings.session_milestones_hit and #H_.settings.session_milestones_hit >= 3 end },
        { key = 'efficiency_master', name = 'Efficiency Master', desc = 'Maintain >200 items/hr for 30 minutes.', condition = function(H_) return H_.current_efficiency and H_.current_efficiency > 200 end },
        { key = 'moonwalker', name = 'Moonwalker', desc = 'Complete a bucket in every moon phase.', condition = function(H_) return H_.settings.moon_phases_completed and #H_.settings.moon_phases_completed >= 8 end },
        { key = 'zone_hopper', name = 'Zone Hopper', desc = 'Clam in 3 different zones in one session.', condition = function(H_) return H_.settings.zone_tracking and H_.settings.zone_tracking.zones and #H_.settings.zone_tracking.zones >= 3 end },
        { key = 'overachiever', name = 'Overachiever', desc = 'Unlock 25 achievements.', condition = function(H_)
            local unlocked = H_.settings.achievements.unlocked or {}; local count = 0; for _,v in pairs(unlocked) do if v then count = count + 1 end end; return count >= 25
        end },
        { key = 'legend', name = 'Legend', desc = 'Unlock all achievements.', condition = function(H_)
            local unlocked = H_.settings.achievements.unlocked or {}; local count = 0; for _,v in pairs(unlocked) do if v then count = count + 1 end end; return count >= 50
        end },
    }


        imgui.TextColored(H_.settings.colors.session_label_color, 'Buckets Cost:')
        imgui.SameLine()
        imgui.TextColored(H_.settings.colors.session_value_color, tostring(H_.settings.bucket_count * H_.settings.clamming.bucket_cost[1]))

        imgui.TextColored(H_.settings.colors.session_label_color, 'Items Dug:')
        imgui.SameLine()
        imgui.TextColored(H_.settings.colors.session_value_color, tostring(H_.settings.item_count))

        if H_.settings.moon_display[1] then
            local moon = get_moon()
            imgui.TextColored(H_.settings.colors.moon_display_color, 'Moon: ' .. moon.MoonPhase .. ' (' .. tostring(moon.MoonPhasePercent) .. '%)')
        end

        if H_.settings.show_session_time[1] then
            local t = format_time_hms(elapsed)
            imgui.TextColored(H_.settings.colors.session_time_color, 'Session Time:')
            imgui.SameLine()
            imgui.TextColored(H_.settings.colors.session_time_color, t)
        end

        imgui.Separator()

        if H_.settings.session_view > 1 then
            for k, v in pairs(H_.settings.rewards) do
                local tot = (H_.pricing[k] or 0) * v
                imgui.TextColored(H_.settings.colors.bucket_item_name_color, display_name(k) .. ' ')
                if H_.settings.show_item_quantities[1] then
                    imgui.SameLine()
                    imgui.TextColored(H_.settings.colors.bucket_item_count_color, '[' .. format_int(v) .. ']')
                end
                if H_.settings.show_item_values[1] then
                    imgui.SameLine()
                    local ww = imgui.GetWindowWidth()
                    local tw = imgui.CalcTextSize('(' .. format_int(tot) .. ')')
                    imgui.SetCursorPosX(ww - tw - 16)
                    imgui.TextColored(H_.settings.colors.bucket_item_value_color, '(' .. format_int(tot) .. ')')
                end
            end
            imgui.Separator()
        end

        if H_.settings.clamming.bucket_subtract[1] then
            total_worth = total_worth - (H_.settings.bucket_count * H_.settings.clamming.bucket_cost[1])
            if (ashita.time.clock()['s'] % 3) == 0 and elapsed > 0 then
                H_.gil_per_hour = math.floor((total_worth / elapsed) * 3600)
            end
            imgui.TextColored(H_.settings.colors.session_total_label_color, 'Total Profit:')
            imgui.SameLine()
            imgui.TextColored(H_.settings.colors.session_total_value_color, format_int(total_worth) .. 'g')
            imgui.SameLine()
            imgui.TextColored(H_.settings.colors.session_gph_color, '(' .. format_int(H_.gil_per_hour) .. ' gph)')
        else
            if (ashita.time.clock()['s'] % 3) == 0 and elapsed > 0 then
                H_.gil_per_hour = math.floor((total_worth / elapsed) * 3600)
            end
            imgui.TextColored(H_.settings.colors.session_total_label_color, 'Total Revenue:')
            imgui.SameLine()
            imgui.TextColored(H_.settings.colors.session_total_value_color, format_int(total_worth) .. 'g')
            imgui.SameLine()
            imgui.TextColored(H_.settings.colors.session_gph_color, '(' .. format_int(H_.gil_per_hour) .. ' gph)')
        end
    end


local function render_detailed_display(H_)
    render_standard_display(H_)
    if not H_.settings.analytics.enabled[1] then return end

    imgui.Separator()
    imgui.TextColored(H_.settings.colors.session_header_color, 'Analytics:')

    local col = H_.settings.colors.efficiency_good_color or {0.5,1,0.5,1}
    if H_.current_efficiency < 50 then
        col = H_.settings.colors.efficiency_poor_color or {1,0.4,0.4,1}
    elseif H_.current_efficiency < 100 then
        col = H_.settings.colors.efficiency_warning_color or {1,0.8,0.35,1}
    end

    imgui.TextColored(H_.settings.colors.session_label_color, 'Efficiency:')
    imgui.SameLine()
    imgui.TextColored(col, string.format('%.1f items/hr', H_.current_efficiency))

    imgui.TextColored(H_.settings.colors.session_label_color, 'Trend:')
    imgui.SameLine()
    local tc = H_.settings.colors.efficiency_good_color or {0.5,1,0.5,1}
    if H_.efficiency_trend == 'declining' then tc = H_.settings.colors.efficiency_poor_color or {1,0.4,0.4,1}
    elseif H_.efficiency_trend == 'stable' then tc = H_.settings.colors.efficiency_warning_color or {1,0.8,0.35,1} end
    imgui.TextColored(tc, string.upper(H_.efficiency_trend or 'stable'))

    if H_.settings.zone_tracking.enabled[1] then
        imgui.TextColored(H_.settings.colors.zone_label_color, 'Current Zone:')
        imgui.SameLine()
        imgui.TextColored(H_.settings.colors.zone_value_color, H_.settings.zone_tracking.current_zone[1] or 'Unknown')
    end

    if #H_.session_milestones_hit > 0 then
        local latest = H_.session_milestones_hit[#H_.session_milestones_hit]
        local sec = ashita.time.clock()['s'] - latest.time
        if sec < 300 then
            imgui.TextColored(H_.settings.colors.milestone_color, 'Latest Milestone: ' .. format_int(latest.value) .. ' gil')
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Index Field Editor
---------------------------------------------------------------------------------------------------

local function render_index_editor(H_)
    if not H_._idx then
        H_._idx = {
            filter = T{ '' },
            new_name = T{ '' },
            new_price = T{ 0 },
            new_weight = T{ 0 },
        }
    end

    imgui.Text('Edit item price and weight indices. All changes are saved automatically.')
    imgui.InputText('Filter', H_._idx.filter, 128); help('Type to filter by item name.')
    imgui.Separator()

    imgui.Columns(5, 'idxcols', true)
    imgui.Text('Item Name');
    if imgui.IsItemHovered() then imgui.SetTooltip('The internal name of the item (used for lookups).') end
    imgui.NextColumn()
    imgui.Text('Price (gil)');
    if imgui.IsItemHovered() then imgui.SetTooltip('The gil value used for profit calculations.') end
    imgui.NextColumn()
    imgui.Text('Weight (units)');
    if imgui.IsItemHovered() then imgui.SetTooltip('The weight of the item for bucket capacity.') end
    imgui.NextColumn()
    imgui.Text('Display Name');
    if imgui.IsItemHovered() then imgui.SetTooltip('How the item will appear in the UI.') end
    imgui.NextColumn()
    imgui.Text('Actions');
    if imgui.IsItemHovered() then imgui.SetTooltip('Remove this item from the index.') end
    imgui.NextColumn()
    imgui.Separator()

    local keys = build_keys_union(H_)
    local f = normalize_item(H_._idx.filter[1] or '')
    for _, k in ipairs(keys) do
        if f == '' or k:find(f, 1, true) then
            local price_v = T{ H_.pricing[k] or 0 }
            local weight_v = T{ H_.weights[k] or 0 }
            local disp_v = T{ ItemDisplayNames[k] or k }

            imgui.Text(k)
            if imgui.IsItemHovered() then imgui.SetTooltip('The internal name of the item (used for lookups).') end
            imgui.NextColumn()

            if imgui.InputInt('##p'..k, price_v) then
                set_index_value(H_.settings.item_index, k, price_v[1]); H_.pricing = parse_pairs(H_.settings.item_index)
            end
            if imgui.IsItemHovered() then imgui.SetTooltip('Edit the gil value for this item.') end
            imgui.NextColumn()

            if imgui.InputInt('##w'..k, weight_v) then
                set_index_value(H_.settings.item_weight_index, k, weight_v[1]); H_.weights = parse_pairs(H_.settings.item_weight_index)
            end
            if imgui.IsItemHovered() then imgui.SetTooltip('Edit the weight for this item.') end
            imgui.NextColumn()

            if imgui.InputText('##d'..k, disp_v, 128) then
                ItemDisplayNames[k] = disp_v[1]
            end
            if imgui.IsItemHovered() then imgui.SetTooltip('Edit how this item will appear in the UI.') end
            imgui.NextColumn()

            if imgui.SmallButton('Remove##'..k) then
                remove_index_entry(H_.settings.item_index, k)
                remove_index_entry(H_.settings.item_weight_index, k)
                H_.pricing = parse_pairs(H_.settings.item_index)
                H_.weights = parse_pairs(H_.settings.item_weight_index)
            end
            if imgui.IsItemHovered() then imgui.SetTooltip('Remove this item from the index.') end
            imgui.NextColumn()
        end
    end

    imgui.Columns(1)
    imgui.Separator()

    imgui.Text('Add / Replace Item')
    imgui.InputText('Name', H_._idx.new_name, 160); help('Lowercase preferred. Example: "turtle shell"')
    imgui.InputInt('Price', H_._idx.new_price); help('Gil value used for calculations.')
    imgui.InputInt('Weight', H_._idx.new_weight); help('Weight used for bucket capacity.')
    if imgui.Button('Add / Update') then
        local n = normalize_item(H_._idx.new_name[1] or '')
        if n ~= '' then
            set_index_value(H_.settings.item_index, n, H_._idx.new_price[1] or 0)
            set_index_value(H_.settings.item_weight_index, n, H_._idx.new_weight[1] or 0)
            ItemDisplayNames[n] = ItemDisplayNames[n] or n:gsub('^%l', string.upper)
            H_.pricing = parse_pairs(H_.settings.item_index)
            H_.weights = parse_pairs(H_.settings.item_weight_index)
            H_._idx.new_name[1] = ''; H_._idx.new_price[1] = 0; H_._idx.new_weight[1] = 0
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Color Reset Functions
---------------------------------------------------------------------------------------------------
local function reset_ui_theme_colors(H_)
    for k, rgba in pairs(COLOR_DEFAULTS.ui) do
        H_.settings.colors[k] = { rgba[1], rgba[2], rgba[3], rgba[4] }
    end
end

local function reset_domain_colors(H_)
    for k, rgba in pairs(COLOR_DEFAULTS.domain) do
        H_.settings.colors[k] = { rgba[1], rgba[2], rgba[3], rgba[4] }
    end
end

local function reset_profit_tiers(H_)
    H_.settings.colors.profit_percentage_tiers = deepcopy(COLOR_DEFAULTS.tiers)
end

local function reset_all_colors(H_)
    reset_ui_theme_colors(H_)
    reset_domain_colors(H_)
    reset_profit_tiers(H_)
end

---------------------------------------------------------------------------------------------------
-- Settings UI Helper Functions
---------------------------------------------------------------------------------------------------
local function ColorEdit(label, col, tip)
    if type(col) ~= 'table' or #col < 4 then col = {0.5,0.5,0.5,1.0} end
    imgui.ColorEdit4(label, col)
    help(tip)
end

local function PercentSlider(label, t, tip)
    local v = T{ (t[1] or 0) }
    if imgui.SliderFloat(label, v, 0.0, 1.0, '%.2f') then t[1] = v[1] end
    help(tip)
end

local function InputPath(label, t, tip)
    local ok = pcall(function() imgui.InputText(label, t, 260) end)
    if not ok then imgui.Text(label .. ': (edit config file)') end
    help(tip)
end

---------------------------------------------------------------------------------------------------
-- Settings Editor
---------------------------------------------------------------------------------------------------
local function render_settings_editor(H_, SETTINGS)
    if not H_.settings.editor.is_open[1] then return end
    local pushed = push_imgui_style(H_.settings.colors)
    imgui.SetNextWindowSize({0,0}, ImGuiCond_Always)
    if imgui.Begin('HXIClam Enhanced - Settings##Config', H_.settings.editor.is_open, ImGuiWindowFlags_AlwaysAutoResize2) then
        if imgui.Button('Save Settings') then SETTINGS.save() end; help('Save current settings to disk.')
        imgui.SameLine()
        if imgui.Button('Reload') then SETTINGS.reload() end; help('Reload settings from disk.')
        imgui.SameLine()
        if imgui.Button('Reset To Defaults') then SETTINGS.reset() end; help('Reset to defaults (logs unaffected).')
        imgui.SameLine()
        if imgui.Button('Export Now (CSV)') then H_._ui_export_csv = true end; help('Quick CSV export.')

        imgui.SameLine()

        if imgui.Button('Clear Bucket') then
            clear_bucket()
            if chat then print(chat.header(addon.name):append(chat.message('Bucket cleared.'))) end
        end
        help('Remove all items from your bucket and reset bucket weight.')

        imgui.SameLine()
        if imgui.Button('Clear Session') then
            clear_rewards()
            if chat then print(chat.header(addon.name):append(chat.message('Session cleared.'))) end
        end
        help('Reset session counters (items, buckets, gph) without touching the bucket.')

        imgui.SameLine()
        if imgui.Button('Clear All') then
            clear_bucket()
            clear_rewards()
            if chat then print(chat.header(addon.name):append(chat.message('Bucket and session cleared.'))) end
        end
        help('Clear both the current bucket and the session totals.')

        imgui.Separator()

        if imgui.BeginTabBar('##hxiclam_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) then
            if imgui.BeginTabItem('General', nil) then
                imgui.Text('General Settings')
                imgui.Checkbox('Visible', H_.settings.visible); help('Toggle main window visibility.')
                imgui.Checkbox('Moon Display', H_.settings.moon_display); help('Show moon phase and percent.')
                imgui.SliderFloat('Opacity', H_.settings.opacity, 0.125, 1.0, '%.3f'); help('Window background opacity.')
                imgui.SliderFloat('Font Scale', H_.settings.font_scale, 0.10, 2.0, '%.3f'); help('Scale all fonts.')
                imgui.InputInt('Display Timeout (sec)', H_.settings.display_timeout); help('Seconds to keep visible after last event.')

                local posX = T{ H_.settings.x[1] }
                local posY = T{ H_.settings.y[1] }
                if imgui.InputInt('Pos X', posX) then H_.settings.x[1] = posX[1] end
                imgui.SameLine()
                if imgui.InputInt('Pos Y', posY) then H_.settings.y[1] = posY[1] end
                help('Window position.')

                if imgui.RadioButton('Minimal Display', H_.settings.display_mode[1] == 1) then H_.settings.display_mode[1] = 1 end; help('Only weight and timer.')
                imgui.SameLine()
                if imgui.RadioButton('Standard Display', H_.settings.display_mode[1] == 2) then H_.settings.display_mode[1] = 2 end; help('Common information.')
                imgui.SameLine()
                if imgui.RadioButton('Detailed Display', H_.settings.display_mode[1] == 3) then H_.settings.display_mode[1] = 3 end; help('Standard + analytics.')
                imgui.SameLine()
                if imgui.RadioButton('Overlay', H_.settings.display_mode[1] == 4) then H_.settings.display_mode[1] = 4 end; help('Transparent overlay mode.')

                imgui.Checkbox('Enable Sound', H_.settings.enable_tone); help('Play a sound when timer ready or events occur.')
                imgui.SameLine()
                if imgui.BeginCombo('Tone', H_.settings.tone) then
                    for i, v in pairs(H_.settings.available_tones) do
                        local sel = (i == H_.settings.tone_selected_idx)
                        if imgui.Selectable(v, sel) then H_.settings.tone_selected_idx = i; H_.settings.tone = v end
                        if sel then imgui.SetItemDefaultFocus() end
                    end
                    imgui.EndCombo()
                end; help('Select sound file from "tones" folder.')
                imgui.SameLine()
                if imgui.Button('Test Tone') then pcall(function() ashita.misc.play_sound(("%stones/%s"):format(BASE, H_.settings.tone)) end) end; help('Play selected tone.')

                imgui.Checkbox('Show Session Time', H_.settings.show_session_time); help('Show elapsed session time.')
                imgui.Checkbox('Show Item Quantities', H_.settings.show_item_quantities); help('Show [x] quantity.')
                imgui.Checkbox('Show Item Values', H_.settings.show_item_values); help('Show (value) next to items.')
                imgui.Checkbox('Reset Rewards On Load', H_.settings.reset_on_load); help('Clear session and bucket on load.')
                imgui.Checkbox('Enable Logging', H_.settings.enable_logging); help('Write drops/turn-ins to logs.')

                imgui.Separator()
                imgui.Text('Auto Backup')
                imgui.Checkbox('Enable Auto Backup', H_.settings.auto_backup_enabled); help('Automatically save backups.')
                if H_.settings.auto_backup_enabled[1] then
                    imgui.InputInt('Backup Interval (sec)', H_.settings.auto_backup_interval); help('Seconds between backups.')
                end

                imgui.Separator()
                imgui.Text('Export')
                if imgui.RadioButton('CSV', H_.settings.export_format[1] == 1) then H_.settings.export_format[1] = 1 end; help('CSV for spreadsheets.')
                imgui.SameLine()
                if imgui.RadioButton('JSON', H_.settings.export_format[1] == 2) then H_.settings.export_format[1] = 2 end; help('JSON export.')

                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Clamming', nil) then
                imgui.Text('Clamming Parameters')
                imgui.InputInt('Bucket Cost (gil)', H_.settings.clamming.bucket_cost); help('Cost to purchase a clamming kit.')
                imgui.Checkbox('Subtract Bucket Cost From Profit', H_.settings.clamming.bucket_subtract); help('Subtract bucket cost from totals.')


                imgui.Separator()
                imgui.Text('Bucket Weight Warning Colors')
                ColorEdit('Warn Color', H_.settings.colors.bucket_weight_warn_color, 'Color when remaining weight is low.')
                ColorEdit('Critical Color', H_.settings.colors.bucket_weight_crit_color, 'Color when remaining weight is critical.')
                imgui.InputInt('Warn Threshold', H_.settings.colors.bucket_weight_warn_threshold); help('Remaining weight for warn color.')
                imgui.InputInt('Critical Threshold', H_.settings.colors.bucket_weight_crit_threshold); help('Remaining weight for critical color.')

                imgui.Separator()
                -- Stop Color Logic Toggle directly under label
                local showStopColor = imgui.Checkbox('Use Stop Color Logic', H_.settings.clamming.color_logic_advanced); help('Enable advanced stop color logic for bucket profit and weight.')
                if H_.settings.clamming.color_logic_advanced and H_.settings.clamming.color_logic_advanced[1] then
                    local caps = {50, 100, 150, 200}
                    for _, cap in ipairs(caps) do
                        imgui.Separator()
                        imgui.Text(('Bucket Size: %d'):format(cap))

                        imgui.Indent()

                        local su = H_.settings.clamming.stop_weights_under_value[cap] or T{0}
                        if imgui.InputInt(('Under Weight Stop Amount##under_%d'):format(cap), su) then
                            H_.settings.clamming.stop_weights_under_value[cap] = su
                        end
                        help('Remaining weight threshold when profit is BELOW the Gil Stop Amount.')

                        local sv = H_.settings.clamming.stop_values[cap] or T{0}
                        if imgui.InputInt(('Gil Stop Amount##stop_%d'):format(cap), sv) then
                            H_.settings.clamming.stop_values[cap] = sv
                        end
                        help('Target profit (gil). Below this uses Under Value; at/above uses Over Value.')

                        local so = H_.settings.clamming.stop_weights_over_value[cap] or T{0}
                        if imgui.InputInt(('Over Weight Stop Amount##over_%d'):format(cap), so) then
                            H_.settings.clamming.stop_weights_over_value[cap] = so
                        end
                        help('Remaining weight threshold when profit is AT OR ABOVE the Gil Stop Amount.')

                        imgui.Unindent()
                    end
                end

                -- Percentage-Based Profit Colors Toggle and Conditional Tiers
                imgui.Separator()
                local showPctColors = imgui.Checkbox('Use Percentage-Based Profit Colors', H_.settings.colors.use_percentage_profit_colors); help('Enable profit color tiers based on percentage of stop value.')
                if H_.settings.colors.use_percentage_profit_colors and H_.settings.colors.use_percentage_profit_colors[1] then
                    imgui.Separator()
                    imgui.Text('Profit Percentage Tiers')
                    local Cc = H_.settings.colors
                    Cc.profit_percentage_tiers = Cc.profit_percentage_tiers or deepcopy(COLOR_DEFAULTS.tiers)
                    for i = 1, #Cc.profit_percentage_tiers do
                        imgui.PushID('tier'..i)
                        local tier = Cc.profit_percentage_tiers[i]
                        if imgui.InputInt(('Tier %d Threshold %%'):format(i), tier.percent) then
                            if tier.percent[1] < 0 then tier.percent[1] = 0 end
                        end
                        ColorEdit(('Tier %d Color'):format(i), tier.color, '')
                        imgui.SameLine()
                        if imgui.SmallButton('Remove') then
                            table.remove(Cc.profit_percentage_tiers, i)
                            imgui.PopID()
                            break
                        end
                        imgui.PopID()
                    end

                    local newTierPct = H_._newTierPct or T{0}
                    local newTierColor = H_._newTierColor or {1,1,1,1}
                    H_._newTierPct, H_._newTierColor = newTierPct, newTierColor

                    imgui.Separator()
                    imgui.Text('Add New Tier')
                    imgui.InputInt('New Tier %', newTierPct)
                    ColorEdit('New Tier Color', newTierColor, '')
                    if imgui.Button('Add Tier') then
                        table.insert(Cc.profit_percentage_tiers, { percent = T{ math.max(0, newTierPct[1]) }, color = { newTierColor[1], newTierColor[2], newTierColor[3], newTierColor[4] } })
                        newTierPct[1] = 0
                        H_._newTierColor = {1,1,1,1}
                    end
                end

                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Indexes', nil) then
                render_index_editor(H_)
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Smart', nil) then
                imgui.Text('Smart Turn-In Suggestions')
                imgui.Checkbox('Enable Smart Turn-Ins', H_.settings.smart.turnin_enabled); help('Suggest turn-ins by risk/value.')
                PercentSlider('Aggressiveness', H_.settings.smart.turnin_aggressiveness, '0.00 conservative to 1.00 aggressive.')
                imgui.Checkbox('Show Banner', H_.settings.smart.show_banner); help('On-screen suggestion banner.')
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Milestones', nil) then
                imgui.Text('Dynamic Milestones')
                imgui.Checkbox('Enable Dynamic Milestones', H_.settings.milestones_dynamic.enabled); help('Scale milestones as profit grows.')
                PercentSlider('Scale Factor', H_.settings.milestones_dynamic.scale, 'Multiplier for next milestone.')
                imgui.InputInt('Minimum Gap (gil)', H_.settings.milestones_dynamic.min_gap); help('Minimum difference between milestones.')
                imgui.Separator()
                imgui.Text('Static Milestones')
                local tmp = {}
                for i, m in ipairs(H_.settings.notifications.profit_milestones) do tmp[i] = { m } end
                for i = 1, #tmp do
                    imgui.PushID('ms'..i)
                    if imgui.InputInt(('Milestone %d'):format(i), tmp[i]) then
                        H_.settings.notifications.profit_milestones[i] = tmp[i][1]
                    end
                    help('Edit static milestone (gil).')
                    imgui.PopID()
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Summary', nil) then
                imgui.Text('One-Click Session Summary')
                imgui.Checkbox('One-Click Enabled', H_.settings.summary.one_click_enabled); help('Enable quick summary generation.')
                imgui.Checkbox('Include Items', H_.settings.summary.include_items); help('Include item breakdown.')
                imgui.Checkbox('Include Zones', H_.settings.summary.include_zones); help('Include per-zone stats.')
                imgui.Checkbox('Send To Discord', H_.settings.summary.send_to_discord); help('Post to Discord if webhook set.')
                imgui.Checkbox('Save As File', H_.settings.summary.save_as_file); help('Write summary to exports folder.')
                if imgui.Button('Generate Summary Now') then one_click_summary(H_) end; help('Create and optionally send the summary.')
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Discord', nil) then
                imgui.Text('Discord Webhooks')
                imgui.Checkbox('Enable Discord', H_.settings.discord.enabled); help('Enable Discord webhook integration.')
                pcall(function() imgui.InputText('Webhook URL', H_.settings.discord.webhook_url, 512) end); help('Paste your Discord webhook URL.')
                imgui.InputInt('Queue Limit', H_.settings.discord.queue_limit); help('Max queued messages.')
                imgui.InputInt('Max Per Minute', H_.settings.discord.max_per_minute); help('Rate limit.')
                imgui.Checkbox('Send Milestones', H_.settings.discord.send_milestones); help('Send milestone messages.')
                imgui.Checkbox('Send Streaks', H_.settings.discord.send_streaks); help('Send celebrations.')
                imgui.Checkbox('Send Summaries', H_.settings.discord.send_summaries); help('Send summaries.')
                if imgui.Button('Send Test Message') then discord_enqueue(H_, 'HXIClam: webhook test.') end; help('Queue a simple test message.')
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Achievements', nil) then
                imgui.Text('Achievements')
                imgui.Checkbox('Enable Achievements', H_.settings.achievements.enabled); help('Track and unlock achievements.')
                local unlocked = H_.settings.achievements.unlocked or {}
                local unlocked_count, total_count = 0, #AchievementsList
                for _, ach in ipairs(AchievementsList) do if unlocked[ach.key] then unlocked_count = unlocked_count + 1 end end
                imgui.Text(('Unlocked: %d / %d'):format(unlocked_count, total_count))
                imgui.Separator()
                imgui.Columns(2, nil, false)
                imgui.Text('Achievement'); imgui.NextColumn(); imgui.Text('Status'); imgui.NextColumn()
                imgui.Separator()
                for _, ach in ipairs(AchievementsList) do
                    if unlocked[ach.key] then
                        imgui.Text(ach.name)
                        if imgui.IsItemHovered() then imgui.SetTooltip(ach.desc) end
                        imgui.NextColumn()
                        imgui.TextColored({0,1,0,1}, 'Unlocked')
                        imgui.NextColumn()
                    end
                end
                imgui.Columns(1)
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Cloud & Mobile', nil) then
                imgui.Text('Cloud Backup')
                imgui.Checkbox('Enable Cloud Copy', H_.settings.cloud.enabled); help('Copy backups/exports to another folder.')
                InputPath('Cloud Folder', H_.settings.cloud.path, 'Target folder to copy files to.')
                imgui.Separator()
                imgui.Text('Mobile Companion')
                imgui.Checkbox('Enable Mobile JSON', H_.settings.mobile.enabled); help('Write a small JSON for companion apps.')
                InputPath('Mobile JSON Path', H_.settings.mobile.out_path, 'Full file path (e.g. C:\\temp\\hxiclam.json).')
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem('Colors', nil) then
                local Cc = H_.settings.colors

                if imgui.Button('Reset UI Theme Colors') then reset_ui_theme_colors(H_) end
                imgui.SameLine()
                if imgui.Button('Reset Domain Colors') then reset_domain_colors(H_) end
                imgui.SameLine()
                if imgui.Button('Reset Profit % Tiers') then reset_profit_tiers(H_) end
                imgui.SameLine()
                if imgui.Button('Reset ALL Colors') then reset_all_colors(H_) end

                imgui.Separator()
                imgui.Text('UI Theme (ImGui)')

                local ui_list = {
                    {'Window BG',              'window_bg_color'},
                    {'Child BG',               'child_bg_color'},
                    {'Popup BG',               'popup_bg_color'},
                    {'Border',                 'border_color'},
                    {'Border Shadow',          'border_shadow_color'},
                    {'Frame BG',               'frame_bg_color'},
                    {'Frame BG (Hovered)',     'frame_bg_hovered_color'},
                    {'Frame BG (Active)',      'frame_bg_active_color'},
                    {'Title BG',               'title_bg_color'},
                    {'Title BG (Active)',      'title_bg_active_color'},
                    {'Title BG (Collapsed)',   'title_bg_collapsed_color'},
                    {'Menu Bar BG',            'menubar_bg_color'},
                    {'Scrollbar BG',           'scrollbar_bg_color'},
                    {'Scrollbar Grab',         'scrollbar_grab_color'},
                    {'Scrollbar Grab (Hovered)','scrollbar_grab_hovered_color'},
                    {'Scrollbar Grab (Active)','scrollbar_grab_active_color'},
                    {'Check Mark',             'checkmark_color'},
                    {'Slider Grab',            'slider_grab_color'},
                    {'Slider Grab (Active)',   'slider_grab_active_color'},
                    {'Button',                 'button_color'},
                    {'Button (Hovered)',       'button_hovered_color'},
                    {'Button (Active)',        'button_active_color'},
                    {'Header',                 'header_color'},
                    {'Header (Hovered)',       'header_hovered_color'},
                    {'Header (Active)',        'header_active_color'},
                    {'Separator',              'separator_color'},
                    {'Separator (Hovered)',    'separator_hovered_color'},
                    {'Separator (Active)',     'separator_active_color'},
                    {'Resize Grip',            'resize_grip_color'},
                    {'Resize Grip (Hovered)',  'resize_grip_hovered_color'},
                    {'Resize Grip (Active)',   'resize_grip_active_color'},
                    {'Tab',                    'tab_color'},
                    {'Tab (Hovered)',          'tab_hovered_color'},
                    {'Tab (Active)',           'tab_active_color'},
                    {'Tab (Unfocused)',        'tab_unfocused_color'},
                    {'Tab (Unfocused Active)', 'tab_unfocused_active_color'},
                    {'Docking Preview',        'docking_preview_color'},
                    {'Docking Empty BG',       'docking_empty_bg_color'},
                    {'Nav Highlight',          'nav_highlight_color'},
                    {'Nav Windowing Highlight','nav_windowing_highlight_color'},
                    {'Nav Windowing Dim BG',   'nav_windowing_dim_bg_color'},
                    {'Modal Window Dim BG',    'modal_window_dim_bg_color'},
                    {'Text',                   'text_color'},
                    {'Text Disabled',          'text_disabled_color'},
                }
                for _, row in ipairs(ui_list) do
                    ColorEdit(row[1], ensure_color(Cc, row[2], COLOR_DEFAULTS.ui[row[2]]), '')
                end

                imgui.Separator()
                imgui.Text('Domain Colors (Addon)')

                local domain_list = {
                    {'Session Label',               'session_label_color'},
                    {'Session Value',               'session_value_color'},
                    {'Session Header',              'session_header_color'},
                    {'Total Label',                 'session_total_label_color'},
                    {'Total Value',                 'session_total_value_color'},
                    {'Session Time',                'session_time_color'},
                    {'Revenue Label',               'revenue_label_color'},
                    {'Revenue Amount',              'revenue_amount_color'},
                    {'Profit Label',                'profit_label_color'},
                    {'Profit Amount (+)',           'profit_amount_positive_color'},
                    {'Profit Amount (-)',           'profit_amount_negative_color'},
                    {'Has Bucket',                  'has_bucket_color'},
                    {'No Bucket',                   'no_bucket_color'},
                    {'Bucket Item Name',            'bucket_item_name_color'},
                    {'Bucket Item Count',           'bucket_item_count_color'},
                    {'Bucket Item Value',           'bucket_item_value_color'},
                    {'Timer (Normal)',              'dig_timer_normal_color'},
                    {'Timer (Ready)',               'dig_timer_ready_color'},
                    {'Bucket Weight Warn',          'bucket_weight_warn_color'},
                    {'Bucket Weight Critical',      'bucket_weight_crit_color'},
                    {'Zone Label',                  'zone_label_color'},
                    {'Zone Value',                  'zone_value_color'},
                    {'Milestone',                   'milestone_color'},
                    {'Efficiency Good',             'efficiency_good_color'},
                    {'Efficiency Warning',          'efficiency_warning_color'},
                    {'Efficiency Poor',             'efficiency_poor_color'},
                    {'GPH',                         'session_gph_color'},
                    {'Moon Display',                'moon_display_color'},
                }
                for _, row in ipairs(domain_list) do
                    ColorEdit(row[1], ensure_color(Cc, row[2], COLOR_DEFAULTS.domain[row[2]]), '')
                end



                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
    end
    imgui.End()
    pop_imgui_style(pushed)
end

---------------------------------------------------------------------------------------------------
-- State Management Functions
---------------------------------------------------------------------------------------------------
local function clear_bucket() 
    H.settings.bucket = T{}
    H.settings.bucket_weight = 0 
end

local function clear_rewards() 
    H.settings.rewards = T{}
    H.settings.item_count = 0
    H.settings.bucket_count = 0
    H.gil_per_hour = 0 
end

---------------------------------------------------------------------------------------------------
-- Settings Registration
---------------------------------------------------------------------------------------------------
settings.register('settings', 'settings_update', function(s)
    if s ~= nil then H.settings = s end
    settings.save()
    update_pricing()
    update_weights()
end)

---------------------------------------------------------------------------------------------------
-- Event Handlers
---------------------------------------------------------------------------------------------------
ashita.events.register('load', 'load_cb', function()
    update_pricing()
    update_weights()
    update_tones(H)
    if H.settings.reset_on_load and H.settings.reset_on_load[1] then
        clear_rewards(); clear_bucket()
    end
    local party = AshitaCore and AshitaCore:GetMemoryManager() and AshitaCore:GetMemoryManager():GetParty()
    local name = party and party.GetMemberName and party:GetMemberName(0) or nil
    if name ~= nil and type(name) == 'string' and name:len() > 0 then LOGS.char_name = name end
    update_zone_tracking(H)
    analytics_initialize(H)
    print(chat.header(addon.name):append(chat.color1(10, 'HXIClam Enhanced loaded. Use /hxiclam help.')))
end)

ashita.events.register('unload', 'unload_cb', function()
    if H.settings.auto_backup_enabled[1] then create_backup() end
    settings.save()
end)

---------------------------------------------------------------------------------------------------
-- Command Handler
---------------------------------------------------------------------------------------------------
local function print_help(isError)
    if isError then
        print(chat.header(addon.name):append(chat.error('Invalid command. Use /hxiclam help')))
        return
    end
    local cmds = T{
        {'/hxiclam edit', 'Open/close settings editor.'},
        {'/hxiclam save', 'Save settings.'},
        {'/hxiclam reload', 'Reload settings.'},
        {'/hxiclam clear', 'Clear bucket and session.'},
        {'/hxiclam clear bucket', 'Clear bucket only.'},
        {'/hxiclam clear session', 'Clear session only.'},
        {'/hxiclam show', 'Show main display.'},
        {'/hxiclam hide', 'Hide main display.'},
        {'/hxiclam update', 'Update pricing and weights.'},
        {'/hxiclam backup', 'Create manual backup.'},
        {'/hxiclam export', 'Export session to CSV.'},
        {'/hxiclam export json', 'Export session to JSON.'},
        {'/hxiclam mode <1-4>', 'Display mode: 1=min,2=std,3=det,4=overlay.'},
        {'/hxiclam analytics', 'Toggle analytics.'},
        {'/hxiclam zone', 'Print current zone.'},
        {'/hxiclam discord enable|disable', 'Toggle Discord webhooks.'},
        {'/hxiclam discord url <webhook>', 'Set Discord webhook URL.'},
        {'/hxiclam summary', 'Create one-click session summary.'}
    }
    for _,v in ipairs(cmds) do
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1] .. ' - ')):append(chat.color1(6, v[2])))
    end
end

ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args()
    if (#args == 0 or not args[1]:any('/hxiclam')) then return end
    e.blocked = true

    if #args == 1 or (#args >= 2 and args[2]:any('edit')) then H.settings.editor.is_open[1] = not H.settings.editor.is_open[1]; return end
    if #args >= 2 and args[2]:any('help') then print_help(false); return end
    if #args >= 2 and args[2]:any('save') then update_pricing(); update_weights(); settings.save(); print(chat.header(addon.name):append(chat.message('Settings saved.'))); return end
    if #args >= 2 and args[2]:any('reload') then settings.reload(); update_tones(H); print(chat.header(addon.name):append(chat.message('Settings reloaded.'))); return end
    if #args >= 2 and args[2]:any('clear') then
        if #args >= 3 and args[3]:any('bucket') then clear_bucket()
        elseif #args >= 3 and args[3]:any('session') then clear_rewards()
        else clear_bucket(); clear_rewards() end
        print(chat.header(addon.name):append(chat.message('Cleared.'))); return
    end
    if #args >= 2 and args[2]:any('show') then H.settings.visible[1] = true; return end
    if #args >= 2 and args[2]:any('hide') then H.settings.visible[1] = false; return end
    if #args >= 2 and args[2]:any('update') then update_pricing(); update_weights(); print(chat.header(addon.name):append(chat.message('Pricing/weights updated.'))); return end
    if #args >= 2 and args[2]:any('backup') then create_backup(); print(chat.header(addon.name):append(chat.message('Backup created.'))); return end
    if #args >= 2 and args[2]:any('export') then
        local as_json = (#args >= 3 and args[3]:any('json'))
        export_session(as_json); return
    end
    if #args >= 2 and args[2]:any('mode') and #args >= 3 then
        local m = tonumber(args[3]) or 2
        H.settings.display_mode[1] = math.max(1, math.min(4, m)); return
    end
    if #args >= 2 and args[2]:any('analytics') then
        H.settings.analytics.enabled[1] = not H.settings.analytics.enabled[1]
        print(chat.header(addon.name):append(chat.message('Analytics: ' .. tostring(H.settings.analytics.enabled[1])))); return
    end
    if #args >= 2 and args[2]:any('zone') then print(chat.header(addon.name):append(chat.message('Zone: ' .. get_current_zone()))); return end
    if #args >= 2 and args[2]:any('discord') then
        if #args >= 3 and args[3]:any('enable') then H.settings.discord.enabled[1] = true; print('Discord enabled.'); return end
        if #args >= 3 and args[3]:any('disable') then H.settings.discord.enabled[1] = false; print('Discord disabled.'); return end
        if #args >= 4 and args[3]:any('url') then H.settings.discord.webhook_url[1] = args[4]; print('Discord webhook set.'); return end
    end
    if #args >= 2 and args[2]:any('summary') then one_click_summary(H); print('Summary generated.'); return end

    print_help(true)
end)

---------------------------------------------------------------------------------------------------
-- Text Parsing and Chat Event Handler
---------------------------------------------------------------------------------------------------
local function normalize_chat(msg)
    msg = tostring(msg or '')
    msg = msg:lower()
    local ok, res = pcall(function()
        if string.strip_colors then return string.strip_colors(msg) end
    end)
    msg = (ok and res) and res or msg:gsub('[\x1E\x1F].', ''):gsub('%s+', ' ')
    return msg
end

local function on_turnin()
    if H.settings.bucket ~= nil and next(H.settings.bucket) ~= nil then
        for k, v in pairs(H.settings.bucket) do
            H.settings.item_count = (H.settings.item_count or 0) + v
            H.settings.rewards[k] = (H.settings.rewards[k] or 0) + v
            if H.settings.enable_logging[1] then
                for i = 1, v do WriteLog(H, LOGS, 'turnin', k) end
            end
        end
    end
    H.has_bucket = false
    clear_bucket()
    achievements_try_unlock(H)
    analytics_after_bucket_turnin(H)
end

ashita.events.register('text_in', 'text_in_cb', function(e)
    local now_ms = ashita.time.clock()['ms']
    local message = normalize_chat(e.message or '')

    local bucket          = message:find('obtained key item: clamming kit', 1, true)
    local item            = message:match('you find a[n]? (.-) and toss it into your bucket.*')
    local bucket_upgrade  = message:match('your clamming capacity has increased to (%d+) ponzes!')
    local bucket_turnin   = message:find('you return the clamming kit', 1, true)
    local overweight      = message:find('for the bucket and its bottom breaks', 1, true)
    local incident        = message:find('something jumps into your bucket', 1, true)

    if (bucket or item or bucket_turnin or overweight or incident) then
        H.last_attempt = now_ms
        if (H.settings.first_attempt == 0) then
            H.settings.first_attempt = now_ms
        end
        if (H.settings.visible[1] == false) then
            H.settings.visible[1] = true
        end
    end

    if bucket then
        clear_bucket()
        H.settings.bucket_count = (H.settings.bucket_count or 0) + 1
        H.has_bucket = true

    elseif item then
        H.play_tone = true
        H.settings.last_dig = now_ms

        if H.settings.dig_timer_countdown then
            H.settings.dig_timer = 10
        else
            H.settings.dig_timer = 0
        end

        H.settings.bucket[item] = (H.settings.bucket[item] or 0) + 1

        if H.settings.enable_logging[1] then
            WriteLog(H, LOGS, 'drop', item)
        end

        if H.weights[item] ~= nil then
            H.settings.bucket_weight = (H.settings.bucket_weight or 0) + H.weights[item]
        end

        analytics_after_item_dug(H, item)
        achievements_try_unlock(H)

    elseif bucket_upgrade then
        H.settings.bucket_capacity = tonumber(bucket_upgrade) or H.settings.bucket_capacity

    elseif bucket_turnin then
        on_turnin()
    end

    if overweight or incident then
        analytics_after_bucket_fail(H)
        clear_bucket()
        H.has_bucket = false
    end
end)

---------------------------------------------------------------------------------------------------
-- Main Render Loop (Present Event)
---------------------------------------------------------------------------------------------------
ashita.events.register('d3d_present', 'present_cb', function()
    if H.settings.zone_tracking.enabled[1] then update_zone_tracking(H) end
    analytics_update(H)
    analytics_check_profit_milestones(H)
    analytics_check_efficiency_warnings(H)
    analytics_check_break_reminders(H)
    discord_process(H)

    if H._ui_export_csv then
        H._ui_export_csv = false
        export_session(false)
    end

    if H.settings.visible[1] then
        local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav)
        if H.settings.display_mode[1] == 4 then flags = bit.bor(flags, ImGuiWindowFlags_NoBackground) end

        imgui.SetNextWindowSize({0,0}, ImGuiCond_Always)
        imgui.SetNextWindowBgAlpha(H.settings.opacity[1])
        imgui.SetNextWindowPos({ H.settings.x[1], H.settings.y[1] }, ImGuiCond_Always)

        if imgui.Begin('HXIClam Enhanced##Display', H.settings.visible, flags) then
            if H.settings.display_mode[1] == 1 then
                render_minimal_display(H)
            elseif H.settings.display_mode[1] == 3 then
                render_detailed_display(H)
            else
                render_standard_display(H)
            end
        end
        imgui.End()
    end

    render_settings_editor(H, settings)

    local now = ashita.time.clock()['s']
    if H.last_cleanup_time == 0 then H.last_cleanup_time = now
    elseif now - H.last_cleanup_time >= 300 then
        analytics_optimize_memory(H)
        H.last_cleanup_time = now
    end
end)

---------------------------------------------------------------------------------------------------
-- Mouse and Keyboard Event Handlers
---------------------------------------------------------------------------------------------------
ashita.events.register('key', 'key_callback', function(e)
    if e.wparam == 0x10 then -- VK_SHIFT
        H.move.shift_down = (bit.band(e.lparam, 0x80000000) == 0)
        return
    end
end)

ashita.events.register('mouse', 'mouse_cb', function(e)
    local function hit_test(x, y)
        local e_x = H.settings.x[1]; local e_y = H.settings.y[1]
        local e_w = ((32 * H.settings.scale[1]) * 4) + H.settings.padding[1] * 3
        local e_h = ((32 * H.settings.scale[1]) * 4) + H.settings.padding[1] * 3
        return ((e_x <= x) and (e_x + e_w) >= x) and ((e_y <= y) and (e_y + e_h) >= y)
    end
    local msg = e.message
    if msg == 512 then -- WM_MOUSEMOVE
        if H.move.dragging then
            H.settings.x[1] = e.x - H.move.drag_x
            H.settings.y[1] = e.y - H.move.drag_y
            e.blocked = true
        end
        return
    end
    if msg == 513 then -- WM_LBUTTONDOWN
        if H.move.shift_down and hit_test(e.x, e.y) then
            H.move.dragging = true
            H.move.drag_x = e.x - H.settings.x[1]
            H.move.drag_y = e.y - H.settings.y[1]
            e.blocked = true
        end
        return
    end
    if msg == 514 then -- WM_LBUTTONUP
        if H.move.dragging then
            H.move.dragging = false
            e.blocked = true
        end
    end
end)

