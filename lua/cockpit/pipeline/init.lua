local logger = require("cockpit.logger.logger")
local config = require("cockpit.config")
local geo = require("cockpit.geo")
local llm = require("cockpit.llm")
local editor = require("cockpit.editor")
local req = require("cockpit.req.req")
local utils = require("cockpit.utils")

local Point = geo.Point

--- @alias InternalDone fun(d: boolean): nil
--- @alias Done fun(ok: boolean, res: any): nil

--- @class PipelineStateResponse
--- @field content string[]
--- @field start number

--- @class PipelineStateRequest
--- @field prefix string
--- @field context string[]
--- @field location string
--- @field request_contents string | nil

--- @class PipelineStateTreeSitter
--- @field scopes Scope
--- @field imports TSNode[]

--- @class PipelineStateLsp
--- @field definitions LspDefinitionResult[]

--- @class PipelineState
--- @field buffer number
--- @field cursor Point
--- @field starting_line string
--- @field treesitter PipelineStateTreeSitter | nil
--- @field lsp PipelineStateLsp | nil
--- @field request PipelineStateRequest | nil
--- @field response PipelineStateResponse
--- @field apply_virtual_text string | nil

--- @class PipelineNode
--- @field run fun(self: PipelineNode, state: any, done: InternalDone): nil
--- @field name fun(self: PipelineNode): string
--- @field on_key fun(self: PipelineNode, key: string): nil

--- @class InitializeStateNode : PipelineNode
--- @field vt VirtualText
local InitializeStateNode = {}
InitializeStateNode.__index = InitializeStateNode

---@param vt VirtualText
function InitializeStateNode:new(vt)
    return setmetatable({ vt = vt }, self)
end

function InitializeStateNode:name()
    return "InitializeStateNode"
end

--- @param _ string
function InitializeStateNode:on_key(_) end

--- @param state PipelineState
---@param done InternalDone
function InitializeStateNode:run(state, done)
    self.vt:clear()

    state.cursor = Point:from_cursor()
    state.starting_line = state.cursor:get_text_line(state.buffer)
    logger:debug(
        "InitializeStateNode",
        "cursor",
        state.cursor,
        "line",
        state.starting_line,
        "buffer",
        state.buffer
    )

    if state.cursor.col <= #state.starting_line then
        logger:debug("InitializeStateNode: cursor before end of column")
        return done(false)
    elseif #vim.trim(state.starting_line) < 2 then
        logger:debug("InitializeStateNode: line too short")
        return done(false)
    end

    return done(true)
end

--- @class TreesitterNode : PipelineNode
local TreesitterNode = {}
TreesitterNode.__index = TreesitterNode

--- @return TreesitterNode
function TreesitterNode:new()
    return setmetatable({}, self)
end

--- @param _ string
function TreesitterNode:on_key(_) end

function TreesitterNode:name()
    return "TreesitterNode"
end

--- @param state PipelineState
---@param done InternalDone
function TreesitterNode:run(state, done)
    local scopes = editor.treesitter.scopes(state.cursor)
    if scopes == nil then
        logger:error("TreesitterNode: early exit, unable to find scope")
        return done(false)
    end

    local imports = editor.treesitter.imports()
    logger:debug("TreesitterNode", "scope", #scopes.scope, "imports", #imports)

    state.treesitter = {
        scopes = scopes,
        imports = imports,
    }
    return done(true)
end

--- @class LspNode : PipelineNode
--- @field lsp Lsp
local LspNode = {}
LspNode.__index = LspNode

--- @param opts CockpitOptions
--- @return LspNode
function LspNode:new(opts)
    return setmetatable({
        lsp = editor.lsp.Lsp:new(opts),
    }, self)
end

--- @param _ string
function LspNode:on_key(_) end

function LspNode:name()
    return "LspNode"
end

--- @param state PipelineState
---@param done InternalDone
function LspNode:run(state, done)
    if state.treesitter == nil then
        logger:debug("unable to do use the lsp to look up extra information")
        return done(false)
    end

    self.lsp:batch_get_ts_node_definitions(
        state.buffer,
        state.treesitter.imports,
        function(definitions)
            logger:debug("LspNode#run finished", "definitions", #definitions)
            state.lsp = {
                definitions = definitions,
            }
            done(true)
        end
    )
end

--- @class ReadyRequestNode : PipelineNode
local ReadyRequestNode = {}
ReadyRequestNode.__index = ReadyRequestNode

--- @return ReadyRequestNode
function ReadyRequestNode:new()
    return setmetatable({}, self)
end

function ReadyRequestNode:name()
    return "ReadyRequestNode"
end

--- @param _ string
function ReadyRequestNode:on_key(_) end

--- @param state PipelineState
---@param done InternalDone
function ReadyRequestNode:run(state, done)
    if state.treesitter == nil or state.lsp == nil then
        logger:debug(
            "ReadyRequestNode had to exit early, no treesitter or lsp information"
        )
        return done(false)
    end

    state.cursor = Point:from_cursor()
    state.starting_line = state.cursor:get_text_line(state.buffer)

    local row, col = state.cursor:to_lua()
    local prefix = llm.lang.add_line_numbers(
        llm.lang.prefix(
            state.treesitter.scopes.range[1]:to_text(),
            row,
            col
        )
    )
    local imported_files = {}

    for _, def in ipairs(state.lsp.definitions) do
        local buffer = vim.uri_to_bufnr(def.uri)
        vim.fn.bufload(buffer)
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        table.insert(lines, 1, string.format("----------- FILE START: %s ----------------", def.uri))
        table.insert(lines, string.format("----------- FILE END: %s ----------------", def.uri))

        logger:debug("ReadyRequestNode loading context", "buffer", buffer, "lines", #lines)

        -- TODO: use treesitter to just grab function defitinions, imports, and other top level items
        local contents = table.concat(lines, "\n")
        contents = contents:gsub("<code>", "&lt;code&gt;")
        table.insert(imported_files, contents)
    end

    state.request = {
        prefix = prefix,
        context = imported_files,
        location = string.format("%d, %d\n", row, col),
    }

    logger:debug(
        "ReadyRequestNode success with",
        "prefix",
        #state.request.prefix,
        "context",
        #state.request.context
    )
    return done(true)
end

--- @class RequestNode : PipelineNode
local RequestNode = {}
RequestNode.__index = RequestNode

--- @return RequestNode
function RequestNode:new()
    return setmetatable({}, self)
end

--- @param _ string
function RequestNode:on_key(_) end

function RequestNode:name()
    return "RequestNode"
end

--- @param state PipelineState
---@param done InternalDone
function RequestNode:run(state, done)
    local context = table.concat(state.request.context, "\n")
    local content = string.format(
        [[------------- Context Start -----------------
%s
------------- Context End -----------------
------------- Code Start -----------------
%s
------------- Code End -----------------
------------- Location Start ---------------
%s
------------- Location End ---------------]],
        context,
        state.request.prefix,
        state.request.location
    )
    state.request.request_contents = content

    logger:error(content)
    req.complete(content, function(data)
        local ok, _ = pcall(llm.openai.get_first_content, data)
        if not ok then
            logger:error(
                "RequestNode code request completed but invalid format",
                "response",
                data
            )
            return done(false)
        end

        local response = llm.openai.get_first_content(data)
        logger:info("RequestNode completed", "response", vim.inspect(data))

        state.response = {
            start = vim.uv.now(),
            content = vim.split(response, "\n"),
        }

        return done(true)
    end)
end

--- @class DisplayNode : PipelineNode
--- @field vt VirtualText
--- @field done fun(ok: boolean): nil | nil
--- @field state PipelineState | nil
local DisplayNode = {}
DisplayNode.__index = DisplayNode

--- @param vt VirtualText
--- @return DisplayNode
function DisplayNode:new(vt)
    return setmetatable({
        vt = vt,
        done = nil,
        state = nil,
    }, self)
end

--- @return string | nil
function DisplayNode:_get_remaining_virtual_text()
    local cursor = Point:from_cursor()
    local line = cursor:get_text_line(self.state.buffer)
    local start = self.state.starting_line

    for _, virt in ipairs(self.state.response.content) do
        local matched = utils.partial_match(start, line, virt)
        if matched ~= nil then
            logger:debug("_get_remaining_virtual_text", "matched", matched)
            return matched
        end
    end

    logger:debug("_get_remaining_virtual_text did not match anything")
    return nil
end

--- @param key string
function DisplayNode:on_key(key)
    if key ~= "\t" then
        self:_display()
        return
    end

    local matched = self:_get_remaining_virtual_text()
    if matched == nil then
        self.state.apply_virtual_text = matched
    end
    return self.done(true)
end

function DisplayNode:name()
    return "DisplayNode"
end

function DisplayNode:_display()
    assert(self.state ~= nil, "somehow state is nil")
    assert(self.done ~= nil, "somehow done is nil")
    assert(
        self.state.response ~= nil,
        "somehow we are displaying without a response"
    )
    assert(
        #self.state.response.content > 0,
        "somehow we are displaying without content"
    )

    local matched = self:_get_remaining_virtual_text()
    if matched == nil then
        return self.done(true)
    end

    local r, _ = Point:from_cursor():to_vim()
    self.vt:clear()
    self.vt:update(matched, r, self.state.buffer)
    self.vt:render()
end

--- @param state PipelineState
---@param done InternalDone
function DisplayNode:run(state, done)
    if state.response == nil or #state.response.content == 0 then
        logger:debug(
            "DisplayNode is running without a valid ending state",
            "state",
            state
        )
        return done(true)
    end

    self.done = done
    self.state = state
    self:_display()
end

--- @class SaveQueryNode : PipelineNode
--- @field config CockpitOptions
local SaveQueryNode = {}
SaveQueryNode.__index = SaveQueryNode

--- @param opts CockpitOptions
--- @return SaveQueryNode
function SaveQueryNode:new(opts)
    return setmetatable({config = opts}, self)
end
function SaveQueryNode:on_key(_) end
function SaveQueryNode:name()
    return "SaveQueryNode"
end

--- @param state PipelineState
---@param done InternalDone
function SaveQueryNode:run(state, done)
    if not self.config.save_queries or state.request.request_contents == nil then
        return done(true)
    end

    local path = config.next_save_query_path(self.config)
    local fd, err = vim.uv.fs_open(path, "w", 493)
    if not fd then
        logger:error("unable to create save query file", "path", path, "err", err)
        return done(true)
    end

    local success, err2 = vim.uv.fs_write(fd, state.request.request_contents)
    if not success then
        logger:error("unable to save query", "path", path, "err", err2)
    end

    return done(true)
end

--- @class ApplyVirtualTextNode : PipelineNode
local ApplyVirtualTextNode = {}
ApplyVirtualTextNode.__index = ApplyVirtualTextNode

--- @return ApplyVirtualTextNode
function ApplyVirtualTextNode:new()
    return setmetatable({}, self)
end
function ApplyVirtualTextNode:on_key(_) end
function ApplyVirtualTextNode:name()
    return "ApplyVirtualTextNode"
end

--- @param state PipelineState
---@param done InternalDone
function ApplyVirtualTextNode:run(state, done)
    logger:debug(
        "ApplyVirtualTextNode",
        "applying text",
        state.apply_virtual_text
    )
    if state.apply_virtual_text == nil then
        return done(false)
    end

    local cursor = Point:from_cursor()
    local line = cursor:get_text_line(state.buffer)
    cursor:set_text_line(state.buffer, line .. line)
    -- todo: i think there has to be a way to make this work well
    -- cursor:update_to_end_of_line()

    return done(true)
end

--- @param pipeline Pipeline
--- @param index number
--- @param state any
--- @param done Done
local function run_pipeline(pipeline, index, state, done)
    if #pipeline.nodes < index then
        logger:debug(
            "run_pipeline: end_state",
            "index",
            index,
            "count",
            #pipeline.nodes
        )
        return done(true, state)
    end

    local node = pipeline.nodes[index]
    pipeline.active_node = node

    logger:debug(
        "run_pipeline",
        "index",
        index,
        "count",
        #pipeline.nodes,
        "name",
        node:name()
    )

    local ok, res, err = pcall(node.run, node, state, function(ok)
        if not ok then
            return done(false, state)
        else
            run_pipeline(pipeline, index + 1, state, done)
        end
    end)


    if not ok then
        logger:error("error calling node.run", "err", err, "res", res)
        return done(false, state)
    end
end

--- @class Pipeline
--- @field vt VirtualText
--- @field nodes PipelineNode[]
--- @field active_node PipelineNode | nil
--- @field active_state PipelineState | nil
--- @field running boolean
--- @field config CockpitOptions
local Pipeline = {}
Pipeline.__index = Pipeline

--- @param opts CockpitOptions
function Pipeline:new(opts)
    return setmetatable({
        nodes = {
            InitializeStateNode:new(llm.display),
            TreesitterNode:new(),
            LspNode:new(opts),
            ReadyRequestNode:new(),
            RequestNode:new(),
            SaveQueryNode:new(opts),
            DisplayNode:new(llm.display),
            ApplyVirtualTextNode:new(),
        },
        config = opts,
        active_node = nil,
        active_state = nil,
        running = false,
    }, self)
end

--- @param key string
function Pipeline:on_key(key)
    if self.active_node == nil then
        return
    end

    assert(
        self.active_state ~= nil,
        "cannot have an active_node without an active state"
    )
    self.active_node:on_key(key)
end

--- @param state PipelineState
--- @param done Done
function Pipeline:run(state, done)
    if self.running then
        logger:info("Pipeline: the pipeline is already running")
        return done(false, state)
    end

    self.running = true
    self.active_state = state

    logger:debug("Pipeline: run_pipeline")
    run_pipeline(self, 1, state, function(ok, s)
        self.running = false
        self.active_state = nil
        self.active_node = nil
        llm.display:clear()
        done(ok, s)
    end)
end

return Pipeline
