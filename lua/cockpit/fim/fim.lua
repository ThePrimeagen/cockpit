local utils = require("cockpit.utils")

local M = {}

M.prefix = "<|fim-prefix|>"
M.suffix = "<|fim-suffix|>"
M.mid = "<|fim-middle|>"

--- @param text string
---@param row number
---@param col number
---@return string
function M.fim(text, row, col)
    local lines = utils.split(text, "\n")
    local prefix = {}
    for i = 1, row do
        table.insert(prefix, lines[i])
    end

    local suffix = {}
    for i = row, #text do
        table.insert(suffix, lines[i])
    end

    prefix[#prefix] = prefix[#prefix]:sub(1, col)
    suffix[1] = suffix[1]:sub(col + 1)

    return M.prefix .. table.concat(prefix, "\n") .. M.suffix .. table.concat(suffix, "\n") .. M.mid
end

return M
