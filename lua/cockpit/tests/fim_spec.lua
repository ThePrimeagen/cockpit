local Point = require("cockpit.geo").Point
local fim = require("cockpit.fim.fim")
local eq = assert.are.same

describe("fim", function()
    it("fill in the middle text", function()
        local text = [[class Foo {
    method() {
        var b = {}
    }
}]]
        local expected_middle = string.format([[%sclass %sFoo {
    method() {
        var b = {}
    }
}%s]], fim.prefix, fim.suffix, fim.mid)
        local expected_end = string.format([[%sclass Foo {
    method() {
        var b = {}
    }
}%s%s]], fim.prefix, fim.suffix, fim.mid)
        local expected_start = string.format([[%sc%slass Foo {
    method() {
        var b = {}
    }
}%s]], fim.prefix, fim.suffix, fim.mid)

        local one = fim.fim(text, Point:new(1, 6))
        local end_ = fim.fim(text, Point:new(5, 1))
        local start = fim.fim(text, Point:new(1, 1))

        eq(expected_middle, one)
        eq(expected_end, end_)
        eq(expected_start, start)
    end)

end)


