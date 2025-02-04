local utils = require("cockpit.utils")
local M = {}

local content_length = "content-length:"

--- @param buf string
--- @return string | nil
local function decode_http(buf)
    local lines = utils.split(buf, "\r\n")
    print("lines", vim.inspect(lines))
    local length = 0
    local empty_field_line = 0
    for k, v in ipairs(lines) do
        local lower = v:lower()
        if v == "" then
            empty_field_line = k
            print("found empty header line", length)
            break
        end

        if #content_length < #lower and content_length == lower:sub(1, #content_length) then
            local len = tonumber(utils.trim(lower:sub(#content_length + 1)))
            if len == nil then
                error("bad request response?", lower)
                -- todo: put in the logger
            end

            length = len
            print("found length", length)
        end
    end

    if length == 0 then
        return
    end

    if empty_field_line == 0 then
        return
    end

    return table.concat(utils.slice(lines, empty_field_line + 1), "\n")
end

--- @param req string
---@param cb fun(res): nil
function M.complete(req, cb)
    local uv = vim.loop
    local client = uv.new_tcp()

    local function read_message()
        local buf = ""
        client:read_start(function(err, data)
            if err then
                -- TODO: logging
                return
            end
            data = buf .. data
            local msg = decode_http(data)
            if msg == nil then
                buf = data
                return
            end
            local ok, d = pcall(vim.json.decode, msg)
            if not ok then
                error("decode failed", data)
            end

            cb(d)
            client:close()
        end)
    end

    local function send_message()
        local request = {
            "GET / HTTP/1.1",
            string.format("Host: localhost:6969"),
        }
        local prompt = { prompt = req, }
        local str = vim.json.encode(prompt)

        table.insert(request, string.format("Content-length: %d", #str))
        table.insert(request, "")
        table.insert(request, str)
        local str_request = table.concat(request, "\r\n")
        client:write(str_request)
    end

    -- Connect to the resolved address and port
    client:connect("127.0.0.1", "6969", function(e)
        if not e then
            read_message()
            send_message()
        else
            -- TODO: make better
            error("could not connect")
        end
    end)
end

return M
