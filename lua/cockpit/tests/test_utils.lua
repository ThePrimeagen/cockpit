local utils = require("cockpit.utils")
local api = vim.api

local function create_test_file()
    local content = utils.split(
        [[class Foo {
    method() {
        var b = {}
    }
}
function anon_fn() {
    return [1, 2, 3].map(function(i) {
        return i + 7
    });
}
function arrow_fn() {
    return [1, 2, 3].map(i => i + 7)
}
]],
        "\n"
    )
    local buffer = api.nvim_create_buf(false, true)
    api.nvim_win_set_buf(0, buffer)
    api.nvim_buf_set_lines(buffer, 0, -1, false, content)
    return buffer
end

return {
    create_test_file = create_test_file,
}
