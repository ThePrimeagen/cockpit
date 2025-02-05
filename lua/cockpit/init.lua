local ts = require("cockpit.treesitter.treesitter")
local Point = require("cockpit.geo").Point
local llm = require("cockpit.llm")
local req = require("cockpit.req.req")

local M = {}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local del_autocmd = vim.api.nvim_del_autocmd
local cockpit_group = augroup("Cockpit", {})
local cmd_id = nil

--- @param opts CockpitOptions
function M.setup(opts)
    opts = vim.tbl_extend("force", {}, opts or {})
    cmd_id = autocmd("TextChangedI", {
        group = cockpit_group,
        pattern = '*',
        --- @param arg TextChangedIEvent
        callback = function(arg)
            local buffer = arg.buf

        end,
    })

    --local cursor = Point:from_cursor()
    --local scope = ts.scopes(cursor)
    --local row, col = cursor:to_lua()
    --local prefix = llm.lang.prefix(scope.range[1]:to_text(), row, col)
    --local loc = string.format("%d, %d\n", row, col)
    --req.complete(string.format("<code>%s</code><location>%s</location>", prefix, loc), function(data)
    --    print("complete:", llm.openai.get_first_content(data))
    --end)
end

local dc = vim.api.nvim_del_user_command
function M.cockpit_refresh()
    if cmd_id ~= nil then
        del_autocmd(cmd_id)
        cmd_id = nil
    end

    for module_name in pairs(package.loaded) do
        if module_name:match("^cockpit") then
            package.loaded[module_name] = nil
        end
    end
    pcall(dc, "CockpitTest")
    pcall(dc, "CockpitRefresh")
    require("cockpit")
end

vim.api.nvim_create_user_command("CockpitTest", M.setup, {})
vim.api.nvim_create_user_command("CockpitRefresh", M.cockpit_refresh, {})

return M
