package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"

	"theprimeagen.tv/cmd/pkg/req"
)

type Req struct {
}

func main() {
    http.Handle("/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        body, err := io.ReadAll(r.Body)
        if err != nil {
            log.Fatalf("YOU GOT AN ERROR DUMMY: %s\n", err)
        }

        fmt.Printf("request: %s\n", string(body))
        var cr req.Prompt
        err = json.Unmarshal(body, &cr)
        if err != nil {
            log.Fatalf("YOU GOT AN ERROR DUMMY BECAUSE YOU DUMB: %s\n", err)
        }

        data := req.RequestLlama(cr)
        fmt.Printf("llama response: %s\n", string(data.Bytes()))
        w.Write(data.Bytes())
    }))

    log.Fatal(http.ListenAndServe(":42069", nil))
}

