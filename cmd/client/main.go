package main

import (
	"flag"
	"fmt"
	"log"
	"math/rand/v2"
	"os"
	"path"
	"sync"

	"theprimeagen.tv/cmd/pkg/req"
)

type Stat struct {
    Prompt float64
    Predict float64
    Count int
}

func (s *Stat) Print() {
    fmt.Printf("Prompt\n")
    fmt.Printf("Total(%f): %f\n", s.Prompt / float64(s.Count), s.Prompt)
    fmt.Printf("Predict\n")
    fmt.Printf("Total(%f): %f\n", s.Predict / float64(s.Count), s.Predict)
    fmt.Printf("Total\n")
    fmt.Printf("Total(%f): %f\n", (s.Predict + s.Prompt) / float64(s.Count), s.Predict + s.Prompt)
}

func readAllFiles() []string {
    out := []string{}

    entries, err := os.ReadDir("./data")
    if err != nil {
        log.Fatalf("error: %s", err)
    }

    for _, entry := range entries {
        if !entry.Type().IsRegular() {
            continue
        }
        wd, err := os.Getwd()
        if err != nil {
            log.Fatalf("error: %s", err)
        }
        p := path.Join(wd, "data", entry.Name())
        contents, err := os.ReadFile(p)
        if err != nil {
            log.Fatalf("error: %s", err)
        }
        out = append(out, string(contents))
    }

    return out
}

func request(count int, ch chan struct{}, wait *sync.WaitGroup, stats *Stat, files []string) {
    mutex := sync.Mutex{}
    for i := range count {
        go func() {
            idx := rand.Int() % len(files)
            r := files[idx]

            <-ch
            out, err := req.ClientRequest(r)
            if err != nil {
                fmt.Printf("Error %s\nskipping request %d: %s\n", err, i, r)
                ch <- struct{}{}
                return
            }


            ch <- struct{}{}

            mutex.Lock()
            stats.Prompt += out.Timings.PromptMS
            stats.Predict += out.Timings.PredictedMS
            stats.Count += 1
            mutex.Unlock()
            wait.Done()

            fmt.Printf("finished: %d\n", i)
        }()
    }
}

func main() {
    var concurrent int
    var completionRequests int
    flag.IntVar(&concurrent, "q", 1, "the amount of concurrent autocomplete requests")
    flag.IntVar(&completionRequests, "c", 1000, "the amount of completion requests to make")
    flag.Parse()

    files := readAllFiles()
    wait := sync.WaitGroup{}
    wait.Add(completionRequests)
    makeRequest := make(chan struct{}, concurrent)
    for range concurrent {
        makeRequest <- struct{}{}
    }

    stats := &Stat{}

    go request(completionRequests, makeRequest, &wait, stats, files)
    wait.Wait()

    defer close(makeRequest)

    stats.Print()
}

