+++
title = "PCRE"
date = "2022-09-13"
showSummary = true
summary = "CGo-free port of PCRE2 to the Go programming language"
weight = 10
+++

## About

[PCRE](https://gitea.arsenm.dev/Arsen6331/pcre) is a CGo-free port of the PCRE2 regular expression engine to Go. Being CGo-free means that rather than just being bindings to the PCRE2 library, this is a pure Go implementation of PCRE2.

## How it works

The implementation leverages a remarkable tool known as [ccgo](https://pkg.go.dev/modernc.org/ccgo/v3), which is a compiler that converts C code into Go. The source code of PCRE2 was converted to Go using `ccgo`. I only have `linux/amd64` and `linux/arm64` systems, so cross-compilation using various C toolchains was performed and tested using `qemu-user-static` to emulate the desired CPU architectures.

For macOS, the process was more intricate as there is no suitable cross-compilation toolchain from Linux. Therefore, a macOS Virtual Machine was created using [OSX-KVM](https://github.com/kholia/OSX-KVM) and used to build PCRE2 for `darwin/amd64` and `darwin/arm64`.

Once the code was converted, a memory-safe interface was created on top of it. This interface adheres to the conventions used in Go's standard library `regexp` package, so it can be used as a drop-in replacement.

## Motivation

Go's standard library [`regexp`](https://pkg.go.dev/regexp) package lacks features like lookaheads and lookbehinds. This was intentional, as it guarantees that regular expressions cannot be exploited for a Denial-of-Service (DoS) attack, known as a ReDoS attack. However, there are cases where these features are necessary, and the expression is compiled into the program or provided in a configuration file, so the source is trusted.

## When to avoid

It is important to note that PCRE2 is vulnerable to ReDoS attacks because of its extra features, such as lookaheads and lookbehinds. If the source of the expression cannot be trusted, it is advisable not to use PCRE2, and instead use the Go standard library `regexp` package.