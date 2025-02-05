local M = {}

local function fill(str, len)
    if #str >= len then
        return str
    end

    return string.rep(" ", len - #str) .. str
end

M.prefix = "<|fim_prefix|>"
M.suffix = "<|fim_suffix|>"
M.mid = "<|fim_middle|>"

function M.add_line_numbers(text)
    local lines = vim.split(text, "\n")
    local size = 2
    local count = math.floor(#lines / 10)
    while count > 0 do
        size = size + 1
        count = math.floor(count / 10)
    end

    for i = 1, #lines do
        lines[i] = fill(tostring(i) .. ".", size) .. lines[i]
    end
    return table.concat(lines, "\n")
end

--- @param text string
--- @param row number
--- @param col number
--- @return string
function M.prefix(text, row, col)
    local lines = vim.split(text, "\n")
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
    local lines = vim.split(text, "\n")
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
