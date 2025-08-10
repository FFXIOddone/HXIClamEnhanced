-- modules/achievements.lua - simple unlocks (ASCII)

local social = require('modules.social_discord')

local M = {}

local defs = {
    first_bucket   = { test=function(hx) return hx.settings.bucket_count >= 1 end,     text='Achievement: First bucket!' },
    hundred_items  = { test=function(hx) return hx.settings.item_count >= 100 end,     text='Achievement: 100 items!' },
    profit_10k     = { test=function(hx) return (require('modules.analytics').total_session_profit_now(hx) >= 10000) end, text='Achievement: 10,000 gil profit!' }
}

function M.try_unlock(hx)
    if not hx.settings.achievements.enabled[1] then return end
    for id, def in pairs(defs) do
        if not hx.settings.achievements.unlocked[id] and def.test(hx) then
            hx.settings.achievements.unlocked[id] = true
            if hx.settings.achievements.webhook[1] and hx.settings.discord.enabled[1] then
                social.enqueue_message(hx, '[' .. (hx.logs_name or 'Unknown') .. '] ' .. def.text)
            end
        end
    end
end

return M
