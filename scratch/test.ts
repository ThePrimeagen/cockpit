type Bar = {
    foo: number,
    baz: {
        another_prop: number,
        test: () => void,
    },
}

class Foo {
    hereIsAProp = 69
    another = 42

    constructor() {
        console.log("hello")
    }

    foofoo() {
        var b = {}
    }
}

function foo() {
    return [1, 2, 3].map(function(i) {
        if (i < 3) { return i; }
    });
}

export {}
