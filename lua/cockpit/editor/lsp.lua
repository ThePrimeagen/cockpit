local logger = require("cockpit.logger.logger")

--- @param node TSNode
local function ts_node_to_lsp_position(node)
    local start_row, start_col, _, _ = node:range() -- Treesitter node range
    return { line = start_row, character = start_col }
end

--- @param buffer number
--- @param position number[]
--- @param cb fun(res: LspDefinitionResult[] | nil): nil
local function get_lsp_definitions(buffer, position, cb)
    local params = vim.lsp.util.make_position_params()
    params.position = position

    --- @param result LspDefinitionResult[] | nil
    vim.lsp.buf_request(
        buffer,
        "textDocument/definition",
        params,
        function(_, result, ctx, _)
            cb(result)
        end
    )
end

--- @class Lsp
--- @field config CockpitOptions
local Lsp = {}
Lsp.__index = Lsp

function Lsp:new(config)
    return setmetatable({
        config = config,
    }, self)
end

--- @param buffer number
--- @param node TSNode[]
--- @param cb fun(res: LspDefinitionResult | nil): nil
function Lsp:get_ts_node_definition(buffer, node, cb)
    local range = ts_node_to_lsp_position(node)
    get_lsp_definitions(buffer, range, cb)
end

--- @param resultsList LspDefinitionResult[][]
--- @param buffer number
--- @return LspDefinitionResult[]
function Lsp:_filter_flatten(resultsList, buffer)
    local ft = vim.bo[buffer].ft
    local out = {}
    local filters = self.config.language_import_filter[ft]
    logger:debug("filter flatten", "filters", filters, "ft", ft)
    for _, results in ipairs(resultsList) do
        for _, res in ipairs(results) do
            local found = true
            for _, filter in ipairs(filters) do
                logger:debug(
                    "filtering lsp definitions",
                    "filter",
                    filter,
                    "uri",
                    res.uri
                )
                if string.find(res.uri, filter) then
                    found = false
                    break
                end
            end

            if res ~= false and found then
                logger:debug("adding resource", "uri", res.uri)
                table.insert(out, res)
            end
        end
    end
    return out
end

--- @param buffer number
--- @param nodes TSNode[]
--- @param cb fun(res: LspDefinitionResult[]): nil
function Lsp:batch_get_ts_node_definitions(buffer, nodes, cb)
    if #nodes == 0 then
        return cb({})
    end

    local definitions = {}
    for index, node in ipairs(nodes) do
        self:get_ts_node_definition(buffer, node, function(def)
            if def == nil or #def == 0 then
                def = {}
            end

            definitions[index] = def
            if #definitions == #nodes then
                cb(self:_filter_flatten(definitions, buffer))
            end
        end)
    end
end

return {
    Lsp = Lsp,
}
