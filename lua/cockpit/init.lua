local utils = require("cockpit.utils")
local Point = require("cockpit.geo").Point
local llm = require("cockpit.llm")
local req = require("cockpit.req.req")
local logger = require("cockpit.logger.logger")
local config = require("cockpit.config")
local Pipeline = require("cockpit.pipeline")

local M = {}

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local del_autocmd = vim.api.nvim_del_autocmd
local cockpit_group = augroup("Cockpit", {})
local ids = {}

local vt = llm.display
local initialized = false

--- @param opts CockpitOptions
function M.setup(opts)
    if initialized then
        print("already called setup")
        logger:warn("everything has been setup already")
        return
    end
    print("running")

    initialized = true

    opts = vim.tbl_extend("force", config.default(), opts or {})
    logger:file_sink("/tmp/cockpit")
    logger:warn("cockpit#setup")

    local editor_state = Pipeline:new(config)

    --- @param arg TextChangedIEvent
    local function run_complete(arg)
        local state = { buffer = arg.buf }

        --- TODO: swap ok to an error and check for its lack of existence
        editor_state:run(state, function(ok, res)
            if not ok then
                logger:info("pipeline finished early")
            else
                logger:info("pipeline finished", "res", res)
            end

        end)
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
        --if current_request == nil then
        --    return
        --end

        --local buffer = vim.api.nvim_get_current_buf()
        --local cursor = Point:from_cursor()
        --local line = cursor:get_text_line(buffer)
        --local ok, idx = utils.partial_match(current_line, line)
        --if not ok then
        --    logger:info("insert<tab>: current line state doesn't match original request line", "current_line_state", line, "requested_line_state", current_line)
        --    current_request = nil
        --    return
        --end

        --local sub_match = line:sub(idx)
        --local completion = vim.trim(llm.openai.get_first_content(current_request))
        --local _, idx = utils.partial_match(line, completion)

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
        --cursor:set_text_line(buffer, line .. completion:sub(idx))
        --cursor:update_to_end_of_line()
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
