local utils = require("cockpit.utils")
local Point = utils.Point
local Range = utils.Range

local M = {}

local query_group = "cockpit"
local function tree_root()
    local bufnr = vim.api.nvim_get_current_buf()
    local lang = vim.bo.ft

    -- Load the parser and the query.
    local parser = vim.treesitter.get_parser(bufnr, lang)
    local tree = parser:parse()[1]
    return tree:root()
end

---
function M.get_smallest_scope()
    local lang = vim.bo.ft
    local root = tree_root()
    local bufnr = vim.api.nvim_get_current_buf()
    local ok, query = pcall(vim.treesitter.query.get, lang, query_group)
    if not ok or not query then
        print("Failed to load query group:", query_group)
        return
    end
    local cursor = Point:from_cursor()
    for pattern, match, metadata in query:iter_matches(root, bufnr, 0, -1, { all = true }) do
        for id, nodes in pairs(match) do
            local name = query.captures[id]
            print("query id", id, "name", name)
            for _, node in ipairs(nodes) do
                local range = Range:from_ts_node(node, bufnr)
                print(vim.inspect(range:to_text()))
                local node_data = metadata[id] -- Node level metadata
                print("node_data", vim.inspect(node_data))
            end
        end
    end

end

function M.find_function_at_cursor()



    -- Iterate over all matches for our query.
    -- Your query is:
    --
    --   (function_declaration name: (identifier) @function.name)
    --
    -- That capture gives you the identifier node. To get the full function declaration,
    -- we take its parent.
end

return M


