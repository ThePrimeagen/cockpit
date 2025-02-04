local geo = require("cockpit.geo")
local utils = require("cockpit.tests.test_utils")

local Point = geo.Point
local Range = geo.Range
local eq = assert.are.same

describe("faux test", function()
    it("here we are", function()
        local buffer = utils.create_test_file()
        eq([[class Foo {
    method() {
        var b = {}
    }
}]],
        Range:new(buffer, Point:new(1, 1), Point:new(5, 1)):to_text())

        eq([[function(i) {
        return i + 7
    }]],
        Range:new(buffer, Point:new(7, 26), Point:new(9, 5)):to_text())

    end)
end)
