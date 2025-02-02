local project_row = 100000000

--- @param point_or_row Point | number
--- @param col number | nil
--- @return number
local function project(point_or_row, col)
    if type(point_or_row) == "number" then
        return point_or_row * project_row + col
    end
    return point_or_row.row * project_row + point_or_row.col
end

--- stores all values as 1 based
--- @class Point
--- @field row number
--- @field col number
local Point = {}
Point.__index = Point

function Point:from_cursor()
    local point = setmetatable({
        row = 0,
        col = 0,
    }, self)

    local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
    point.row = cursor_row
    point.col = cursor_col + 1
    return point
end

--- @param row number
---@param col number
--- @return Point
function Point:from_ts_point(row, col)
    return setmetatable({
        row = row + 1,
        col = col + 1,
    }, self)
end

--- stores all 2 points
--- @param range Range
--- @return boolean
function Point:in_ts_range(range)
    return range:contains(self)
end

--- vim.api.nvim_buf_get_text uses 0 based row and col
--- @return number, number
function Point:to_vim()
    return self.row - 1, self.col - 1
end

--- treesitter uses 0 based row and col
--- @return number, number
function Point:to_ts()
    return self.row - 1, self.col - 1
end

--- @param point Point
--- @return boolean
function Point:gt(point)
    return project(self) > project(point)
end

--- @param point Point
--- @return boolean
function Point:lt(point)
    return project(self) < project(point)
end

--- @param point Point
--- @return boolean
function Point:lte(point)
    return project(self) <= project(point)
end

--- @param point Point
--- @return boolean
function Point:gte(point)
    return project(self) >= project(point)
end

--- @param point Point
--- @return boolean
function Point:eq(point)
    return project(self) == project(point)
end

--- @class Range
--- @field start Point
--- @field end_ Point
--- @field buffer number
local Range = {}
Range.__index = Range

---@param node TSNode
---@param buffer number
---@return Range
function Range:from_ts_node(node, buffer)
    -- ts is zero based
    local start_row, start_col, _ = node:start()
    local end_row, end_col, _ = node:end_()

    local range = {
        start = Point:from_ts_point(start_row, start_col),
        end_ = Point:from_ts_point(end_row, end_col),
        buffer = buffer,
    }

    return setmetatable(range, self)
end

--- @param point Point
--- @return boolean
function Range:contains(point)
    local start = project(self.start)
    local stop = project(self.end_)
    local p = project(point)
    return start <= p and p <= stop
end

--- @return string
function Range:to_text()
    local sr, sc = self.start:to_vim()
    local er, ec = self.end_:to_vim()
    return vim.api.nvim_buf_get_text(self.buffer, sr, sc, er, ec, {})
end

--- @param range Range
--- @return boolean
function Range:contains_range(range)
    return self.start:lte(range.start) and self.end_:gte(range.end_)
end

return {
    Point = Point,
    Range = Range,
}
