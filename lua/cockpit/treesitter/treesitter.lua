local geo = require("cockpit.geo")
local Point = geo.Point
local Range = geo.Range

local M = {}

local scope_query = "cockpit-scope"
local function tree_root()
    local buffer = vim.api.nvim_get_current_buf()
    local lang = vim.bo.ft

    -- Load the parser and the query.
    local parser = vim.treesitter.get_parser(buffer, lang)
    local tree = parser:parse()[1]
    return tree:root()
end

--- @class Scope
--- @field scope TSNode[]
--- @field range Range[]
--- @field buffer number
--- @field cursor Point
local Scope = {}
Scope.__index = Scope

--- @param cursor Point
--- @param buffer number
--- @return Scope
function Scope:new(cursor, buffer)
    return setmetatable({
        scope = {},
        range = {},
        buffer = buffer,
        cursor = cursor,
    }, self)
end

--- @return boolean
function Scope:has_scope()
    return self.range ~= nil
end

--- @param node TSNode
function Scope:push(node)
    local range = Range:from_ts_node(node, self.buffer)
    if not range:contains(self.cursor) then
        return
    end

    table.insert(self.range, range)
    table.insert(self.scope, node)
end

function Scope:finalize()
    assert(#self.range == #self.scope, "range scope mismatch")
    table.sort(self.range, function (a, b)
        return a:contains_range(b)
    end)
end

--- @return Scope
function M.get_smallest_scope()
    local lang = vim.bo.ft
    local root = tree_root()
    local buffer = vim.api.nvim_get_current_buf()
    local ok, query = pcall(vim.treesitter.query.get, lang, scope_query)

    assert(ok, "unable to load query for", lang, scope_query)
    assert(query ~= nil, "unable to find query", lang, scope_query)

    local cursor = Point:from_cursor()
    local scope = Scope:new(cursor, buffer)
    for _, match, _ in query:iter_matches(root, buffer, 0, -1, { all = true }) do
        for _, nodes in pairs(match) do
            for _, node in ipairs(nodes) do
                scope:push(node)
            end
        end
    end

    assert(scope:has_scope(), "get smallest scope failed.  it should never fail since scopeset should contain the \"program\" scope")
    scope:finalize()

    return scope
end

return M


