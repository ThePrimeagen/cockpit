local utils = require("cockpit.utils")

local M = {}

M.prefix = "<|fim_prefix|>"
M.suffix = "<|fim_suffix|>"
M.mid = "<|fim_middle|>"

--- @param text string
--- @param row number
--- @param col number
--- @return string
function M.prefix(text, row, col)
    local lines = utils.split(text, "\n")
    local prefix = {}
    for i = 1, row do
        table.insert(prefix, lines[i])
    end

    prefix[#prefix] = prefix[#prefix]:sub(1, col)
    return table.concat(prefix, "\n")
end

--- @param text string
--- @param row number
--- @param col number
--- @return string
function M.suffix(text, row, col)
    local lines = utils.split(text, "\n")
    local suffix = {}
    for i = row, #text do
        table.insert(suffix, lines[i])
    end

    suffix[1] = suffix[1]:sub(col + 1)
    return table.concat(suffix, "\n")
end

--- @param text string
--- @param row number
--- @param col number
--- @return string
function M.fim(text, row, col)
    local prefix = M.prefix(text, row, col)
    local suffix = M.suffix(text, row, col)

    return M.prefix .. prefix .. M.suffix .. suffix .. M.mid
end

return M
