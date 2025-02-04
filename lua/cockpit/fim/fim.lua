local utils = require("cockpit.utils")

local M = {}

M.prefix = "<fim-prefix>"
M.suffix = "<fim-suffix>"
M.mid = "<fim-middle>"

--- @param text string
---@param cursor Point
---@return string
function M.fim(text, cursor)
    local lines = utils.split(text, "\n")
    local prefix = {}
    for i = 1, cursor.row do
        table.insert(prefix, lines[i])
    end

    local suffix = {}
    for i = cursor.row, #text do
        table.insert(suffix, lines[i])
    end

    prefix[#prefix] = prefix[#prefix]:sub(1, cursor.col)
    suffix[1] = suffix[1]:sub(cursor.col + 1)

    return M.prefix .. table.concat(prefix, "\n") .. M.suffix .. table.concat(suffix, "\n") .. M.mid
end

return M
