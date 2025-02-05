
--- @class CompleteLine
--- @field line string
--- @field completion string
local CompleteLine = {}
CompleteLine.__index = {}

--- @return CompleteLine
function CompleteLine:new()
    return setmetatable({
        line = "",
        completion = "",
    }, self)
end

--- @return boolean
function CompleteLine:valid()
    if self.line == "" then
        return false
    end

    return true
end

--- @param completion_line string
function CompleteLine:set_completion(completion_line)
end

--- @param line string
function CompleteLine:update_line(line)
end


