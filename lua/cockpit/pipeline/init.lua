local logger = require("cockpit.logger.logger")
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

--- @class PipelineNode
--- @field run fun(self: PipelineNode, state: any, done: InternalDone): nil
--- @field name fun(): string

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

--- @param state PipelineState
---@param done InternalDone
function InitializeStateNode:run(state, done)
    logger:error("isn", "vt", self.vt)

    self.vt:clear()

    state.cursor = Point:from_cursor()
    state.starting_line = state.cursor:get_text_line(state.buffer)
    logger:debug("InitializeStateNode", "cursor", state.cursor, "line", state.starting_line, "buffer", state.buffer)

    if state.cursor.col <= #state.starting_line then
        logger:debug("InitializeStateNode: cursor before end of column")
        done(false)
    elseif #vim.trim(state.starting_line) < 2 then
        logger:debug("InitializeStateNode: line too short")
        done(false)
    else
        done(true)
    end
end

--- @class TreesitterNode : PipelineNode
local TreesitterNode = {}
TreesitterNode.__index = TreesitterNode

--- @return TreesitterNode
function TreesitterNode:new()
    return setmetatable({}, self)
end

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

    logger:debug("scopes", "scope", scopes)
    local imports = editor.treesitter.imports()

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

--- @param config CockpitOptions
--- @return LspNode
function LspNode:new(config)
    return setmetatable({
        lsp = editor.lsp.Lsp:new(config),
    }, self)
end

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

    self.lsp:batch_get_ts_node_definitions(state.buffer, state.treesitter.imports, function(definitions)
        state.lsp = {
            definitions = definitions,
        }
        done(true)
    end)
end

--- @class ReadyRequestNode : PipelineNode
local ReadyRequestNode = {}
ReadyRequestNode.__index = ReadyRequestNode

--- @return ReadyRequestNode
function ReadyRequestNode:new()
    return setmetatable({ }, self)
end

function ReadyRequestNode:name()
    return "ReadyRequestNode"
end

--- @param state PipelineState
---@param done InternalDone
function ReadyRequestNode:run(state, done)
    if state.treesitter == nil or state.lsp == nil then
        logger:debug("ReadyRequestNode had to exit early, no treesitter or lsp information")
        return done(false)
    end

    state.cursor = Point:from_cursor()
    state.starting_line = state.cursor:get_text_line(state.buffer)

    local row, col = state.cursor:to_ts()
    local prefix = llm.lang.add_line_numbers(llm.lang.prefix(state.treesitter.scopes.range[1]:to_text(), row, col))
    local imported_files = {}

    for _, def in ipairs(state.lsp.definitions) do
        local buffer = vim.uri_to_bufnr(def.uri)

        -- TODO: use treesitter to just grab function defitinions, imports, and other top level items
        local contents = table.concat(vim.api.nvim_get_buf_lines(buffer, 0, -1, false), "\n")
        table.insert(imported_files, contents)
    end

    state.request = {
        prefix = prefix,
        context = imported_files,
        location = string.format("%d, %d\n", row, col)
    }

    logger:debug("ReadyRequestNode success with", "prefix", #state.request.prefix, "context", #state.request.context)
    return done(true)
end

--- @class RequestNode : PipelineNode
local RequestNode = {}
RequestNode.__index = RequestNode

--- @return RequestNode
function RequestNode:new()
    return setmetatable({ }, self)
end

function RequestNode:name()
    return "RequestNode"
end

--- @param state PipelineState
---@param done InternalDone
function RequestNode:run(state, done)
    local context = table.concat(state.request.context)
    local content = string.format("<context>%s</context><code>%s</code><location>%s</location>", context, state.request.prefix, state.request.location)

    req.complete(content, function (data)
        local ok, _ = pcall(llm.openai.get_first_content, data)
        if not ok then
            logger:error("RequestNode code request completed but invalid format", "response", data)
            return done(false)
        end

        local response = llm.openai.get_first_content(data)
        logger:info("RequestNode completed", "response", response)

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

function DisplayNode:name()
    return "DisplayNode"
end

function DisplayNode:_display()
    assert(self.state ~= nil, "somehow state is nil")
    assert(self.done ~= nil, "somehow done is nil")
    assert(self.state.response ~= nil, "somehow we are displaying without a response")
    assert(#self.state.response.content > 0, "somehow we are displaying without content")

    local cursor = Point:from_cursor()
    local line = cursor:get_text_line(self.state.buffer)
    local content = self.state.response.content[1]
    local _, idx = utils.partial_match(line, content)
    local r, _ = cursor:to_vim()

    self.vt:update(content:sub(idx), r, self.state.buffer)
    self.vt:render()
end

--- @param state PipelineState
---@param done InternalDone
function DisplayNode:run(state, done)
    if state.response == nil or #state.response.content > 0 then
        logger:debug("DisplayNode is running without a valid ending state", "state", state)
        done(false)
    end

    self.done = done
    self.state = state
    self:_display()
end

--- @param pipeline Pipeline
--- @param index number
--- @param state any
--- @param done Done
local function run_pipeline(pipeline, index, state, done)
    logger:debug("run_pipeline", "index", index, "count", #pipeline.nodes)
    if #pipeline.nodes < index then
        logger:debug("run_pipeline: end_state", "index", index, "count", #pipeline.nodes)
        return done(true, state)
    end

    local node = pipeline.nodes[index]
    logger:debug("run_pipeline", "name", node:name())

    local ok, _ = pcall(node.run, node, state, function(ok)
        if not ok then
            return done(false, state)
        else
            run_pipeline(pipeline, index + 1, state, done)
        end
    end)

    if not ok then
        return done(false, state)
    end
end

--- @class Pipeline
--- @field vt VirtualText
--- @field nodes PipelineNode[]
--- @field running boolean
--- @field config CockpitOptions
local Pipeline = {}
Pipeline.__index = Pipeline

--- @param config CockpitOptions
function Pipeline:new(config)
    return setmetatable({
        nodes = {
            InitializeStateNode:new(llm.display),
            TreesitterNode:new(),
            LspNode:new(config),
            ReadyRequestNode:new(),
            RequestNode:new(),
            DisplayNode:new(llm.display),
        },
        config = config,
        running = false,
    }, self)
end

--- @param state PipelineState
--- @param done Done
function Pipeline:run(state, done)
    if self.running then
        logger:info("Pipeline: the pipeline is already running")
        done(false, state)
        return
    end

    self.running = true
    logger:debug("Pipeline: run_pipeline")
    run_pipeline(self, 1, state, function(ok, s)
        self.running = false
        done(ok, s)
    end)
end

return Pipeline
