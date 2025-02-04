local uv = vim.loop
local client = uv.new_tcp()

--- @class TCPSocket
--- @field close fun(self: TCPSocket)
--- @field connect fun(self: TCPSocket, addr: string, port: number, cb: fun(e: unknown))
--- @field is_closing fun(self: TCPSocket): boolean
--- @field write fun(self: TCPSocket, msg: string)
--- @field read_start fun(self: TCPSocket, cb: fun(err: unknown, data: string))

local function read_message()
    client:read_start(function(err, data)
        if err then
            print("Read error:", err)
            return
        end

        print("data received", data)
    end)
end

local function send_message()
    local request = {
        "GET / HTTP/1.1",
        string.format("Host: localhost:6969"),
    }

    local prompt = {
        prompt = [[context:
1.  const express = require('express');
2.  const app = express();
3.
4.  app.get('/users', async (req, res) => {
5.

location: 5, 7]],
    }
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
        print("connected")
        read_message()
        send_message()
    else
        error("could not connect")
    end
end)

