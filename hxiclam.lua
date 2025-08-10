-- hxiclam.lua
-- HXIClam (Modular) - Main (ASCII-only, Ashita v4)

addon.name     = 'hxiclam';
addon.author   = 'jimmy58663 (Oddone Edit) - Enhanced Version';
addon.version  = '2.2.0';
addon.desc     = 'HorizonXI clamming tracker with analytics, social, and modular UI.';
addon.link     = 'https://github.com/jimmy58663/hxiclam';
addon.commands = {'/hxiclam'};

require('common');
local chat     = require('chat');
local d3d      = require('d3d8');
local ffi      = require('ffi');
local imgui    = require('imgui');
local settings = require('settings');
local data     = require('constants');

_G.__hxiclam_basepath = addon.path or ''

local C       = ffi.C;
local d3d8dev = d3d.get_device();

-- Safe ImGui constants (fallback to 0 so Push/Begin calls still succeed)
local function FG(k) return rawget(_G, k) or 0 end
local ImGuiWindowFlags_NoDecoration        = FG('ImGuiWindowFlags_NoDecoration')
local ImGuiWindowFlags_AlwaysAutoResize    = FG('ImGuiWindowFlags_AlwaysAutoResize')
local ImGuiWindowFlags_NoFocusOnAppearing  = FG('ImGuiWindowFlags_NoFocusOnAppearing')
local ImGuiWindowFlags_NoNav               = FG('ImGuiWindowFlags_NoNav')
local ImGuiWindowFlags_NoBackground        = FG('ImGuiWindowFlags_NoBackground')
local ImGuiCond_Always                     = FG('ImGuiCond_Always')

-- Modules
local util         = dofile((addon.path or '') .. 'modules\\util.lua');         _G.__hxiclam_util = util
local display      = dofile((addon.path or '') .. 'modules\\display.lua');
local ui_settings  = dofile((addon.path or '') .. 'modules\\ui_settings.lua');
local cloud        = dofile((addon.path or '') .. 'modules\\cloud.lua');
local social       = dofile((addon.path or '') .. 'modules\\social_discord.lua'); _G.__hxiclam_social = social
local analytics    = dofile((addon.path or '') .. 'modules\\analytics.lua');      _G.__hxiclam_analytics = analytics
local achievements = dofile((addon.path or '') .. 'modules\\achievements.lua');

-- Logging folders
local logs = T{
    drop_log_dir   = 'drops',
    turnin_log_dir = 'turnins',
    backup_log_dir = 'backups',
    export_log_dir = 'exports',
    char_name      = nil
};

-- Defaults
local default_settings = T{
    visible = T{ true },
    moon_display = T{ false },
    display_timeout = T{ 600 },
    opacity = T{ 1.0 },
    padding = T{ 1.0 },
    scale = T{ 1.0 },
    item_index = data.ItemIndex,
    item_weight_index = data.ItemWeightIndex,
    font_scale = T{ 1.0 },
    x = T{ 100 }, y = T{ 100 },
    enable_logging = T{ true },
    show_session_time = T{ true },
    show_item_quantities = T{ true },
    show_item_values = T{ true },

    available_tones = T{ 'clam.wav' },
    tone_selected_idx = 1,
    tone = 'clam.wav',
    enable_tone = T{ true },

    dig_timer = 0,
    dig_timer_countdown = true,
    last_dig = 0,

    bucket = T{},
    rewards = T{},
    bucket_weight = 0,
    bucket_capacity = 50,
    has_bucket = false,
    bucket_count = 0,
    item_count = 0,

    session_view = 2,
    gil_per_hour = 0,

    clamming = {
        bucket_cost = T{ 500 },
        bucket_subtract = T{ true },
        stop_values = { [50]=T{1200},[100]=T{2400},[150]=T{3600},[200]=T{4800} },
        stop_weights_under_value = { [50]=T{4},[100]=T{6},[150]=T{8},[200]=T{10} },
        stop_weights_over_value  = { [50]=T{6},[100]=T{8},[150]=T{10},[200]=T{12} },
        stop_colors = { [50]={1,0.55,0,1},[100]={1,0.55,0,1},[150]={1,0.55,0,1},[200]={1,0.55,0,1} },
        color_logic_advanced = T{ true },
    },

    analytics = {
        enabled = T{ true },
        efficiency_history = T{},
        item_frequency = T{},
    },

    notifications = {
        enabled = T{ true },
        milestone_index = T{ 1 },
        profit_milestones = { 500, 1000, 2500, 5000, 10000, 20000 },
        sound_enabled = T{ true },
        efficiency_warnings = T{ true },
        break_reminders = T{ true },
        break_reminder_interval = T{ 3600 },
    },

    milestones_dynamic = {
        enabled = T{ true },
        scale = T{ 1.5 },
        min_gap = T{ 1000 },
    },

    summary = {
        one_click_enabled = T{ true },
        include_items = T{ true },
        include_zones = T{ true },
        send_to_discord = T{ false },
        save_as_file = T{ true },
    },

    autoscreenshot = {
        enabled = T{ false }, on_milestone = T{ true }, on_rare_item = T{ true }, on_best_streak = T{ true },
    },

    zone_tracking = {
        enabled = T{ true },
        current_zone = T{ '' },
        zone_start_time = T{ 0 },
        zone_stats = T{},
    },

    discord = {
        enabled = T{ false },
        webhook_url = T{ '' },
        queue_limit = T{ 50 },
        max_per_minute = T{ 10 },
        send_milestones = T{ true },
        send_streaks = T{ true },
        send_summaries = T{ true },
    },

    achievements = {
        enabled = T{ true },
        unlocked = T{},
        webhook  = T{ true },
    },

    smart = {
        turnin_enabled = T{ false },
        turnin_aggressiveness = T{ 0.5 },
        show_banner = T{ true },
    },

    heatmap = {
        enabled = T{ false },
    },

    sound_themes = {
        enabled = T{ false },
        theme = T{ 'default' },
        files = { default = { ready='clam.wav', milestone='clam.wav' } }
    },

    leaderboard = {
        enabled = T{ false },
        display_name = T{ 'Clammer' },
        privacy = T{ 'private' },
        share_discord = T{ false },
    },

    auto_backup_enabled = T{ false },
    auto_backup_interval = T{ 900 },

    export_format = T{ 1 }, -- 1=CSV, 2=JSON

    colors = {
        window_bg_color={0.06,0.06,0.07,0.94}, child_bg_color={0.06,0.06,0.07,0.60}, popup_bg_color={0.08,0.08,0.09,0.94},
        border_color={0.20,0.20,0.20,0.60}, border_shadow_color={0,0,0,0},
        text_color={0.86,0.86,0.86,1.00}, text_disabled_color={0.50,0.50,0.50,1.00},
        session_label_color={0.70,0.70,0.80,1.00}, session_value_color={0.90,0.90,0.95,1.00},
        session_header_color={0.90,0.90,1.00,1.00}, session_total_label_color={0.90,0.90,0.95,1.00}, session_total_value_color={0.80,1.00,0.80,1.00},
        session_time_color={0.85,0.85,0.95,1.00},
        revenue_label_color={0.80,0.90,1.00,1.00}, revenue_amount_color={0.80,0.95,0.80,1.00},
        profit_label_color={0.95,0.95,0.80,1.00}, profit_amount_positive_color={0.50,1.00,0.50,1.00}, profit_amount_negative_color={1.00,0.50,0.50,1.00},
        profit_percentage_tiers = { {percent=T{25}, color={0.85,0.85,0.85,1}}, {percent=T{50}, color={0.70,1.00,0.70,1}}, {percent=T{100}, color={0.30,1.00,0.30,1}}, },
        use_percentage_profit_colors = T{ true },
        has_bucket_color={0.80,1.00,0.85,1.00}, no_bucket_color={1.00,0.70,0.70,1.00},
        bucket_item_name_color={0.90,0.90,0.90,1.00}, bucket_item_count_color={0.95,0.95,0.80,1.00}, bucket_item_value_color={0.80,0.95,0.80,1.00},
        dig_timer_normal_color={0.85,0.85,0.90,1.00}, dig_timer_ready_color={0.50,1.00,0.50,1.00},
        bucket_weight_warn_color={1.00,0.80,0.35,1.00}, bucket_weight_crit_color={1.00,0.40,0.40,1.00},
        bucket_weight_warn_threshold=T{8}, bucket_weight_crit_threshold=T{4},
        zone_label_color={0.85,0.85,0.90,1.00}, zone_value_color={0.90,0.95,1.00,1.00},
        milestone_color={0.90,1.00,0.90,1.00},
        bucket_weight_font_scale=T{1.0},
    },

    editor = { is_open = T{ false } },
}

-- State
local hxiclam = T{}
hxiclam.settings = settings.load(default_settings)
hxiclam.pricing  = {}
hxiclam.weights  = {}
hxiclam.move     = { dragging=false, shift_down=false, drag_x=0, drag_y=0 }
hxiclam.last_cleanup_time = 0

-- Utilities
local function parse_pairs(list)
    local out = {}
    for _, s in ipairs(list) do
        local name, val = s:match('^(.-):(%-?%d+)$')
        if name and val then out[name] = tonumber(val) end
    end
    return out
end

local function update_pricing()
    hxiclam.pricing = parse_pairs(hxiclam.settings.item_index or {})
end

local function update_weights()
    hxiclam.weights = parse_pairs(hxiclam.settings.item_weight_index or {})
end

local function clear_bucket()
    hxiclam.settings.bucket = T{}
    hxiclam.settings.bucket_weight = 0
end

local function clear_rewards()
    hxiclam.settings.rewards = T{}
    hxiclam.settings.item_count = 0
    hxiclam.settings.bucket_count = 0
    hxiclam.gil_per_hour = 0
end

local function create_backup()
    local dt = os.date('*t')
    local dir = ('%s/addons/hxiclam/logs/%s/'):format(AshitaCore:GetInstallPath(), logs.backup_log_dir)
    if not ashita.fs.exists(dir) then ashita.fs.create_dir(dir) end
    local fname = ('backup_%04d%02d%02d_%02d%02d%02d.json'):format(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec)
    local f = io.open(dir .. fname, 'wb')
    if not f then return end
    local snapshot = {
        settings = hxiclam.settings,
        rewards  = hxiclam.settings.rewards,
        bucket   = hxiclam.settings.bucket,
        bucket_weight = hxiclam.settings.bucket_weight
    }
    local ok, j = pcall(function() return require('json').encode(snapshot) end)
    if ok then f:write(j) end
    f:close()
    cloud.copy_to_cloud_if_enabled(hxiclam, dir .. fname)
end

local function export_session(as_json)
    local dt = os.date('*t')
    local dir = ('%s/addons/hxiclam/%s/'):format(AshitaCore:GetInstallPath(), logs.export_log_dir)
    if not ashita.fs.exists(dir) then ashita.fs.create_dir(dir) end
    local stamp = ('%04d%02d%02d_%02d%02d%02d'):format(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec)
    local ext = as_json and '.json' or '.csv'
    local out

    if not as_json then
        local lines = { 'item,count,price,value' }
        local total = 0
        for k,v in pairs(hxiclam.settings.rewards) do
            local p = hxiclam.pricing[k] or 0
            local val = p * v
            total = total + val
            lines[#lines+1] = ('"%s",%d,%d,%d'):format(k, v, p, val)
        end
        lines[#lines+1] = ('Total,,,%d'):format(total)
        out = table.concat(lines, '\n')
    else
        local json_data = {
            bucket_count = hxiclam.settings.bucket_count,
            items_dug = hxiclam.settings.item_count,
            rewards = hxiclam.settings.rewards,
            pricing = hxiclam.pricing,
            weights = hxiclam.weights,
            zone_statistics = hxiclam.settings.zone_tracking.zone_stats,
            analytics = {
                current_efficiency = hxiclam.current_efficiency,
                efficiency_trend = hxiclam.efficiency_trend,
                milestones_hit = hxiclam.session_milestones_hit
            }
        }
        local ok, j = pcall(function() return require('json').encode(json_data) end)
        out = ok and j or 'null'
    end

    local fname = ('%s_export_%s%s'):format(logs.char_name or 'unknown', stamp, ext)
    local f = io.open(dir .. fname, 'w')
    if f then f:write(out) f:close()
        print(chat.header(addon.name):append(chat.message('Session exported to: ' .. fname)))
        cloud.copy_to_cloud_if_enabled(hxiclam, dir .. fname)
        cloud.write_mobile_companion_json(hxiclam)
        return true
    end
    print(chat.header(addon.name):append(chat.error('Failed to export session data.')))
    return false
end

settings.register('settings', 'settings_update', function(s)
    if s ~= nil then hxiclam.settings = s end
    settings.save()
    update_pricing()
    update_weights()
end)

-- Load / Unload
ashita.events.register('load', 'load_cb', function()
    update_pricing()
    update_weights()
    util.update_tones(hxiclam, addon.path)
    if hxiclam.settings.reset_on_load[1] then
        print('Reset bucket and session on reload.')
        clear_rewards(); clear_bucket()
    end

    local name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)
    if name ~= nil and name:len() > 0 then logs.char_name = name end

    util.update_zone_tracking(hxiclam) -- initialize
    social.init(hxiclam)               -- webhooks
    analytics.initialize_session(hxiclam)

    print(chat.header(addon.name):append(chat.color1(10, 'HXIClam Enhanced loaded. Use /hxiclam help.')))
end)

ashita.events.register('unload', 'unload_cb', function()
    if hxiclam.settings.auto_backup_enabled[1] then create_backup() end
    settings.save()
end)

-- Commands
local function print_help(isError)
    if isError then
        print(chat.header(addon.name):append(chat.error('Invalid command. Use /hxiclam help')))
        return
    end
    local cmds = T{
        {'/hxiclam edit', 'Open or close the settings editor.'},
        {'/hxiclam save', 'Save current settings to disk.'},
        {'/hxiclam reload', 'Reload settings from disk.'},
        {'/hxiclam clear', 'Clear bucket and session.'},
        {'/hxiclam clear bucket', 'Clear bucket only.'},
        {'/hxiclam clear session', 'Clear session only.'},
        {'/hxiclam show', 'Show main display.'},
        {'/hxiclam hide', 'Hide main display.'},
        {'/hxiclam show session', 'Show session stats view.'},
        {'/hxiclam update', 'Update pricing and weights.'},
        {'/hxiclam backup', 'Create a manual backup now.'},
        {'/hxiclam export', 'Export session to CSV.'},
        {'/hxiclam export json', 'Export session to JSON.'},
        {'/hxiclam mode <1-4>', 'Display mode: 1=minimal,2=standard,3=detailed,4=overlay.'},
        {'/hxiclam analytics', 'Toggle analytics on or off.'},
        {'/hxiclam zone', 'Print current zone and stats.'},
        {'/hxiclam discord enable', 'Enable Discord webhooks.'},
        {'/hxiclam discord disable', 'Disable Discord webhooks.'},
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

    if #args == 1 or (#args >= 2 and args[2]:any('edit')) then
        hxiclam.editor.is_open[1] = not hxiclam.editor.is_open[1]; return
    end
    if #args >= 2 and args[2]:any('help') then print_help(false); return end
    if #args >= 2 and args[2]:any('save') then update_pricing(); update_weights(); settings.save(); print(chat.header(addon.name):append(chat.message('Settings saved.'))); return end
    if #args >= 2 and args[2]:any('reload') then settings.reload(); util.update_tones(hxiclam, addon.path); print(chat.header(addon.name):append(chat.message('Settings reloaded.'))); return end
    if #args >= 2 and args[2]:any('clear') then
        if #args >= 3 and args[3]:any('bucket') then clear_bucket() else if #args >= 3 and args[3]:any('session') then clear_rewards() else clear_bucket(); clear_rewards() end end
        print(chat.header(addon.name):append(chat.message('Cleared.'))); return
    end
    if #args >= 2 and args[2]:any('show') then hxiclam.settings.visible[1] = true; return end
    if #args >= 2 and args[2]:any('hide') then hxiclam.settings.visible[1] = false; return end
    if #args >= 2 and args[2]:any('update') then update_pricing(); update_weights(); print(chat.header(addon.name):append(chat.message('Pricing/weights updated.'))); return end
    if #args >= 2 and args[2]:any('backup') then create_backup(); print(chat.header(addon.name):append(chat.message('Backup created.'))); return end
    if #args >= 2 and args[2]:any('export') then
        local as_json = (#args >= 3 and args[3]:any('json'))
        export_session(as_json); return
    end
    if #args >= 2 and args[2]:any('mode') and #args >= 3 then
        local m = tonumber(args[3]) or 2
        hxiclam.settings.display_mode[1] = math.max(1, math.min(4, m)); return
    end
    if #args >= 2 and args[2]:any('analytics') then
        hxiclam.settings.analytics.enabled[1] = not hxiclam.settings.analytics.enabled[1]
        print(chat.header(addon.name):append(chat.message('Analytics: ' .. tostring(hxiclam.settings.analytics.enabled[1])))); return
    end
    if #args >= 2 and args[2]:any('zone') then
        print(chat.header(addon.name):append(chat.message('Zone: ' .. util.get_current_zone()))); return
    end
    if #args >= 2 and args[2]:any('discord') then
        if #args >= 3 and args[3]:any('enable') then hxiclam.settings.discord.enabled[1] = true; print('Discord enabled.'); return end
        if #args >= 3 and args[3]:any('disable') then hxiclam.settings.discord.enabled[1] = false; print('Discord disabled.'); return end
        if #args >= 4 and args[3]:any('url') then hxiclam.settings.discord.webhook_url[1] = args[4]; print('Discord webhook set.'); return end
    end
    if #args >= 2 and args[2]:any('summary') then
        analytics.one_click_summary(hxiclam); print('Summary generated.'); return
    end

    print_help(true)
end)

-- Text parsing (dig results & turn-ins)
local item_patterns = {
    '^You dig up (?:an? )?(.+)%.',
    '^You find (?:an? )?(.+)%.',
    '^Obtained: (.+)%.',
}

local function normalize_item(name)
    name = (name or ''):lower():gsub('%s+', ' ')
    return name
end

local function add_item(name)
    local item = normalize_item(name)
    if item == '' then return end
    hxiclam.settings.item_count = (hxiclam.settings.item_count or 0) + 1
    hxiclam.settings.rewards[item] = (hxiclam.settings.rewards[item] or 0) + 1
    hxiclam.settings.bucket[item]  = (hxiclam.settings.bucket[item]  or 0) + 1
    local w = hxiclam.weights[item] or 1
    hxiclam.settings.bucket_weight = hxiclam.settings.bucket_weight + w
    analytics.after_item_dug(hxiclam, item)
    achievements.try_unlock(hxiclam)
    if hxiclam.settings.enable_logging[1] then util.WriteLog(hxiclam, logs, 'drop', item) end
end

local function on_turnin()
    hxiclam.settings.bucket_count = (hxiclam.settings.bucket_count or 0) + 1
    clear_bucket()
    achievements.try_unlock(hxiclam)
    analytics.after_bucket_turnin(hxiclam)
    if hxiclam.settings.enable_logging[1] then util.WriteLog(hxiclam, logs, 'turnin', 'Bucket Turn-In') end
end

ashita.events.register('text_in', 'text_in_cb', function(e)
    -- mode 121, 123 etc. for system; just scan message text
    local t = e.message or ''
    for _, pat in ipairs(item_patterns) do
        local m = t:match(pat)
        if m then add_item(m); break end
    end
    if t:find('trade your clamming kit') or t:find('turn in your bucket') then
        on_turnin()
    end
    if t:find('You fail to dig up anything') or t:find('Your clamming kit breaks') then
        analytics.after_bucket_fail(hxiclam)
    end
end)

-- Present (render & cadence)
ashita.events.register('d3d_present', 'present_cb', function()
    if hxiclam.settings.zone_tracking.enabled[1] then util.update_zone_tracking(hxiclam) end
    analytics.update_analytics(hxiclam)
    analytics.check_profit_milestones(hxiclam)
    analytics.check_efficiency_warnings(hxiclam)
    analytics.check_break_reminders(hxiclam)
    social.process_queue(hxiclam)

    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav)
    if hxiclam.settings.display_mode[1] == 4 then
        flags = bit.bor(flags, ImGuiWindowFlags_NoBackground)
    end

    imgui.SetNextWindowSize({0,0}, ImGuiCond_Always)
    imgui.SetNextWindowBgAlpha(hxiclam.settings.opacity[1])
    imgui.SetNextWindowPos({ hxiclam.settings.x[1], hxiclam.settings.y[1] }, ImGuiCond_Always)

    if imgui.Begin('HXIClam Enhanced##Display', hxiclam.settings.visible[1], flags) then
        if display and display.render_minimal_display then
            if hxiclam.settings.display_mode[1] == 1 then
                display.render_minimal_display(hxiclam, addon.path)
            elseif hxiclam.settings.display_mode[1] == 3 and display.render_detailed_display then
                display.render_detailed_display(hxiclam, addon.path)
            else
                display.render_standard_display(hxiclam, addon.path)
            end
        end
    end
    imgui.End()

    -- memory cleanup every 5 minutes
    local now = ashita.time.clock()['s']
    if hxiclam.last_cleanup_time == 0 then hxiclam.last_cleanup_time = now
    elseif now - hxiclam.last_cleanup_time >= 300 then
        analytics.optimize_memory_usage(hxiclam)
        hxiclam.last_cleanup_time = now
    end
end)

-- Key / Mouse dragging (hold SHIFT to drag)
ashita.events.register('key', 'key_callback', function(e)
    if e.wparam == 0x10 then -- VK_SHIFT
        hxiclam.move.shift_down = not (bit.band(e.lparam, bit.lshift(0x8000, 0x10)) == bit.lshift(0x8000, 0x10))
        return
    end
end)

ashita.events.register('mouse', 'mouse_cb', function(e)
    local function hit_test(x, y)
        local e_x = hxiclam.settings.x[1]; local e_y = hxiclam.settings.y[1]
        local e_w = ((32 * hxiclam.settings.scale[1]) * 4) + hxiclam.settings.padding[1] * 3
        local e_h = ((32 * hxiclam.settings.scale[1]) * 4) + hxiclam.settings.padding[1] * 3
        return ((e_x <= x) and (e_x + e_w) >= x) and ((e_y <= y) and (e_y + e_h) >= y)
    end

    local msg = e.message
    if msg == 512 then -- WM_MOUSEMOVE
        if hxiclam.move.dragging then
            hxiclam.settings.x[1] = e.x - hxiclam.move.drag_x
            hxiclam.settings.y[1] = e.y - hxiclam.move.drag_y
            e.blocked = true
        end
        return
    end

    if msg == 513 then -- WM_LBUTTONDOWN
        if hxiclam.move.shift_down and hit_test(e.x, e.y) then
            hxiclam.move.dragging = true
            hxiclam.move.drag_x = e.x - hxiclam.settings.x[1]
            hxiclam.move.drag_y = e.y - hxiclam.settings.y[1]
            e.blocked = true
        end
        return
    end

    if msg == 514 then -- WM_LBUTTONUP
        if hxiclam.move.dragging then
            hxiclam.move.dragging = false
            e.blocked = true
        end
        return
    end
end)
