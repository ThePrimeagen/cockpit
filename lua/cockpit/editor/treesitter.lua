local geo = require("cockpit.geo")
local Point = geo.Point
local Range = geo.Range

local M = {}

local scope_query = "cockpit-scope"
local imports_query = "cockpit-imports"

local function tree_root()
    local buffer = vim.api.nvim_get_current_buf()
    local lang = vim.bo.ft

    -- Load the parser and the query.
    local ok, parser = pcall(vim.treesitter.get_parser, buffer, lang)
    if not ok then
        return nil
    end

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
    return #self.range > 0
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
    table.sort(self.range, function(a, b)
        return a:contains_range(b)
    end)
end

--- if you want cursor just use Point:from_cursor()
--- @param cursor Point
--- @return Scope | nil
function M.scopes(cursor)
    local lang = vim.bo.ft
    local root = tree_root()
    if not root then
        -- consider logging
        return nil
    end

    local buffer = vim.api.nvim_get_current_buf()
    local ok, query = pcall(vim.treesitter.query.get, lang, scope_query)

    if not ok or query == nil then
        return nil
    end

    local scope = Scope:new(cursor, buffer)
    scope:push(root)

    for _, match, _ in query:iter_matches(root, buffer, 0, -1, { all = true }) do
        for _, nodes in pairs(match) do
            for _, node in ipairs(nodes) do
                scope:push(node)
            end
        end
    end

    assert(
        scope:has_scope(),
        'get smallest scope failed.  it should never fail since scopeset should contain the "program" scope'
    )
    scope:finalize()

    return scope
end

--- @return TSNode[]
function M.imports()
    local root = tree_root()
    if not root then
        return {}
    end

    local buffer = vim.api.nvim_get_current_buf()
    local ok, query = pcall(vim.treesitter.query.get, vim.bo.ft, imports_query)

    if not ok or query == nil then
        return {}
    end

    local imports = {}
    for _, match, _ in query:iter_matches(root, buffer, 0, -1, { all = true }) do
        for id, nodes in pairs(match) do
            local name = query.captures[id]
            if name == "import.name" then
                for _, node in ipairs(nodes) do
                    table.insert(imports, node)
                end
            end
        end
    end

    return imports
end

return M
