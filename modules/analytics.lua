-- modules/analytics.lua (ASCII only)

local ok_chat, chat_mod = pcall(require, 'chat'); local chat = (ok_chat and chat_mod) or rawget(_G, 'chat')
local util = rawget(_G, '__hxiclam_util') or dofile(((rawget(_G,'addon') and addon.path) or (rawget(_G,'__hxiclam_basepath') or '')) .. 'modules\\util.lua'); _G.__hxiclam_util = util
local social = rawget(_G, '__hxiclam_social') or dofile(((rawget(_G,'addon') and addon.path) or (rawget(_G,'__hxiclam_basepath') or '')) .. 'modules\\social_discord.lua'); _G.__hxiclam_social = social
local cloud = rawget(_G, '__hxiclam_cloud') or dofile(((rawget(_G,'addon') and addon.path) or (rawget(_G,'__hxiclam_basepath') or '')) .. 'modules\\cloud.lua'); _G.__hxiclam_cloud = cloud

local A = {}

function A.total_session_profit_now(h)
    local total = 0
    for k, v in pairs(h.settings.rewards) do
        if h.pricing[k] then total = total + (h.pricing[k] * v) end
    end
    if h.settings.clamming.bucket_subtract[1] then
        total = total - (h.settings.bucket_count * h.settings.clamming.bucket_cost[1])
    end
    return total
end

function A.initialize_session(h)
    h.last_analytics_update = ashita.time.clock()['s']
    h.current_efficiency = 0
    h.efficiency_trend = 'stable'
    h.session_milestones_hit = T{}
end

local function calc_eff(h)
    local elapsed = ashita.time.clock()['s'] - math.floor(h.settings.first_attempt / 1000.0)
    if elapsed <= 0 or h.settings.item_count <= 0 then return 0 end
    return (h.settings.item_count / elapsed) * 3600
end

function A.update_analytics(h)
    if not h.settings.analytics.enabled[1] then return end
    local now = ashita.time.clock()['s']
    if now - h.last_analytics_update < 30 then return end

    h.current_efficiency = calc_eff(h)
    local hist = h.settings.analytics.efficiency_history
    hist[#hist + 1] = { time = now, efficiency = h.current_efficiency }
    if #hist > 240 then table.remove(hist, 1) end

    if #hist >= 10 then
        local half = math.floor(#hist / 2)
        local older, recent = 0, 0
        for i = 1, half do older = older + hist[i].efficiency end
        for i = half + 1, #hist do recent = recent + hist[i].efficiency end
        older = older / half; recent = recent / half
        local change = older ~= 0 and ((recent - older) / older) * 100 or 0
        if change > 10 then h.efficiency_trend = 'improving'
        elseif change < -10 then h.efficiency_trend = 'declining'
        else h.efficiency_trend = 'stable' end
    end

    h.last_analytics_update = now
end

function A.check_profit_milestones(h)
    if not h.settings.notifications.enabled[1] then return end
    local total = A.total_session_profit_now(h)
    local idx   = h.settings.notifications.milestone_index[1]
    local miles = h.settings.notifications.profit_milestones
    if idx <= #miles and total >= miles[idx] then
        local v = miles[idx]
        if chat then
            print(chat.header('hxiclam'):append(chat.color1(6, ' Milestone reached! Total profit: ' .. util.format_int(v) .. ' gil')))
        end
        if h.settings.notifications.sound_enabled[1] then
            pcall(function() ashita.misc.play_sound(("%stones/%s"):format(rawget(_G,'__hxiclam_basepath') or '', h.settings.tone)) end)
        end
        h.settings.notifications.milestone_index[1] = idx + 1
        table.insert(h.session_milestones_hit, { time = ashita.time.clock()['s'], value = v })
        social.send_milestone(h, v)
        if h.settings.milestones_dynamic.enabled[1] then
            local scale = h.settings.milestones_dynamic.scale[1] or 1.5
            local nextv = math.max(v + (h.settings.milestones_dynamic.min_gap[1] or 500), math.floor(v * scale))
            table.insert(h.settings.notifications.profit_milestones, nextv)
        end
    end
end

function A.check_efficiency_warnings(h)
    if not h.settings.notifications.enabled[1] or not h.settings.notifications.efficiency_warnings[1] then return end
    if h.efficiency_trend == 'declining' and h.current_efficiency > 0 then
        local avg = 0
        local hist = h.settings.analytics.efficiency_history
        for _, e in ipairs(hist) do avg = avg + e.efficiency end
        if #hist > 0 then avg = avg / #hist end
        if #hist > 0 and h.current_efficiency < (avg * 0.70) then
            if chat then print(chat.header('hxiclam'):append(chat.color1(8, ' Efficiency declining! Consider a short break.'))) end
        end
    end
end

function A.check_break_reminders(h)
    if not h.settings.notifications.enabled[1] or not h.settings.notifications.break_reminders[1] then return end
    local now = ashita.time.clock()['s']
    local interval = h.settings.notifications.break_reminder_interval[1]
    if h.settings.last_break_reminder == 0 then
        h.settings.last_break_reminder = now
    elseif now - h.settings.last_break_reminder >= interval then
        local elapsed = now - math.floor(h.settings.first_attempt / 1000.0)
        if chat then
            print(chat.header('hxiclam'):append(chat.color1(11, ' Break reminder: You have been clamming for ' .. util.format_time_hms(elapsed) .. '.')))
        end
        h.settings.last_break_reminder = now
    end
end

function A.after_item_dug(h, item)
    if h.settings.analytics.enabled[1] then
        local f = h.settings.analytics.item_frequency
        f[item] = (f[item] or 0) + 1
    end
end

function A.after_bucket_turnin(h) end
function A.after_bucket_fail(h)  end

function A.optimize_memory_usage(h)
    local now = ashita.time.clock()['s']
    local cutoff = now - 7200
    local hist = h.settings.analytics.efficiency_history
    local keep = T{}
    for _, e in ipairs(hist) do if e.time > cutoff then keep[#keep + 1] = e end end
    h.settings.analytics.efficiency_history = keep
    if #h.session_milestones_hit > 20 then
        local nm = T{}
        for i = #h.session_milestones_hit - 19, #h.session_milestones_hit do nm[#nm + 1] = h.session_milestones_hit[i] end
        h.session_milestones_hit = nm
    end
end

function A.one_click_summary(h)
    local total = A.total_session_profit_now(h)
    local lines = {}
    lines[#lines + 1] = 'HXIClam Summary'
    lines[#lines + 1] = 'Profit: ' .. util.format_int(total) .. ' gil'
    lines[#lines + 1] = 'Items: ' .. tostring(h.settings.item_count)
    if h.settings.summary.include_zones[1] then
        lines[#lines + 1] = 'Zones:'
        for z, st in pairs(h.settings.zone_tracking.zone_stats) do
            lines[#lines + 1] = ' - ' .. z .. ' : ' .. util.format_int(st.profit or 0) .. ' gil'
        end
    end
    if h.settings.summary.include_items[1] then
        lines[#lines + 1] = 'Top Items:'
        for k,v in pairs(h.settings.rewards) do
            local val = (h.pricing[k] or 0) * v
            lines[#lines + 1] = ' - ' .. k .. ' x' .. tostring(v) .. ' = ' .. util.format_int(val)
        end
    end
    local text = table.concat(lines, '\n')
    if h.settings.summary.send_to_discord[1] then pcall(function() social.send_summary(h, text) end) end
    if h.settings.summary.save_as_file[1] then
        local dt = os.date('*t')
        local dir = ('%s/addons/hxiclam/exports/'):format(AshitaCore:GetInstallPath())
        if not ashita.fs.exists(dir) then ashita.fs.create_dir(dir) end
        local fname = ('summary_%04d%02d%02d_%02d%02d%02d.txt'):format(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec)
        local fp = io.open(dir .. fname, 'wb'); if fp then fp:write(text); fp:close(); cloud.copy_to_cloud_if_enabled(h, dir .. fname) end
    end
end

return A
