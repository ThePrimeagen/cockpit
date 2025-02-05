local M = {}

--- @class Lsp
--- @field config CockpitOptions
local Lsp = {}
Lsp.__index = {}

function Lsp:new(config)
    return setmetatable({
        config = config
    }, self)
end

--- @param node TSNode
function Lsp:ts_node_to_lsp_position(node)
    local start_row, start_col, _, _ = node:range() -- Treesitter node range
    return { line = start_row, character = start_col }
end

--- @param buffer number
---@param position number[]
---@param cb fun(): nil
function Lsp:get_lsp_definitions(buffer, position, cb)
    local params = vim.lsp.util.make_position_params()
    params.position = position

    --- @param result LspDefinitionResult[] | nil
    vim.lsp.buf_request(buffer, "textDocument/definition", params, function(_, result, ctx, _)
        if not result then
            return
        end
        local accepted_results = {}
        for _, res in ipairs(result) do
            if res.uri:match(self.config.
        end
    end)
end

return M
