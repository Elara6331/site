+++
title = "LRPC"
date = "2022-09-13"
showSummary = true
summary = "Lightweight, simple RPC framework for Go"
weight = 20
+++

## About

LRPC stands for Lightweight RPC. It is a very lightweight RPC framework that is designed to be as idiomatic and easy to use as possible in Go.

To add a new function, simply create a type and define a method on it, like so:

```go
package main

import (
    "fmt"
    "time"
    "strconv"
    "go.arsenm.dev/lrpc/server"
    "go.arsenm.dev/lrpc/codec"
)

type RPC struct{}

// No arguments, no return values, no error, no channel
func (RPC) Hello(_ *server.Context) {
    fmt.Println("Hello, World")
}

// 1 argument, no return values, no error, no channel
func (RPC) Hello(_ *server.Context, name string) {
    fmt.Println("Hello,", name)
}

// 1 argument, 1 return value, no error, no channel
func (RPC) Hello(_ *server.Context, name string) string {
    return "Hello, " + name
}

// 1 argument, 1 return value, with error, no channel
func (RPC) Atoi(_ *server.Context, num string) (int, error) {
    return strconv.Atoi(num)
}

// 1 argument, 0 return values, with error, with channel
// (client-terminated)
func (RPC) Nums(ctx *server.Context, num int) error {
    ch, err := ctx.MakeChannel()

    go func() {
        for {
            select {
            case <-time.After(time.Second):
                ch <- num
                num++
            case <-ctx.Done(): // Signal received when client cancels their context
                return
            }
        }
    }()
    
    return nil
}

// 1 argument, 0 return values, with error, with channel
// (server-terminated)
func (RPC) Nums(ctx *server.Context, amount int) error {
    ch, err := ctx.MakeChannel()

    for i := 0; i < amount; i++ {
        ch <- i
        time.Sleep(time.Second)
    }

    // Sends a signal to the client, closing the channel
    // on the client-side as well.
    close(ch)
    
    return nil
}
```

Then, it can be simply run like so:

```go
func main() {
    ctx := context.Background()
    srv := server.New()

    err := srv.Register(RPC{})
    if err != nil {
        panic(err)
    }

    ln, err := net.Listen("tcp", ":8080")
    if err != nil {
        panic(err)
    }

    srv.Serve(ctx, ln, codec.Default) // Default is Msgpack
}
```

## Why

The reason I made LRPC is that I used to simply read JSON messages from a socket for ITD, but that was quickly becoming unmaintainable as more and more features were added. Therefore, I decided to switch to an RPC framework. 

Seeing as Go's `net/rpc` was [frozen](https://github.com/golang/go/issues/16844), I decided to look for a different one, and found [RPCX](https://github.com/smallnest/rpcx). Upon importing it, I noticed that it added a ridiculous 7MB to my binary. Two days later, LRPC was born. It's extremely lightweight, because it omits most of the features RPCX has, since I didn't need them anyway. Also, I needed a feature like the channels I implemented, and while RPCX was capable of doing something similar, it was very ugly and didn't work very well.
