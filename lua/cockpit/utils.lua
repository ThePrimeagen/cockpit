local M = {}

--- @param str string
--- @param partial string
--- @return boolean
function M.partial_match(str, partial)
    -- TODO: this doesn't work with utf8 maybe...
    for i = 1, #str do
        local curr = str:byte(i, i)
        local first = partial:byte(1, 1)

        local found = true
        if curr == first then
            for j = 1, #partial - 1 do
                if not found then
                    break
                end

                if i + j > #str then
                    return true
                end

                local expected = str:byte(i + j, i + j)
                local received = partial:byte(j + 1, j + 1)
                found = expected == received
            end

            if found then
                return true
            end
        end
    end

    return false
end

M.partial_match("foofofofofofofofofof", "bar")

return M
