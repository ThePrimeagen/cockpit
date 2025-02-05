local ts = require("cockpit.editor.treesitter")
local geo = require("cockpit.geo")

local Point = geo.Point
local Range = geo.Range
local eq = assert.are.same

describe("range", function()
    it("range with to_text ", function()
        vim.cmd([[:e lua/cockpit/tests/test_file.ts]])
        eq(
            [[class Foo {
    method() {
        var b = {}
    }
}]],
            Range:new(0, Point:new(1, 1), Point:new(5, 2)):to_text()
        )

        eq(
            [[function(i) {
        return i + 7
    }]],
            Range:new(0, Point:new(8, 26), Point:new(10, 6)):to_text()
        )
    end)

    it("point comparisons", function()
        local p1 = Point:new(1, 2)
        local p2 = Point:new(2, 2)
        local p3 = Point:new(1, 3)
        local p4 = Point:new(1, 1)
        local p5 = Point:new(1, 2)

        eq(true, p1:lt(p2))
        eq(true, p1:lt(p3))
        eq(true, p1:gt(p4))
        eq(true, p1:eq(p5))
        eq(true, p1:lte(p5))
        eq(true, p1:gte(p5))
    end)

    it("range with scopes", function()
        vim.cmd([[:e lua/cockpit/tests/test_file.ts]])
        local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), "\n")
        local scopes = ts.scopes(Point:new(1, 1))
        eq(content, scopes.range[1]:to_text())
        eq([[class Foo {
    method() {
        var b = {}
    }
}]], scopes.range[2]:to_text())

    end)
end)
