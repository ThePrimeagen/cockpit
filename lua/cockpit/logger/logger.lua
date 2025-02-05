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

--- @param ... any[]
--- @return string
local function stringifyArgs(...)
    local count = select("#", ...)
    local out = {}
    assert(
        count % 2 == 0,
        "you cannot call logging with an odd number of args. e.g: msg, [k, v]..."
    )
    for i = 1, count, 2 do
        local key = select(i, ...)
        local value = select(i + 1, ...)
        assert(type(key) == "string", "keys in logging must be strings")

        if type(value) == "table" then
            if type(value.to_string) == "function" then
                value = value:to_string()
            else
                value = vim.inspect(value)
            end
        elseif type(value) == "string" then
            value = string.format("\"%s\"", value)
        else
            value = tostring(value)
        end

        table.insert(out, string.format("%s=%s", key, value))
    end
    return table.concat(out, " ")
end

--- @class LoggerSink
--- @field write_line fun(LoggerSink, string): nil

--- @class FileSink : LoggerSink
--- @field fd number
local FileSink = {}
FileSink.__index = FileSink

--- @param path string
--- @return LoggerSink
function FileSink:new(path)
    local fd, err = vim.uv.fs_open(path, "w", 493)
    if not fd then
        error("unable to file sink", err)
    end

    return setmetatable({
        fd = fd
    }, self)
end

--- @param str string
function FileSink:write_line(str)
    local success, err = vim.uv.fs_write(self.fd, str .. "\n")
    if not success then
        error("unable to write to file sink", err)
    end
end

--- @class PrintSink : LoggerSink
local PrintSink = {}
PrintSink.__index = PrintSink

--- @return LoggerSink
function PrintSink:new()
    return setmetatable({}, self)
end

--- @param str string
function PrintSink:write_line(str)
    local _ = self
    print(str)
end

--- @class Logger
--- @field level number
--- @field sink LoggerSink
local Logger = {}
Logger.__index = Logger

function Logger:new()
    return setmetatable({
        sink = PrintSink:new(),
        level = DEBUG,
    }, self)
end

--- @param path string
function Logger:file_sink(path)
    self.sink = FileSink:new(path)
end

function Logger:_log(level, msg, ...)
    if self.level > level then
        return
    end

    local args = stringifyArgs(...)
    local line = string.format("[%s]: %s %s", levelToString(level), msg, args)
    self.sink:write_line(line)
end

--- @param msg string
--- @param ... any
function Logger:info(msg, ...)
    self:_log(INFO, msg, ...)
end

--- @param msg string
--- @param ... any[]
function Logger:warn(msg, ...)
    self:_log(WARN, msg, ...)
end

--- @param msg string
--- @param ... any[]
function Logger:debug(msg, ...)
    self:_log(DEBUG, msg, ...)
end

--- @param msg string
--- @param ... any[]
function Logger:error(msg, ...)
    self:_log(ERROR, msg, ...)
end

--- @param msg string
--- @param ... any[]
function Logger:fatal(msg, ...)
    self:_log(FATAL, msg, ...)
    assert(false, "fatal msg recieved")
end

local module_logger = Logger:new()

return module_logger
