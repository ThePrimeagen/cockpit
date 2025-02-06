local logger = require("cockpit.logger.logger")
local M = {}

---@param start string
---@param curr string
---@param completion string
---@return string | nil
function M.partial_match(start, curr, completion)
    logger:debug("partial match", "current_line", curr, "start_line", start, "completion", completion)
    if #curr < #start then
        return nil
    end

    if start ~= curr:sub(1, #start) then
        return nil
    end

    local remaining = curr:sub(#start + 1)
    if #remaining == 0 then
        return completion
    end

    if #completion < #remaining then
        return nil
    end

    local sub_completion = completion:sub(1, #remaining)
    if remaining == sub_completion then
        return completion:sub(#remaining + 1)
    end
    return nil
end

return M
