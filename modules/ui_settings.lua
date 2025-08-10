-- modules/ui_settings.lua (ASCII only)
local ok_imgui, imgui_mod = pcall(require, 'imgui'); local imgui = (ok_imgui and imgui_mod) or rawget(_G, 'imgui')
if not imgui then return {} end

local util = rawget(_G, '__hxiclam_util') or dofile(((rawget(_G,'addon') and addon.path) or (rawget(_G,'__hxiclam_basepath') or '')) .. 'modules\\util.lua'); _G.__hxiclam_util = util
local analytics = rawget(_G, '__hxiclam_analytics') or dofile(((rawget(_G,'addon') and addon.path) or (rawget(_G,'__hxiclam_basepath') or '')) .. 'modules\\analytics.lua'); _G.__hxiclam_analytics = analytics
local social = rawget(_G, '__hxiclam_social') or dofile(((rawget(_G,'addon') and addon.path) or (rawget(_G,'__hxiclam_basepath') or '')) .. 'modules\\social_discord.lua'); _G.__hxiclam_social = social

-- Safe constants
local function FG(k) return rawget(_G, k) or 0 end
local ImGuiWindowFlags_AlwaysAutoResize = FG('ImGuiWindowFlags_AlwaysAutoResize')
local ImGuiTabBarFlags_NoCloseWithMiddleMouseButton = FG('ImGuiTabBarFlags_NoCloseWithMiddleMouseButton')
local ImGuiCond_Always = FG('ImGuiCond_Always')

local ui = {}
local MAXH = 34

local function BeginChild(id, lines)
    return imgui.BeginChild(id, {0, imgui.GetTextLineHeightWithSpacing() * lines}, true, ImGuiWindowFlags_AlwaysAutoResize)
end

local function ColorEdit(label, col, help)
    if type(col) ~= 'table' or #col < 4 then col = T{0.5,0.5,0.5,1.0} end
    local changed = imgui.ColorEdit4(label, col)
    util.help(help)
    return changed
end

local function PercentSlider(label, t, help)
    local v = T{ (t[1] or 0) }
    local changed = imgui.SliderFloat(label, v, 0.0, 1.0, '%.2f')
    if changed then t[1] = v[1] end
    util.help(help)
end

local function InputPath(label, t, help)
    local ok = pcall(function() imgui.InputText(label, t, 260) end)
    if not ok then imgui.Text(label .. ': (use config file or commands)') end
    util.help(help)
end

function ui.render_editor(h, settings, apath)
    if not h.editor.is_open[1] then return end
    local pushed = util.push_imgui_style(h.settings.colors)

    imgui.SetNextWindowSize({0,0}, ImGuiCond_Always)
    if imgui.Begin('HXIClam Enhanced - Settings##Config', h.editor.is_open, ImGuiWindowFlags_AlwaysAutoResize) then

        if imgui.Button('Save Settings') then settings.save() end
        util.help('Save all current settings to disk.')
        imgui.SameLine()
        if imgui.Button('Reload') then settings.reload() end
        util.help('Reload settings from disk.')
        imgui.SameLine()
        if imgui.Button('Reset To Defaults') then settings.reset() end
        util.help('Reset settings to defaults (you will not lose logs).')
        imgui.SameLine()
        if imgui.Button('Export Now (CSV)') then
            pcall(function() h._ui_export_csv = true end)
        end
        util.help('Quickly export the current session as CSV. Uses /hxiclam export.')

        imgui.Separator()

        if imgui.BeginTabBar('##hxiclam_tabbar', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) then

            -- General
            if imgui.BeginTabItem('General', nil) then
                imgui.Text('General Settings')
                BeginChild('settings_general', MAXH)

                imgui.Checkbox('Visible', h.settings.visible); util.help('Toggle visibility of the main display window.')
                imgui.Checkbox('Moon Display', h.settings.moon_display); util.help('Show current moon phase and percent.')
                imgui.SliderFloat('Opacity', h.settings.opacity, 0.125, 1.0, '%.3f'); util.help('Window background opacity (0.125 to 1.000).')
                imgui.SliderFloat('Font Scale', h.settings.font_scale, 0.10, 2.0, '%.3f'); util.help('Scale all display fonts.')
                imgui.InputInt('Display Timeout (sec)', h.settings.display_timeout); util.help('Seconds to keep the window visible after last event.')
                local pos = {h.settings.x[1], h.settings.y[1]}
                if imgui.InputInt2('Position', pos) then h.settings.x[1]=pos[1]; h.settings.y[1]=pos[2] end
                util.help('On-screen position of the window.')

                if imgui.RadioButton('Minimal Display', h.settings.display_mode[1] == 1) then h.settings.display_mode[1] = 1 end
                util.help('Only weight and timer.')
                imgui.SameLine()
                if imgui.RadioButton('Standard Display', h.settings.display_mode[1] == 2) then h.settings.display_mode[1] = 2 end
                util.help('All common information.')
                imgui.SameLine()
                if imgui.RadioButton('Detailed Display', h.settings.display_mode[1] == 3) then h.settings.display_mode[1] = 3 end
                util.help('Standard plus analytics.')
                imgui.SameLine()
                if imgui.RadioButton('Overlay', h.settings.display_mode[1] == 4) then h.settings.display_mode[1] = 4 end
                util.help('Transparent overlay mode.')

                imgui.Checkbox('Enable Sound', h.settings.enable_tone); util.help('Play a sound when the timer is ready or events happen.')
                imgui.SameLine()
                if imgui.BeginCombo('Tone', h.settings.tone) then
                    for i, v in pairs(h.settings.available_tones) do
                        local sel = (i == h.settings.tone_selected_idx)
                        if imgui.Selectable(v, sel) then h.settings.tone_selected_idx = i; h.settings.tone = v end
                        if sel then imgui.SetItemDefaultFocus() end
                    end
                    imgui.EndCombo()
                end
                util.help('Select the sound file from the "tones" folder.')
                imgui.SameLine()
                if imgui.Button('Test Tone') then pcall(function() ashita.misc.play_sound(("%stones/%s"):format(apath or '', h.settings.tone)) end) end
                util.help('Play the selected tone once.')

                imgui.Checkbox('Show Session Time', h.settings.show_session_time); util.help('Show total elapsed session time.')
                imgui.Checkbox('Show Item Quantities', h.settings.show_item_quantities); util.help('Show [x] quantity next to each item name.')
                imgui.Checkbox('Show Item Values', h.settings.show_item_values); util.help('Show (value) next to each item or reward entry.')
                imgui.Checkbox('Reset Rewards On Load', h.settings.reset_on_load); util.help('Clear session and bucket whenever the addon loads.')
                imgui.Checkbox('Enable Logging', h.settings.enable_logging); util.help('Write drops and turn-ins to text log files.')

                imgui.Separator()
                imgui.Text('Auto Backup')
                imgui.Checkbox('Enable Auto Backup', h.settings.auto_backup_enabled); util.help('Automatically save backups in the background.')
                if h.settings.auto_backup_enabled[1] then
                    imgui.InputInt('Backup Interval (sec)', h.settings.auto_backup_interval); util.help('Seconds between automatic backups.')
                end

                imgui.Separator()
                imgui.Text('Export')
                if imgui.RadioButton('CSV', h.settings.export_format[1] == 1) then h.settings.export_format[1] = 1 end
                util.help('Export session data as CSV for spreadsheets.')
                imgui.SameLine()
                if imgui.RadioButton('JSON', h.settings.export_format[1] == 2) then h.settings.export_format[1] = 2 end
                util.help('Export session data as JSON.')

                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Clamming
            if imgui.BeginTabItem('Clamming', nil) then
                imgui.Text('Clamming Parameters')
                BeginChild('clamming_config', MAXH)

                imgui.InputInt('Bucket Cost (gil)', h.settings.clamming.bucket_cost); util.help('Cost to purchase a clamming kit.')
                imgui.Checkbox('Subtract Bucket Cost From Profit', h.settings.clamming.bucket_subtract); util.help('If enabled, total profit subtracts bucket costs.')

                imgui.Separator()
                imgui.Text('Stop Values By Capacity')
                local caps = {50,100,150,200}
                for _, cap in ipairs(caps) do
                    local sv = h.settings.clamming.stop_values[cap] or T{0}
                    if imgui.InputInt(('Stop Value %d'):format(cap), sv) then h.settings.clamming.stop_values[cap] = sv end
                    util.help('Target profit to stop at for capacity ' .. tostring(cap) .. '.')
                    local su = h.settings.clamming.stop_weights_under_value[cap] or T{0}
                    if imgui.InputInt(('Stop Weight Under %d'):format(cap), su) then h.settings.clamming.stop_weights_under_value[cap] = su end
                    util.help('When under stop value, stop if remaining weight <= this.')
                    local so = h.settings.clamming.stop_weights_over_value[cap] or T{0}
                    if imgui.InputInt(('Stop Weight Over %d'):format(cap), so) then h.settings.clamming.stop_weights_over_value[cap] = so end
                    util.help('When over stop value, stop if remaining weight <= this.')
                end

                imgui.Separator()
                imgui.Checkbox('Advanced Stop Color Logic', h.settings.clamming.color_logic_advanced); util.help('Use percentage-based color logic against stop value.')

                imgui.Separator()
                imgui.Text('Bucket Weight Warning Colors')
                ColorEdit('Warn Color', h.settings.bucket_weight_warn_color, 'Color when remaining weight is getting low.')
                ColorEdit('Critical Color', h.settings.bucket_weight_crit_color, 'Color when remaining weight is critical.')
                imgui.InputInt('Warn Threshold', h.settings.bucket_weight_warn_threshold); util.help('Remaining weight at which warn color is used.')
                imgui.InputInt('Critical Threshold', h.settings.bucket_weight_crit_threshold); util.help('Remaining weight at which critical color is used.')

                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Smart
            if imgui.BeginTabItem('Smart', nil) then
                imgui.Text('Smart Turn-In Suggestions')
                BeginChild('smart_config', MAXH/2)
                imgui.Checkbox('Enable Smart Turn-Ins', h.settings.smart.turnin_enabled); util.help('Suggest turning in when risk vs. value favors a turn-in.')
                PercentSlider('Aggressiveness', h.settings.smart.turnin_aggressiveness, '0.00 conservative to 1.00 very aggressive.')
                imgui.Checkbox('Show Banner', h.settings.smart.show_banner); util.help('Show an on-screen suggestion banner.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Streaks
            if imgui.BeginTabItem('Streaks', nil) then
                imgui.Text('Streak Tracking and Celebration')
                BeginChild('streaks_config', MAXH/2)
                imgui.Checkbox('Enable Streaks', h.settings.streaks.enabled); util.help('Track consecutive successful buckets.')
                imgui.InputInt('Celebrate Every N Buckets', h.settings.streaks.celebrate_every); util.help('Trigger celebration every N buckets.')
                imgui.Checkbox('Webhook On Celebrate', h.settings.streaks.webhook); util.help('Send a Discord message when a celebration happens.')
                imgui.Checkbox('Sound On Celebrate', h.settings.streaks.sound_enabled); util.help('Play sound on celebration.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Dynamic milestones
            if imgui.BeginTabItem('Milestones', nil) then
                imgui.Text('Dynamic Milestones')
                BeginChild('miles_config', MAXH/2)
                imgui.Checkbox('Enable Dynamic Milestones', h.settings.milestones_dynamic.enabled); util.help('Automatically scale milestones as profit grows.')
                PercentSlider('Scale Factor', h.settings.milestones_dynamic.scale, 'Multiplier applied to next milestone.')
                imgui.InputInt('Minimum Gap (gil)', h.settings.milestones_dynamic.min_gap); util.help('Minimum difference between milestones.')
                imgui.Separator()
                imgui.Text('Static Milestones')
                local tmp = {}
                for i, m in ipairs(h.settings.notifications.profit_milestones) do tmp[i] = { m } end
                for i = 1, #tmp do
                    imgui.PushID('ms'..i)
                    if imgui.InputInt(('Milestone %d'):format(i), tmp[i]) then
                        h.settings.notifications.profit_milestones[i] = tmp[i][1]
                    end
                    util.help('Edit a static milestone value in gil.')
                    imgui.PopID()
                end
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Summary
            if imgui.BeginTabItem('Summary', nil) then
                imgui.Text('One-Click Session Summary')
                BeginChild('summary_config', MAXH/2)
                imgui.Checkbox('One-Click Enabled', h.settings.summary.one_click_enabled); util.help('Enable quick summary generation.')
                imgui.Checkbox('Include Items', h.settings.summary.include_items); util.help('Include item breakdown.')
                imgui.Checkbox('Include Zones', h.settings.summary.include_zones); util.help('Include per-zone stats.')
                imgui.Checkbox('Send To Discord', h.settings.summary.send_to_discord); util.help('Post the summary to Discord if webhook is configured.')
                imgui.Checkbox('Save As File', h.settings.summary.save_as_file); util.help('Write summary to file in exports folder.')
                if imgui.Button('Generate Summary Now') then pcall(function() analytics.one_click_summary(h) end) end
                util.help('Create and optionally send the summary immediately.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Discord / Social
            if imgui.BeginTabItem('Discord', nil) then
                imgui.Text('Discord Webhooks')
                BeginChild('discord_config', MAXH/2)
                imgui.Checkbox('Enable Discord', h.settings.discord.enabled); util.help('Enable Discord webhook integration.')
                pcall(function() imgui.InputText('Webhook URL', h.settings.discord.webhook_url, 512) end)
                util.help('Paste your Discord webhook URL here. You can also use: /hxiclam discord url <webhook>')
                imgui.InputInt('Queue Limit', h.settings.discord.queue_limit); util.help('Max queued messages; older messages are dropped.')
                imgui.InputInt('Max Per Minute', h.settings.discord.max_per_minute); util.help('Rate limit to avoid spam.')
                imgui.Checkbox('Send Milestones', h.settings.discord.send_milestones); util.help('Send messages when milestones are reached.')
                imgui.Checkbox('Send Streaks', h.settings.discord.send_streaks); util.help('Send messages for celebrations.')
                imgui.Checkbox('Send Summaries', h.settings.discord.send_summaries); util.help('Send one-click summaries.')
                if imgui.Button('Send Test Message') then
                    pcall(function() social.enqueue_message(h, 'HXIClam: webhook test.') end)
                end
                util.help('Queue a simple test message to verify the webhook.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Achievements
            if imgui.BeginTabItem('Achievements', nil) then
                imgui.Text('Achievements')
                BeginChild('ach_config', MAXH/2)
                imgui.Checkbox('Enable Achievements', h.settings.achievements.enabled); util.help('Track and unlock achievements.')
                imgui.Text('Unlocked: ' .. tostring(#h.settings.achievements.unlocked)); util.help('Number of unlocked achievements this session.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Heatmap
            if imgui.BeginTabItem('Heatmap', nil) then
                imgui.Text('Efficiency Heat Map')
                BeginChild('heat_config', MAXH/2)
                imgui.Checkbox('Enable Heatmap', h.settings.heatmap.enabled); util.help('Aggregate performance by day-of-week and hour.')
                imgui.Text('The heatmap will be produced in summary exports.'); util.help('Rendering in-ui is not implemented to keep overhead low.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Sound Themes
            if imgui.BeginTabItem('Sound Themes', nil) then
                imgui.Text('Contextual Sound Themes')
                BeginChild('sound_config', MAXH/2)
                imgui.Checkbox('Enable Sound Themes', h.settings.sound_themes.enabled); util.help('Select themed sound sets for events.')
                if imgui.BeginCombo('Theme', h.settings.sound_themes.theme[1]) then
                    for name,_ in pairs(h.settings.sound_themes.files) do
                        local sel = (name == h.settings.sound_themes.theme[1])
                        if imgui.Selectable(name, sel) then h.settings.sound_themes.theme[1] = name end
                        if sel then imgui.SetItemDefaultFocus() end
                    end
                    imgui.EndCombo()
                end
                util.help('Choose which set of sound files to use for events.')
                imgui.Text('Files map is configurable in settings file.'); util.help('Edit tones under /addons/hxiclam/tones.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Auto Screenshot
            if imgui.BeginTabItem('Screenshot', nil) then
                imgui.Text('Auto Screenshot On Exceptional Events')
                BeginChild('screen_config', MAXH/2)
                imgui.Checkbox('Enable Auto Screenshot', h.settings.autoscreenshot.enabled); util.help('Capture a screenshot for highlight moments.')
                imgui.Checkbox('On Milestone', h.settings.autoscreenshot.on_milestone); util.help('Screenshot when a milestone is hit.')
                imgui.Checkbox('On Rare Item', h.settings.autoscreenshot.on_rare_item); util.help('Screenshot when a rare item is found.')
                imgui.Checkbox('On Best Streak', h.settings.autoscreenshot.on_best_streak); util.help('Screenshot when you beat your best streak.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- ML Advanced
            if imgui.BeginTabItem('ML', nil) then
                imgui.Text('Advanced ML Pattern Recognition')
                BeginChild('ml_config', MAXH/2)
                imgui.Checkbox('Enable ML', h.settings.ml_advanced.enabled); util.help('Experimental: pattern recognition for digging cadence.')
                imgui.Text('Patterns tracked: ' .. tostring(#(h.settings.ml_advanced.patterns or {}))); util.help('Count of learned patterns.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Leaderboards
            if imgui.BeginTabItem('Leaderboards', nil) then
                imgui.Text('Social Leaderboards')
                BeginChild('lb_config', MAXH/2)
                imgui.Checkbox('Enable Leaderboards', h.settings.leaderboard.enabled); util.help('Share stats to a leaderboard (future).')
                pcall(function() imgui.InputText('Display Name', h.settings.leaderboard.display_name, 64) end); util.help('Public name to show.')
                if imgui.BeginCombo('Privacy', h.settings.leaderboard.privacy[1]) then
                    local opts = {'private','friends','public'}
                    for _, o in ipairs(opts) do
                        local sel = (o == h.settings.leaderboard.privacy[1])
                        if imgui.Selectable(o, sel) then h.settings.leaderboard.privacy[1] = o end
                        if sel then imgui.SetItemDefaultFocus() end
                    end
                    imgui.EndCombo()
                end
                util.help('Who can see your shared stats.')
                imgui.Checkbox('Share To Discord', h.settings.leaderboard.share_discord); util.help('Also post leaderboard updates to Discord.')
                imgui.EndChild()
                imgui.EndTabItem()
            end

            -- Cloud / Mobile
            if imgui.BeginTabItem('Cloud & Mobile', nil) then
                imgui.Text('Cloud Backup')
                BeginChild('cloud_config', MAXH/2)
                imgui.Checkbox('Enable Cloud Copy', h.settings.cloud.enabled); util.help('Copy backups/exports to another folder.')
                InputPath('Cloud Folder', h.settings.cloud.path, 'Target folder to copy files to.')
                imgui.EndChild()

                imgui.Separator()
                imgui.Text('Mobile Companion')
                BeginChild('mobile_config', MAXH/2)
                imgui.Checkbox('Enable Mobile JSON', h.settings.mobile.enabled); util.help('Write a small JSON for companion apps.')
                InputPath('Mobile JSON Path', h.settings.mobile.out_path, 'Full file path to write (e.g. C:\\temp\\hxiclam.json).')
                imgui.EndChild()

                imgui.EndTabItem()
            end

            -- Colors (extensive) — keep as in util.push_imgui_style keys
            if imgui.BeginTabItem('Colors', nil) then
                imgui.Text('Global Theme Colors')
                BeginChild('colors_theme', MAXH)
                local C = h.settings.colors
                ColorEdit('Window BG',              util.ensure_color(C,'window_bg_color',{0.06,0.06,0.07,0.94}), 'Main window background.')
                ColorEdit('Child BG',               util.ensure_color(C,'child_bg_color',{0.06,0.06,0.07,0.60}), 'Child panels background.')
                ColorEdit('Popup BG',               util.ensure_color(C,'popup_bg_color',{0.08,0.08,0.09,0.94}), 'Popup background.')
                ColorEdit('Border',                 util.ensure_color(C,'border_color',{0.20,0.20,0.20,0.60}), 'Border color.')
                ColorEdit('Border Shadow',          util.ensure_color(C,'border_shadow_color',{0,0,0,0}), 'Border shadow.')
                ColorEdit('Text',                   util.ensure_color(C,'text_color',{0.86,0.86,0.86,1.00}), 'Default text.')
                ColorEdit('Text Disabled',          util.ensure_color(C,'text_disabled_color',{0.50,0.50,0.50,1.00}), 'Disabled text.')
                -- (…continue exposing other colors as needed…)
                imgui.EndChild()
                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
    end

    imgui.End()
    util.pop_imgui_style(pushed)
end

return ui
