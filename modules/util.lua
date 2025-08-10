-- modules/util.lua
-- Utility, theming, audio, zone/moon helpers, formatting, file logging.

-- Safe requires
local ok_imgui, imgui_mod = pcall(require, 'imgui');  local imgui = (ok_imgui and imgui_mod) or rawget(_G, 'imgui')
local ok_chat , chat_mod  = pcall(require, 'chat');   local chat  = (ok_chat  and chat_mod ) or rawget(_G, 'chat')
local ok_const, const_mod = pcall(require, 'constants'); local data = (ok_const and const_mod) or rawget(_G, 'constants') or {}

-- Cache base path so modules can locate siblings without assuming globals
local function basepath()
    local p = (rawget(_G, 'addon') and addon.path) or rawget(_G, '__hxiclam_basepath') or ''
    return type(p) == 'string' and p or ''
end
_G.__hxiclam_basepath = basepath()

local util = {}

-- ---------- formatting ----------
function util.split(s, sep)
    sep = sep or '%s'
    local t = {}
    for str in string.gmatch(s or '', '([^' .. sep .. ']+)') do t[#t + 1] = str end
    return t
end

function util.format_int(n)
    if type(n) ~= 'number' then return tostring(n or 0) end
    local s, neg = tostring(math.floor(n)), n < 0 and '-' or ''
    s = s:gsub('^-', '')
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return neg .. out
end

function util.format_time_hms(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format('%02d:%02d:%02d', h, m, s)
end

-- ---------- color safety ----------
local function ensure_tbl(t) if type(t) ~= 'table' then return {} end return t end
function util.ensure_color(colors, key, default)
    colors = ensure_tbl(colors)
    if type(colors[key]) ~= 'table' or #colors[key] < 4 then
        colors[key] = { default[1], default[2], default[3], default[4] }
    end
    return colors[key]
end

-- ---------- ImGui constants (safe fallbacks) ----------
local function FG(k) return rawget(_G, k) or 0 end
local ImGuiCol_Text                 = FG('ImGuiCol_Text')
local ImGuiCol_TextDisabled         = FG('ImGuiCol_TextDisabled')
local ImGuiCol_WindowBg             = FG('ImGuiCol_WindowBg')
local ImGuiCol_ChildBg              = FG('ImGuiCol_ChildBg')
local ImGuiCol_PopupBg              = FG('ImGuiCol_PopupBg')
local ImGuiCol_Border               = FG('ImGuiCol_Border')
local ImGuiCol_BorderShadow         = FG('ImGuiCol_BorderShadow')
local ImGuiCol_FrameBg              = FG('ImGuiCol_FrameBg')
local ImGuiCol_FrameBgHovered       = FG('ImGuiCol_FrameBgHovered')
local ImGuiCol_FrameBgActive        = FG('ImGuiCol_FrameBgActive')
local ImGuiCol_TitleBg              = FG('ImGuiCol_TitleBg')
local ImGuiCol_TitleBgActive        = FG('ImGuiCol_TitleBgActive')
local ImGuiCol_TitleBgCollapsed     = FG('ImGuiCol_TitleBgCollapsed')
local ImGuiCol_MenuBarBg            = FG('ImGuiCol_MenuBarBg')
local ImGuiCol_ScrollbarBg          = FG('ImGuiCol_ScrollbarBg')
local ImGuiCol_ScrollbarGrab        = FG('ImGuiCol_ScrollbarGrab')
local ImGuiCol_ScrollbarGrabHovered = FG('ImGuiCol_ScrollbarGrabHovered')
local ImGuiCol_ScrollbarGrabActive  = FG('ImGuiCol_ScrollbarGrabActive')
local ImGuiCol_CheckMark            = FG('ImGuiCol_CheckMark')
local ImGuiCol_SliderGrab           = FG('ImGuiCol_SliderGrab')
local ImGuiCol_SliderGrabActive     = FG('ImGuiCol_SliderGrabActive')
local ImGuiCol_Button               = FG('ImGuiCol_Button')
local ImGuiCol_ButtonHovered        = FG('ImGuiCol_ButtonHovered')
local ImGuiCol_ButtonActive         = FG('ImGuiCol_ButtonActive')
local ImGuiCol_Header               = FG('ImGuiCol_Header')
local ImGuiCol_HeaderHovered        = FG('ImGuiCol_HeaderHovered')
local ImGuiCol_HeaderActive         = FG('ImGuiCol_HeaderActive')
local ImGuiCol_Separator            = FG('ImGuiCol_Separator')
local ImGuiCol_SeparatorHovered     = FG('ImGuiCol_SeparatorHovered')
local ImGuiCol_SeparatorActive      = FG('ImGuiCol_SeparatorActive')
local ImGuiCol_ResizeGrip           = FG('ImGuiCol_ResizeGrip')
local ImGuiCol_ResizeGripHovered    = FG('ImGuiCol_ResizeGripHovered')
local ImGuiCol_ResizeGripActive     = FG('ImGuiCol_ResizeGripActive')
local ImGuiCol_Tab                  = FG('ImGuiCol_Tab')
local ImGuiCol_TabHovered           = FG('ImGuiCol_TabHovered')
local ImGuiCol_TabActive            = FG('ImGuiCol_TabActive')
local ImGuiCol_TabUnfocused         = FG('ImGuiCol_TabUnfocused')
local ImGuiCol_TabUnfocusedActive   = FG('ImGuiCol_TabUnfocusedActive')
local ImGuiCol_DockingPreview       = FG('ImGuiCol_DockingPreview')
local ImGuiCol_DockingEmptyBg       = FG('ImGuiCol_DockingEmptyBg')
local ImGuiCol_NavHighlight         = FG('ImGuiCol_NavHighlight')
local ImGuiCol_NavWindowingHighlight= FG('ImGuiCol_NavWindowingHighlight')
local ImGuiCol_NavWindowingDimBg    = FG('ImGuiCol_NavWindowingDimBg')
local ImGuiCol_ModalWindowDimBg     = FG('ImGuiCol_ModalWindowDimBg')

-- ---------- tooltips ----------
function util.help(text)
    if not (imgui and text) then return end
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(420)
        imgui.TextUnformatted(text)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

-- Push many theme colors defined in settings.colors.
function util.push_imgui_style(colors)
    if not imgui then return 0 end
    colors = ensure_tbl(colors)
    local n = 0
    local function P(idx, key, def)
        local c = util.ensure_color(colors, key, def)
        imgui.PushStyleColor(idx, { c[1], c[2], c[3], c[4] }); n = n + 1
    end
    -- Defaults (professional dark theme)
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
    P(ImGuiCol_Text,               'text_color',               D.text)
    P(ImGuiCol_TextDisabled,       'text_disabled_color',      D.text_dis)
    P(ImGuiCol_WindowBg,           'window_bg_color',          D.winbg)
    P(ImGuiCol_ChildBg,            'child_bg_color',           D.child)
    P(ImGuiCol_PopupBg,            'popup_bg_color',           D.popup)
    P(ImGuiCol_Border,             'border_color',             D.border)
    P(ImGuiCol_BorderShadow,       'border_shadow_color',      D.bshadow)
    P(ImGuiCol_FrameBg,            'frame_bg_color',           D.fbg)
    P(ImGuiCol_FrameBgHovered,     'frame_bg_hovered_color',   D.fhov)
    P(ImGuiCol_FrameBgActive,      'frame_bg_active_color',    D.fact)
    P(ImGuiCol_TitleBg,            'title_bg_color',           D.title)
    P(ImGuiCol_TitleBgActive,      'title_bg_active_color',    D.tactive)
    P(ImGuiCol_TitleBgCollapsed,   'title_bg_collapsed_color', D.tcoll)
    P(ImGuiCol_MenuBarBg,          'menubar_bg_color',         D.menubg)
    P(ImGuiCol_ScrollbarBg,        'scrollbar_bg_color',       D.sbbg)
    P(ImGuiCol_ScrollbarGrab,      'scrollbar_grab_color',     D.sbg)
    P(ImGuiCol_ScrollbarGrabHovered,'scrollbar_grab_hovered_color', D.sbgh)
    P(ImGuiCol_ScrollbarGrabActive,'scrollbar_grab_active_color',   D.sbga)
    P(ImGuiCol_CheckMark,          'checkmark_color',          D.check)
    P(ImGuiCol_SliderGrab,         'slider_grab_color',        D.sgrab)
    P(ImGuiCol_SliderGrabActive,   'slider_grab_active_color', D.sgraba)
    P(ImGuiCol_Button,             'button_color',             D.btn)
    P(ImGuiCol_ButtonHovered,      'button_hovered_color',     D.btnh)
    P(ImGuiCol_ButtonActive,       'button_active_color',      D.btna)
    P(ImGuiCol_Header,             'header_color',             D.header)
    P(ImGuiCol_HeaderHovered,      'header_hovered_color',     D.headerh)
    P(ImGuiCol_HeaderActive,       'header_active_color',      D.headera)
    P(ImGuiCol_Separator,          'separator_color',          D.sep)
    P(ImGuiCol_SeparatorHovered,   'separator_hovered_color',  D.seph)
    P(ImGuiCol_SeparatorActive,    'separator_active_color',   D.sepa)
    P(ImGuiCol_ResizeGrip,         'resize_grip_color',        D.grip)
    P(ImGuiCol_ResizeGripHovered,  'resize_grip_hovered_color',D.griph)
    P(ImGuiCol_ResizeGripActive,   'resize_grip_active_color', D.gripa)
    P(ImGuiCol_Tab,                'tab_color',                D.tab)
    P(ImGuiCol_TabHovered,         'tab_hovered_color',        D.tabh)
    P(ImGuiCol_TabActive,          'tab_active_color',         D.taba)
    P(ImGuiCol_TabUnfocused,       'tab_unfocused_color',      D.tabun)
    P(ImGuiCol_TabUnfocusedActive, 'tab_unfocused_active_color', D.tabuna)
    P(ImGuiCol_DockingPreview,     'docking_preview_color',    D.dockp)
    P(ImGuiCol_DockingEmptyBg,     'docking_empty_bg_color',   D.dockbg)
    P(ImGuiCol_NavHighlight,       'nav_highlight_color',      D.navhi)
    P(ImGuiCol_NavWindowingHighlight,'nav_windowing_highlight_color', D.navwh)
    P(ImGuiCol_NavWindowingDimBg,  'nav_windowing_dim_bg_color', D.navdim)
    P(ImGuiCol_ModalWindowDimBg,   'modal_window_dim_bg_color', D.modaldim)
    return n
end

function util.pop_imgui_style(n)
    if imgui and n and n > 0 then imgui.PopStyleColor(n) end
end

-- ---------- zone / moon helpers ----------
local function vana_timestamp()
    local ok, t = pcall(function()
        local pVanaTime = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0)
        local pointer   = ashita.memory.read_uint32(pVanaTime + 0x34)
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

function util.get_moon()
    local ts = vana_timestamp()
    local idx = ((ts.day + 26) % 84) + 1
    local ph  = (data.MoonPhase        and data.MoonPhase[idx])        or 'Waxing'
    local pct = (data.MoonPhasePercent and data.MoonPhasePercent[idx]) or 50
    return { MoonPhase = ph, MoonPhasePercent = pct }
end

function util.get_current_zone()
    local ok, z = pcall(function()
        local id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
        if id and id > 0 then
            local name = AshitaCore:GetResourceManager():GetString('zones', id)
            if name and #name > 0 then return name end
        end
        return 'Unknown'
    end)
    return ok and z or 'Unknown'
end

function util.update_zone_tracking(h)
    if not h or not h.settings.zone_tracking.enabled[1] then return end
    local cur  = util.get_current_zone()
    local prev = h.settings.zone_tracking.current_zone[1]
    if cur ~= prev then
        if prev ~= '' and h.settings.zone_tracking.zone_start_time[1] > 0 then
            local t  = ashita.time.clock()['s'] - h.settings.zone_tracking.zone_start_time[1]
            local zs = h.settings.zone_tracking.zone_stats
            zs[prev] = zs[prev] or { profit=0, items=0, time=0, buckets=0 }
            zs[prev].time = (zs[prev].time or 0) + t
        end
        h.settings.zone_tracking.current_zone[1] = cur
        h.settings.zone_tracking.zone_start_time[1] = ashita.time.clock()['s']
        if chat then print(chat.header('hxiclam'):append(chat.message('Zone changed to: ' .. cur))) end
    end
end

-- ---------- sounds ----------
function util.update_tones(h, apath)
    if not h then return end
    h.settings.available_tones = {}
    local tone_path = string.format('%stones/', apath or basepath())
    local cmd = 'dir "' .. tone_path .. '" /B'
    local idx = 1
    for file in io.popen(cmd):lines() do
        if file:match('%.wav$') then
            h.settings.available_tones[idx] = file
            idx = idx + 1
        end
    end
    if idx == 1 then h.settings.available_tones[1] = 'clam.wav' end
end

function util.maybe_play_ready_tone(h)
    if not h then return end
    if h.settings.enable_tone[1] and h.play_tone == true then
        pcall(function()
            ashita.misc.play_sound(("%stones/%s"):format(basepath(), h.settings.tone))
        end)
        h.play_tone = false
    end
end

-- ---------- clamming color logic ----------
function util.updateWeightColor(h, bucketSize, bucketWeight, money)
    local defaultColor = {0.50, 1.00, 0.50, 1.00}
    local remain = (bucketSize or 0) - (bucketWeight or 0)
    if not h.settings.clamming.color_logic_advanced[1] then
        if remain <= h.settings.bucket_weight_crit_threshold[1] then
            return h.settings.bucket_weight_crit_color
        elseif remain <= h.settings.bucket_weight_warn_threshold[1] then
            return h.settings.bucket_weight_warn_color
        else
            return defaultColor
        end
    else
        local sv  = h.settings.clamming.stop_values[bucketSize] and h.settings.clamming.stop_values[bucketSize][1] or 0
        local su  = h.settings.clamming.stop_weights_under_value[bucketSize] and h.settings.clamming.stop_weights_under_value[bucketSize][1] or 0
        local so  = h.settings.clamming.stop_weights_over_value[bucketSize]  and h.settings.clamming.stop_weights_over_value[bucketSize][1]  or 0
        local scol= h.settings.clamming.stop_colors[bucketSize] or {1,0,0,1}
        local currentProfit = (money or 0) - (h.settings.clamming.bucket_cost[1] or 0)
        if currentProfit >= sv then
            if remain <= so then return scol end
        else
            if remain <= su then return scol end
        end
        return defaultColor
    end
end

function util.getProfitPercentageColor(h, bucketSize, currentProfit)
    if not h.settings.colors.use_percentage_profit_colors[1] then
        return currentProfit >= 0 and h.settings.colors.profit_amount_positive_color
            or h.settings.colors.profit_amount_negative_color
    end
    local stopValue = (h.settings.clamming.stop_values[bucketSize] and h.settings.clamming.stop_values[bucketSize][1]) or 0
    local pct  = (stopValue ~= 0) and ((currentProfit / stopValue) * 100) or 0
    local tiers= h.settings.colors.profit_percentage_tiers or {}
    for i = #tiers, 1, -1 do
        local th = tiers[i].percent and tiers[i].percent[1] or 0
        if pct >= th then return tiers[i].color end
    end
    return (#tiers > 0 and tiers[1].color) or h.settings.colors.profit_amount_positive_color
end

-- ---------- file logging ----------
function util.WriteLog(h, logs, logtype, item)
    local dirkey = (logtype == 'drop') and logs.drop_log_dir or logs.turnin_log_dir
    local dt = os.date('*t')
    local fname = ('%s_%.4u.%.2u.%.2u.log'):format(logs.char_name or 'unknown', dt.year, dt.month, dt.day)
    local full = ('%s/addons/hxiclam/logs/%s/'):format(AshitaCore:GetInstallPath(), dirkey)
    if not ashita.fs.exists(full) then ashita.fs.create_dir(full) end
    local f = io.open(full .. '/' .. fname, 'a')
    if f then
        local zone = util.get_current_zone()
        local line = ('%s, %s, %s\n'):format(os.date('[%H:%M:%S]'), zone, item or '')
        f:write(line); f:close()
    end
end

return util
