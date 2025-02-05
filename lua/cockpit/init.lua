local ts = require("cockpit.treesitter.treesitter")
local Point = require("cockpit.geo").Point
local llm = require("cockpit.llm")
local req = require("cockpit.req.req")

local M = {}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local del_autocmd = vim.api.nvim_del_autocmd
local cockpit_group = augroup("Cockpit", {})
local ids = {}

local vt = llm.display

--- @param opts CockpitOptions
function M.setup(opts)
    opts = vim.tbl_extend("force", {}, opts or {})

    local pending_request = false
    local current_request = nil

    local function valid(buffer)
        local cursor = Point:from_cursor()
        local line = cursor:get_text_line(buffer)
    end

    local function display(buffer)
    end

    --- @param arg TextChangedIEvent
    local function run_complete(arg)
        local buffer = arg.buf
        local cursor = Point:from_cursor()
        local line = cursor:get_text_line(buffer)
        -- 1. i am at the end of the line
        if cursor.col <= #line then
            return
        end

        -- 2. there are more than 2 alphanumeric characters
        if #vim.trim(line) < 2 then
            return
        end

        -- 3. there is no request in flight
        if pending_request then
            return
        end

        -- 4a. we have no current request, we need to request it
        if current_request == nil then
            pending_request = true
            local scope = ts.scopes(cursor)
            local row, col = cursor:to_lua()
            local prefix = llm.lang.prefix(scope.range[1]:to_text(), row, col)
            local loc = string.format("%d, %d\n", row, col)
            req.complete(string.format("<code>%s</code><location>%s</location>", prefix, loc), function(data)
                pending_request = false
                current_request = data
                if valid() then
                    display(buffer)
                else
                    current_request = nil

                    -- TODO: figure out a way to really make this awesome...
                end
            end)
            return
        end

        -- 4b. there is no current completion or the current completion does't match the current characters
        --    whitespace difficulty here...
        if valid(buffer) then
            display(buffer)
        else
            current_request = nil
            run_complete(arg)
        end
    end

    table.insert(ids, autocmd("BufLeave", {
        group = cockpit_group,
        pattern = '*',
        callback = run_complete,
    }))

    table.insert(ids, autocmd("TextChangedI", {
        group = cockpit_group,
        pattern = '*',

        --- @param arg TextChangedIEvent
        callback = function(arg)
            local buffer = arg.buf

        end,
    }))

end

local dc = vim.api.nvim_del_user_command
function M.cockpit_refresh()
    vt:clear()
    for _, id in ipairs(ids) do
        del_autocmd(id)
    end
    ids = {}

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
