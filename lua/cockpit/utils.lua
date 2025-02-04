local M = {}

--- @param str string
--- @param sep string
--- @return table
function M.split(str, sep)
    if sep == nil then
        sep = " "
    end
    return vim.split(str, sep)
end

function M.trim(s)
    return s:match("^%s*(.-)%s*$")
end

--- @param arr any[]
--- @param start number
--- @param stop number | nil
function M.slice(arr, start, stop)
    if stop == nil then
        stop = #arr
    end

    assert(start <= stop, "dude, wtf you slapped a fish")

    local out = {}
    for i = start, stop do
        table.insert(out, arr[i])
    end

    return out
end


return M
