class Foo {
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

