-- modules/social_discord.lua
-- Discord webhook queue (ASCII-only, optional luasocket)

local social = { _q = {}, h = nil }

local function post_json(url, body)
    local ok_http, http = pcall(require, 'socket.http')
    local ok_ltn,  ltn12= pcall(require, 'ltn12')
    if not ok_http or not ok_ltn or not http or not ltn12 then return false end
    local resp = {}
    local _, code = http.request{
        method = 'POST',
        url = url,
        headers = { ['Content-Type']='application/json', ['Content-Length']=tostring(#body) },
        source = ltn12.source.string(body),
        sink   = ltn12.sink.table(resp),
    }
    return code == 200 or code == 204
end

function social.init(h) social.h = h end

local function enqueue(t, payload)
    t[#t + 1] = payload
    local limit = (social.h and social.h.settings.discord.queue_limit[1]) or 50
    if #t > limit then table.remove(t, 1) end
end

function social.enqueue_message(h, content)
    if not h.settings.discord.enabled[1] then return end
    local url = h.settings.discord.webhook_url[1]
    if not url or url == '' then return end
    local ok, json = pcall(function() return require('json').encode({ content = content }) end)
    if not ok then return end
    enqueue(social._q, { url = url, json = json })
end

function social.send_milestone(h, value)
    if not (h.settings.discord.enabled[1] and h.settings.discord.send_milestones[1]) then return end
    social.enqueue_message(h, ('Milestone reached: %s gil'):format(tostring(value)))
end

function social.send_summary(h, text)
    if not (h.settings.discord.enabled[1] and h.settings.discord.send_summaries[1]) then return end
    social.enqueue_message(h, text)
end

function social.process_queue(h)
    if not h.settings.discord.enabled[1] then return end
    local max_per_min = h.settings.discord.max_per_minute[1]
    local sent = 0
    local q = social._q
    while #q > 0 and sent < max_per_min do
        local item = table.remove(q, 1)
        if item and item.url and item.json then pcall(post_json, item.url, item.json) end
        sent = sent + 1
    end
end

return social
