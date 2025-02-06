local lang = require("cockpit.llm.lang")
local eq = assert.are.same

describe("lang", function()
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
}%s]], lang.fim_prefix, lang.fim_suffix, lang.fim_middle)
        local expected_end = string.format([[%sclass Foo {
    method() {
        var b = {}
    }
}%s%s]], lang.fim_prefix, lang.fim_suffix, lang.fim_middle)
        local expected_start = string.format([[%sc%slass Foo {
    method() {
        var b = {}
    }
}%s]], lang.fim_prefix, lang.fim_suffix, lang.fim_middle)

        local one = lang.fim(text, 1, 6)
        local end_ = lang.fim(text, 5, 1)
        local start = lang.fim(text, 1, 1)

        eq(expected_middle, one)
        eq(expected_end, end_)
        eq(expected_start, start)
    end)

end)


