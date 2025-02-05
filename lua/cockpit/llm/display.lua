local logger = require("cockpit.logger.logger")
local ns_id = vim.api.nvim_create_namespace("cockpit-vt")

--- @class VirtualText
--- @field vt_id unknown
--- @field row number
--- @field buffer number
--- @field text string
local VirtualText = {}
VirtualText.__index = VirtualText

--- @return VirtualText
function VirtualText:new(buffer)
    return setmetatable({
        vt_id = nil,
        row = 0,
        buffer = buffer,
        text = "",
    }, self)
end

function VirtualText:render()
    self.vt_id = vim.api.nvim_buf_set_extmark(self.buffer, ns_id, self.row, 0, {
        virt_text = { { self.text, "Comment" } },
        right_gravity = true,
    })
end

function VirtualText:clear()
    logger:info("clearing virtual text")
    vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
end

--- @param text string
---@param row number | nil
---@param buffer number | nil
function VirtualText:update(text, row, buffer)
    logger:info("VirtualText#update", "text", text, "row", row, "buffer", buffer)
    self.text = text
    if row ~= nil then
        self.row = row
    end
    if buffer ~= nil then
        self.buffer = buffer
    end
end

local vt = VirtualText:new(0)

return vt
