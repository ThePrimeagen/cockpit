local levels = require("cockpit.logger.level")

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
            value = string.format('"%s"', value)
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
        fd = fd,
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

--- @param level number
function Logger:new(level)
    level = level or levels.DEBUG
    return setmetatable({
        sink = PrintSink:new(),
        level = level,
    }, self)
end

--- @param config CockpitOptions
function Logger:init(config)
    if config.log_level ~= nil then
        self.level = config.log_level
    end
    if config.log_file_path ~= nil then
        self:file_sink(config.log_file_path)
    end
end

--- @param path string
--- @return Logger
function Logger:file_sink(path)
    self.sink = FileSink:new(path)
    return self
end

--- @param level number
--- @return Logger
function Logger:set_level(level)
    self.level = level
    return self
end

function Logger:_log(level, msg, ...)
    if self.level > level then
        return
    end

    local args = stringifyArgs(...)
    local line =
        string.format("[%s]: %s %s", levels.levelToString(level), msg, args)
    self.sink:write_line(line)
end

--- @param msg string
--- @param ... any
function Logger:info(msg, ...)
    self:_log(levels.INFO, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:warn(msg, ...)
    self:_log(levels.WARN, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:debug(msg, ...)
    self:_log(levels.DEBUG, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:error(msg, ...)
    self:_log(levels.ERROR, msg, ...)
end

--- @param msg string
--- @param ... any
function Logger:fatal(msg, ...)
    self:_log(levels.FATAL, msg, ...)
    assert(false, "fatal msg recieved")
end

local module_logger = Logger:new(levels.DEBUG)

return module_logger
