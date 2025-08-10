-- modules/cloud.lua
-- Cloud copy + mobile companion JSON (ASCII-only)

local cloud = {}

local function safe_copy(src, dst)
    local fi = io.open(src, 'rb'); if not fi then return false end
    local data = fi:read('*a'); fi:close()
    local di = io.open(dst, 'wb'); if not di then return false end
    di:write(data); di:close()
    return true
end

function cloud.copy_to_cloud_if_enabled(h, src_path)
    if not h or not h.settings or not h.settings.cloud or not h.settings.cloud.enabled[1] then return end
    local target_dir = h.settings.cloud.path[1]
    if not target_dir or #target_dir == 0 then return end
    pcall(function()
        local sep = (package.config:sub(1,1) == '\\') and '\\' or '/'
        local fname = src_path:match('([^\\/]+)$')
        local dst = target_dir .. sep .. fname
        safe_copy(src_path, dst)
    end)
end

function cloud.write_mobile_companion_json(h)
    if not h or not h.settings or not h.settings.mobile or not h.settings.mobile.enabled[1] then return end
    local path = h.settings.mobile.out_path[1]; if not path or #path == 0 then return end
    local obj = {
        bucket_count = h.settings.bucket_count,
        item_count = h.settings.item_count,
        rewards = h.settings.rewards
    }
    local ok, json = pcall(function() return require('json').encode(obj) end)
    if not ok then return end
    local f = io.open(path, 'wb'); if not f then return end
    f:write(json); f:close()
end

return cloud
