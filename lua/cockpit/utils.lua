local logger = require("cockpit.logger.logger")
local M = {}

--- @param str string
--- @param partial string
--- @return boolean, number
function M.partial_match(str, partial)
    -- TODO: this doesn't work with utf8 maybe...
    logger:info("partial_match", "str-len", #str, "str", str, "partial-len", #partial, "partial", partial)
    for i = 1, #str do
        local curr = str:byte(i, i)
        local first = partial:byte(1, 1)

        local found = true
        if curr == first then
            for j = 1, #partial - 1 do
                logger:info("partial_match inner#match", "i", i, "j", j)
                if not found then
                    break
                end

                if i + j > #str then
                    logger:info("partial_match found", "returning", j)
                    return true, j
                end

                local expected = str:byte(i + j, i + j)
                local received = partial:byte(j + 1, j + 1)
                found = expected == received
            end

            if found then
                return true, #partial
            end
        end
    end

    return false, 1
end

return M
