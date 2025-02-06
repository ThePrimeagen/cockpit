local DEBUG = -5
local INFO = 0
local WARN = 5
local ERROR = 10
local FATAL = 15

--- @param level number
--- @return string
local function levelToString(level)
    if level == DEBUG then
        return "DEBUG"
    elseif level == INFO then
        return "INFO"
    elseif level == WARN then
        return "WARN"
    elseif level == ERROR then
        return "ERROR"
    elseif level == FATAL then
        return "FATAL"
    end
    assert(false, "unknown level", level)
    return ""
end

return {
    DEBUG = DEBUG,
    INFO = INFO,
    WARN = WARN,
    ERROR = ERROR,
    FATAL = FATAL,
    levelToString = levelToString,
}
