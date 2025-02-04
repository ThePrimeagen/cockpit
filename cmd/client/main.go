package main

import (
	"fmt"

	"theprimeagen.tv/cmd/pkg/req"
)

var requests = []string{
`context:
1.  function foo(in_arr) {
2.      const bar = in_arr.map(x => x + 1)
3.      for

location: 3, 7
`,
`context:
1.  function printValues(obj) {
2.      for (const key in obj) {
3.

location: 3, 11
`,

`context:
1.  class Person {
2.      constructor(name, age) {
3.          this.name = name;
4.          this.age = age;
5.      }
6.
7.      greet() {
8.

location: 8, 7
`,

`context:
1.  async function getData(url) {
2.      try {
3.          const response = await fetch(url);
4.

location: 4, 11
`,

`context:
1.  const express = require('express');
2.  const app = express();
3.
4.  app.get('/users', async (req, res) => {
5.

location: 5, 7
`,

`context:
1.  function Counter() {
2.      const [count, setCount] = useState(0);
3.
4.      return (
5.          <button onClick={() =>

location: 5, 28`,

}

func main() {
    sumPrompt := 0.0
    sumPredict := 0.0
    count := 0
    for i, r := range requests {
        out, err := req.ClientRequest(r)
        if err != nil {
            fmt.Printf("Error %s\nskipping request %d: %s\n", err, i, r)
            continue
        }

        count++
        sumPrompt += out.Timings.PromptMS
        sumPredict += out.Timings.PredictedMS

        fmt.Printf("in: %s\nout: %s\n", r, out.Choices[0].Message.Content)
    }

    fmt.Printf("Prompt\n")
    fmt.Printf("Total(%f): %f\n", sumPrompt / float64(count), sumPrompt)
    fmt.Printf("Predict\n")
    fmt.Printf("Total(%f): %f\n", sumPredict / float64(count), sumPredict)
    fmt.Printf("Total\n")
    fmt.Printf("Total(%f): %f\n", (sumPredict + sumPrompt) / float64(count), sumPredict + sumPrompt)
}

