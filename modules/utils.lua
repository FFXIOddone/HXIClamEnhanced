local M = {}
-- Index Management Functions
function M.set_index_value(list, name, value)
    name = M.normalize_item(name)
    local found = false
    for i, s in ipairs(list) do
        local n = s:match('^(.-):')
        if n and M.normalize_item(n) == name then
            list[i] = n .. ':' .. tostring(tonumber(value) or 0)
            found = true
            break
        end
    end
    if not found then
        table.insert(list, name .. ':' .. tostring(tonumber(value) or 0))
    end
end

function M.remove_index_entry(list, name)
    name = M.normalize_item(name)
    for i = #list, 1, -1 do
        local n = list[i]:match('^(.-):')
        if n and M.normalize_item(n) == name then
            table.remove(list, i)
        end
    end
end

function M.parse_pairs(list)
    local out = {}
    if not list then return out end
    for _, s in ipairs(list) do
        local name, val = s:match('^(.-):(%-?%d+)$')
        if name and val then out[M.normalize_item(name)] = tonumber(val) end
    end
    return out
end

function M.build_keys_union(H_)
    local set, keys = {}, {}
    if not H_ then return keys end
    for k in pairs(H_.pricing or {}) do set[k] = true end
    for k in pairs(H_.weights or {}) do set[k] = true end
    for k in pairs(require('modules.constants').ItemDisplayNames or {}) do set[k] = true end
    for k in pairs(set) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

function M.update_pricing(H)
    H.pricing = M.parse_pairs(H.settings and H.settings.item_index or {})
end

function M.update_weights(H)
    H.weights = M.parse_pairs(H.settings and H.settings.item_weight_index or {})
end
-- utils.lua
-- Utility functions for hxiclam

local M = {}

function M.normalize_item(name)
    return (name or ''):lower():gsub('%s+', ' ')
end

function M.format_int(n)
    if n == nil then return '0' end
    if type(n) ~= 'number' then return tostring(n or 0) end
    local s, neg = tostring(math.floor(n)), n < 0 and '-' or ''
    s = s:gsub('^-', '')
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return neg .. out
end

function M.format_time_hms(sec)
    sec = math.max(0, math.floor(sec or 0))
    if not sec or type(sec) ~= 'number' then return '00:00:00' end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    return string.format('%02d:%02d:%02d', h, m, s)
end

function M.deepcopy(tbl)
    if tbl == nil then return nil end
    if type(tbl) ~= 'table' then return tbl end
    local t = {}
    for k, v in pairs(tbl) do t[k] = M.deepcopy(v) end
    return t
end

function M.is_dense_array(t)
    if t == nil or type(t) ~= 'table' then return false end
    local n = #t
    for k, _ in pairs(t) do
        if type(k) ~= 'number' or k < 1 or k > n or k % 1 ~= 0 then
            return false
        end
    end
    return true
end

-- Additional utility functions from hxiclam.lua
function M.ensure_color(colors, key, default)
    if not colors then return default end
    if type(colors[key]) ~= 'table' or #colors[key] < 4 then
        colors[key] = { default[1], default[2], default[3], default[4] }
    end
    return colors[key]
end

function M.json_sanitize(v)
    if v == nil then return nil end
    local tv = type(v)
    if tv == 'nil' then return nil end
    if tv == 'number' or tv == 'string' or tv == 'boolean' then return v end
    if tv == 'function' or tv == 'userdata' or tv == 'thread' then return tostring(v) end
    if tv ~= 'table' then return v end

    local out
    if M.is_dense_array(v) then
        out = {}
        for i = 1, #v do out[i] = M.json_sanitize(v[i]) end
        return out
    end

    out = {}
    for k, val in pairs(v) do
        out[tostring(k)] = M.json_sanitize(val)
    end
    return out
end

return M
