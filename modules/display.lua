-- modules/display.lua (ASCII only)
local ok_imgui, imgui_mod = pcall(require, 'imgui'); local imgui = (ok_imgui and imgui_mod) or rawget(_G, 'imgui')
if not imgui then return {} end

local ok_const, const_mod = pcall(require, 'constants'); local data = (ok_const and const_mod) or rawget(_G, 'constants') or {}

-- util (robust import)
local util = rawget(_G, '__hxiclam_util') or dofile(((rawget(_G,'addon') and addon.path) or (rawget(_G,'__hxiclam_basepath') or '')) .. 'modules\\util.lua'); _G.__hxiclam_util = util

local display = {}

local function display_name(item)
    local map = data.ItemDisplayNames or {}
    local d = map[item]
    if d and #d > 0 then return d end
    return (tostring(item or ''):gsub('^%l', string.upper))
end

local function timer_text(h)
    local timer_display = h.settings.dig_timer
    if h.settings.dig_timer_countdown then
        local dig_diff = (math.floor(h.settings.last_dig / 1000.0) + 10) - ashita.time.clock()['s']
        if dig_diff < h.settings.dig_timer then h.settings.dig_timer = dig_diff end
        timer_display = h.settings.dig_timer
        if timer_display <= 0 then return '[*]', true end
    else
        local dig_diff = ashita.time.clock()['s'] - math.floor(h.settings.last_dig / 1000.0)
        if dig_diff > h.settings.dig_timer then h.settings.dig_timer = dig_diff end
        timer_display = h.settings.dig_timer
        if timer_display >= 10 then return '[*]', true end
    end
    return tostring(timer_display), false
end

local function bucket_value(h)
    local total = 0
    for k, v in pairs(h.settings.bucket) do
        if h.pricing[k] then total = total + (v * h.pricing[k]) end
    end
    return total
end

function display.render_minimal_display(h, apath)
    local value = bucket_value(h)
    local bw_color = util.updateWeightColor(h, h.settings.bucket_capacity, h.settings.bucket_weight, value)

    imgui.TextColored(h.settings.colors.session_label_color, 'Weight:')
    imgui.SameLine()
    imgui.TextColored(bw_color, string.format('%d/%d', h.settings.bucket_weight, h.settings.bucket_capacity))

    local txt, ready = timer_text(h)
    imgui.TextColored(h.settings.colors.session_label_color, 'Timer:')
    imgui.SameLine()
    if ready then
        imgui.TextColored(h.settings.dig_timer_ready_color, txt)
        util.maybe_play_ready_tone(h)
    else
        imgui.TextColored(h.settings.colors.dig_timer_normal_color, txt)
    end
end

function display.render_standard_display(h, apath)
    local elapsed = ashita.time.clock()['s'] - math.floor(h.settings.first_attempt / 1000.0)
    local txt, ready = timer_text(h)
    local value = bucket_value(h)
    local bw_color = util.updateWeightColor(h, h.settings.bucket_capacity, h.settings.bucket_weight, value)

    imgui.SetWindowFontScale(h.settings.font_scale[1] + 0.10)
    local head_color = h.has_bucket and h.settings.colors.has_bucket_color or h.settings.colors.no_bucket_color
    imgui.TextColored(head_color, 'HXIClam Enhanced')
    imgui.SetWindowFontScale(h.settings.font_scale[1])

    imgui.SetWindowFontScale(h.settings.bucket_weight_font_scale[1])
    imgui.TextColored(h.settings.colors.session_label_color, 'Bucket Weight:')
    imgui.SameLine()
    imgui.TextColored(bw_color, string.format('%d/%d', h.settings.bucket_weight, h.settings.bucket_capacity))
    imgui.SetWindowFontScale(h.settings.font_scale[1])

    imgui.TextColored(h.settings.colors.session_label_color, 'CLAM')
    imgui.SameLine()
    if ready then
        imgui.TextColored(h.settings.dig_timer_ready_color, txt)
        util.maybe_play_ready_tone(h)
    else
        imgui.TextColored(h.settings.colors.dig_timer_normal_color, txt)
    end

    if h.settings.clamming.bucket_subtract[1] then
        local profit = value - h.settings.clamming.bucket_cost[1]
        local pc = util.getProfitPercentageColor(h, h.settings.bucket_capacity, profit)
        imgui.TextColored(h.settings.colors.profit_label_color, 'Bucket Profit:')
        imgui.SameLine()
        imgui.TextColored(pc, util.format_int(profit) .. 'g')
    else
        imgui.TextColored(h.settings.colors.revenue_label_color, 'Bucket Revenue:')
        imgui.SameLine()
        imgui.TextColored(h.settings.colors.revenue_amount_color, util.format_int(value) .. 'g')
    end

    imgui.Separator()

    for k, v in pairs(h.settings.bucket) do
        local tot = (h.pricing[k] or 0) * v
        imgui.TextColored(h.settings.colors.bucket_item_name_color, display_name(k) .. ' ')
        if h.settings.show_item_quantities[1] then
            imgui.SameLine()
            imgui.TextColored(h.settings.colors.bucket_item_count_color, '[' .. util.format_int(v) .. ']')
        end
        if h.settings.show_item_values[1] then
            imgui.SameLine()
            local ww = imgui.GetWindowWidth()
            local tw = imgui.CalcTextSize('(' .. util.format_int(tot) .. ')')
            imgui.SetCursorPosX(ww - tw - 16)
            imgui.TextColored(h.settings.colors.bucket_item_value_color, '(' .. util.format_int(tot) .. ')')
        end
    end

    if h.settings.session_view > 0 then
        local total_worth = 0
        for k, v in pairs(h.settings.rewards) do
            if h.pricing[k] then total_worth = total_worth + (h.pricing[k] * v) end
        end
        imgui.Separator()
        imgui.SetWindowFontScale(h.settings.font_scale[1] + 0.10)
        imgui.TextColored(h.settings.colors.session_header_color, 'Session Stats:')
        imgui.SetWindowFontScale(h.settings.font_scale[1])

        imgui.TextColored(h.settings.colors.session_label_color, 'Buckets Cost:')
        imgui.SameLine()
        imgui.TextColored(h.settings.colors.session_value_color, tostring(h.settings.bucket_count * h.settings.clamming.bucket_cost[1]))

        imgui.TextColored(h.settings.colors.session_label_color, 'Items Dug:')
        imgui.SameLine()
        imgui.TextColored(h.settings.colors.session_value_color, tostring(h.settings.item_count))

        if h.settings.moon_display[1] then
            local moon = util.get_moon()
            imgui.TextColored(h.settings.colors.moon_display_color, 'Moon: ' .. moon.MoonPhase .. ' (' .. tostring(moon.MoonPhasePercent) .. '%)')
        end

        if h.settings.show_session_time[1] then
            local t = util.format_time_hms(elapsed)
            imgui.TextColored(h.settings.colors.session_time_color, 'Session Time:')
            imgui.SameLine()
            imgui.TextColored(h.settings.colors.session_time_color, t)
        end

        imgui.Separator()

        if h.settings.session_view > 1 then
            for k, v in pairs(h.settings.rewards) do
                local tot = (h.pricing[k] or 0) * v
                imgui.TextColored(h.settings.colors.bucket_item_name_color, display_name(k) .. ' ')
                if h.settings.show_item_quantities[1] then
                    imgui.SameLine()
                    imgui.TextColored(h.settings.colors.bucket_item_count_color, '[' .. util.format_int(v) .. ']')
                end
                if h.settings.show_item_values[1] then
                    imgui.SameLine()
                    local ww = imgui.GetWindowWidth()
                    local tw = imgui.CalcTextSize('(' .. util.format_int(tot) .. ')')
                    imgui.SetCursorPosX(ww - tw - 16)
                    imgui.TextColored(h.settings.colors.bucket_item_value_color, '(' .. util.format_int(tot) .. ')')
                end
            end
            imgui.Separator()
        end

        if h.settings.clamming.bucket_subtract[1] then
            total_worth = total_worth - (h.settings.bucket_count * h.settings.clamming.bucket_cost[1])
            if (ashita.time.clock()['s'] % 3) == 0 and elapsed > 0 then
                h.gil_per_hour = math.floor((total_worth / elapsed) * 3600)
            end
            imgui.TextColored(h.settings.colors.session_total_label_color, 'Total Profit:')
            imgui.SameLine()
            imgui.TextColored(h.settings.colors.session_total_value_color, util.format_int(total_worth) .. 'g')
            imgui.SameLine()
            imgui.TextColored(h.settings.colors.session_gph_color, '(' .. util.format_int(h.gil_per_hour) .. ' gph)')
        else
            if (ashita.time.clock()['s'] % 3) == 0 and elapsed > 0 then
                h.gil_per_hour = math.floor((total_worth / elapsed) * 3600)
            end
            imgui.TextColored(h.settings.colors.session_total_label_color, 'Total Revenue:')
            imgui.SameLine()
            imgui.TextColored(h.settings.colors.session_total_value_color, util.format_int(total_worth) .. 'g')
            imgui.SameLine()
            imgui.TextColored(h.settings.colors.session_gph_color, '(' .. util.format_int(h.gil_per_hour) .. ' gph)')
        end
    end
end

function display.render_detailed_display(h, apath)
    display.render_standard_display(h, apath)
    if not h.settings.analytics.enabled[1] then return end

    imgui.Separator()
    imgui.TextColored(h.settings.colors.session_header_color, 'Analytics:')

    local col = h.settings.colors.efficiency_good_color
    if h.current_efficiency < 50 then
        col = h.settings.colors.efficiency_poor_color
    elseif h.current_efficiency < 100 then
        col = h.settings.colors.efficiency_warning_color
    end

    imgui.TextColored(h.settings.colors.session_label_color, 'Efficiency:')
    imgui.SameLine()
    imgui.TextColored(col, string.format('%.1f items/hr', h.current_efficiency))

    imgui.TextColored(h.settings.colors.session_label_color, 'Trend:')
    imgui.SameLine()
    local tc = h.settings.colors.efficiency_good_color
    if h.efficiency_trend == 'declining' then tc = h.settings.colors.efficiency_poor_color
    elseif h.efficiency_trend == 'stable' then tc = h.settings.colors.efficiency_warning_color end
    imgui.TextColored(tc, string.upper(h.efficiency_trend or 'stable'))

    if h.settings.zone_tracking.enabled[1] then
        imgui.TextColored(h.settings.colors.zone_label_color, 'Current Zone:')
        imgui.SameLine()
        imgui.TextColored(h.settings.colors.zone_value_color, h.settings.zone_tracking.current_zone[1] or 'Unknown')
    end

    if #h.session_milestones_hit > 0 then
        local latest = h.session_milestones_hit[#h.session_milestones_hit]
        local sec = ashita.time.clock()['s'] - latest.time
        if sec < 300 then
            imgui.TextColored(h.settings.colors.milestone_color, 'Latest Milestone: ' .. util.format_int(latest.value) .. ' gil')
        end
    end
end

return display
