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

There is an amazing program called [ccgo](https://pkg.go.dev/modernc.org/ccgo/v3). This is a transpiler that converts C code to Go. It was used to compile the source code of PCRE2 to Go. 

Unfortunately, `ccgo` does create OS and CPU architecture-specific code but I only have `linux/amd64` and `linux/arm64` systems, so I used various C cross-compiler toolchains to compile to the desired target, then used `qemu-user-static` to emulate the CPU arcitectures in order to test the cross-compiled code.

For macOS, the process was a little more complicated. Since there isn't a straightforward cross-compile toolchain for macOS from Linux as far as I know, I ran a macOS VM, which I created using this project: https://github.com/kholia/OSX-KVM. With that VM, I transpiled PCRE2 to both `darwin/amd64` and `darwin/arm64`.

## Why

The reason I created this is that Go's standard library [`regexp`](https://pkg.go.dev/regexp) is missing features such as lookaheads and lookbehinds. There is a good reason for this. Due to the omission of those features, Go's `regexp` library can guarantee that regular expressions cannot be exploited for a DoS attack, known as a ReDoS attack.

This seems like a big deal, and it is in many cases, but not in all cases. For example, if the expression is compiled into the program or provided in a config file, the source is trusted and therefore can be used without worrying about DoS attacks. Some applications also require the features in order to function properly, and they might have a different way to ensure no DoS attack occurs. In these cases, PCRE2 provides extra features without sacrificing anything. This is why I made this project, to allow these use cases to exist.

It also mimics the standard library as closely as possible, meaning it can be used in conjunction with interfaces to provide different regular expression engines based on input, which may be useful in some cases.

## When not to use

Due to the extra features such as lookaheads and lookbehinds, PCRE2 is vulnerable to an attack known as ReDoS. This is where an expression is provided that recurses infinitely, consuming resources forever until there are none left for anything else. This means, if you don't need the features and can't trust the source of the expression, do not use this. Use Go's standard library `regexp` instead.