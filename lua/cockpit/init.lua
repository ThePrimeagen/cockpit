local utils = require("cockpit.utils")
local ts = require("cockpit.treesitter.treesitter")
local Point = require("cockpit.geo").Point
local llm = require("cockpit.llm")
local req = require("cockpit.req.req")
local logger = require("cockpit.logger.logger")

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
    logger:file_sink("/tmp/cockpit")
    logger:warn("cockpit#setup")

    local pending_request = false
    local current_line = ""
    local current_request = nil
    local current_start = 0

    local function valid(buffer)
        assert(current_request ~= nil, "somehow we are checking for a valid completion and no current request")
        local cursor = Point:from_cursor()
        local line = cursor:get_text_line(buffer)
        local expected = llm.openai.get_first_content(current_request)
        local partial = utils.partial_match(line, expected)
        logger:info("valid", "partial", partial)
        return partial
    end

    local function display(buffer)
        assert(current_request ~= nil, "somehow we are checking for a valid completion and no current request")
        local cursor = Point:from_cursor()
        local line = cursor:get_text_line(buffer)
        local expected = llm.openai.get_first_content(current_request)
        local _, idx = utils.partial_match(line, expected)
        local r, _ = cursor:to_vim()
        vt:update(expected:sub(idx), r, buffer)
        vt:render()
    end

    --- @param arg TextChangedIEvent
    local function run_complete(arg)
        vt:clear()

        local buffer = arg.buf
        local cursor = Point:from_cursor()
        local line = cursor:get_text_line(buffer)
        logger:info("run_complete", "cursor", cursor, "line", line, "buffer", buffer)
        -- 1. i am at the end of the line
        if cursor.col <= #line then
            logger:info("run_complete exit early: cursor isn't at end")
            return
        end

        -- 2. there are more than 2 alphanumeric characters
        if #vim.trim(line) < 2 then
            logger:info("run_complete exit early: not enough content")
            return
        end

        -- 3. there is no request in flight
        if pending_request then
            logger:info("run_complete exit early: pending_request")
            return
        end

        -- 4a. we have no current request, we need to request it
        if current_request == nil then
            local scope = ts.scopes(cursor)
            if scope == nil then
                logger:info("run_complete exit early: scopes are nil, unable to request")
                return
            end

            pending_request = true
            local row, col = cursor:to_lua()
            local prefix = llm.lang.prefix(scope.range[1]:to_text(), row, col)
            local loc = string.format("%d, %d\n", row, col)
            logger:info("run_complete code request", "loc", loc)

            current_line = cursor:get_text_line(buffer)

            req.complete(string.format("<code>%s</code><location>%s</location>", prefix, loc), function(data)
                pending_request = false
                current_request = data
                local ok, _ = pcall(llm.openai.get_first_content, data)
                if not ok then
                    logger:info("run_complete code request completed but invalid")
                    current_request = nil
                    return
                end

                logger:info("run_complete code request completed", "completion", llm.openai.get_first_content(data))
                current_start = vim.uv.now()
                display(buffer)

            end)
            return
        end

        local now = vim.uv.now()
        if now - current_start > 1000 then
            current_request = nil
            run_complete(arg)
            return
        end

        -- 4b. there is no current completion or the current completion does't match the current characters
        --    whitespace difficulty here...
        --    NOT IMPLEMENTED
        --    BECAUSE I AM BAD AT PROGRAMMING
        display(buffer)
    end

    table.insert(ids, autocmd("BufLeave", {
        group = cockpit_group,
        pattern = '*',
        callback = function(arg)
            vt:clear()
        end,
    }))

    table.insert(ids, autocmd("TextChangedI", {
        group = cockpit_group,
        pattern = '*',
        callback = vim.schedule_wrap(run_complete),
    }))

    table.insert(ids, autocmd("ModeChanged", {
        group = cockpit_group,
        pattern = '*',
        callback = function()
            vt:clear()
        end
    }))

    vim.keymap.set("i", "<tab>", function()
        if current_request == nil then
            return
        end

        local buffer = vim.api.nvim_get_current_buf()
        local cursor = Point:from_cursor()
        local line = cursor:get_text_line(buffer)
        local ok, idx = utils.partial_match(current_line, line)
        if not ok then
            logger:info("insert<tab>: current line state doesn't match original request line", "current_line_state", line, "requested_line_state", current_line)
            current_request = nil
            return
        end

        local sub_match = line:sub(idx)
        local completion = vim.trim(llm.openai.get_first_content(current_request))
        local _, idx = utils.partial_match(line, completion)

        --[[
        ok, idx = utils.partial_match(sub_match, completion)
        logger:info("insert<tab> completion match", "ok", ok, "idx", idx)
        if not ok then
            current_request = nil
            return
        end

        local remaining_completion = completion:sub(idx)
        logger:info("insert<tab> remaining ok", "remaining", remaining_completion)

        local final = line .. remaining_completion
        --]]
        cursor:set_text_line(buffer, line .. completion:sub(idx))
        cursor:insert_new_line_below(buffer)
    end)

end

local dc = vim.api.nvim_del_user_command
function M.cockpit_refresh()
    vt:clear()
    pcall(vim.api.nvim_del_keymap, "i", "<tab>")

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
    logger:warn("cockpit_refresh")
end

vim.api.nvim_create_user_command("CockpitTest", M.setup, {})
vim.api.nvim_create_user_command("CockpitRefresh", M.cockpit_refresh, {})

return M
