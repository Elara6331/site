+++
title = "Using Go's runtime/cgo to pass values between C and Go"
date = "2022-09-22"
summary = "Calling C code from Go (or Go code from C) presents certain challenges, especially when Go values need to be used by C. This article discusses the `runtime/cgo` package added in Go 1.17 and how it can be used to solve these challenges."
+++

## The problem

Often, I come across a complex problem that I can't solve myself. This is the purpose of libraries, so just import one and you're done, right? Well, that works, until you come across a problem for which a library hasn't been written in your language (Go, in this case). What if you could use a library from another language, such as C, in your Go program.

This is what CGo is for. It is a Foreign Function Interface, meaning it allows you to call functions from another language. CGo calls functions from C. The issue is that, since C is a completely separate language from Go, it has its own rules for how it expects things to be done.

This limitation also means that C doesn't know how to handle a value from Go. Such values must be converted to values that can be understood by C. For example, if you have a `string` in Go, you can't simply pass that to C. It must be converted to a `*C.char` before doing so, since C doesn't know about Go's `string` type.

Here, we come across some challenges. Let's say you want your C library to do some processing and then call a method on a struct with the results of the operation. How do you pass a struct to C so that it can call a method? And how do you even call the method when C doesn't have methods? Well, `runtime/cgo` is the perfect solution for this.

There are two problems here. First of all, as I said, C doesn't understand Go's values and doesn't even have methods. Second, Go is a garbage-collected language. This means that it'll automatically clean up unused data (garbage) by deleting (collecting) it. Unfortunately, C has no way to know when this happens and Go has no way to know if C needs the value, so anything passed to C should not be collected until it's done using it.

## How does `runtime/cgo` help?

[`runtime/cgo`](https://pkg.go.dev/runtime/cgo) is a package added in Go 1.17, and its purpose is to solve exactly the problems I discussed above. It has a [`NewHandle()`](https://pkg.go.dev/runtime/cgo#NewHandle) method that takes any value and returns a [`Handle`](https://pkg.go.dev/runtime/cgo#Handle), which has the underlying type `uintptr`. This means it can be converted to a `C.uintptr_t`, which C can understand.

Internally, `NewHandle()` creates a unique integer for the value you've passed in, and holds a reference to it. This integer is what is returned by the function. Holding a reference to the value means the garbage collector will leave the value alone because it will believe that the value is always in use. So, problem solved, right? Well, kind of. We now have a `Handle`, which is an integer, but how do we call a method on an integer?

## How to use it

So, first, let's say we have a Go program like this:

```go
package main

import (
    "runtime/cgo"
    "fmt"
)

// #include <stdint.h>
import "C"

type Result struct {
    value1 int16
    value2 int64
    value3 uint32
}

func (r *Result) Set(val1 int16, val2 int64, val3 uint32) {
    r.value1 = val1
    r.value2 = val2
    r.value3 = val3
}

func (r *Result) String() string {
    return fmt.Sprintf("1: %d, 2: %d, 3: %d", r.value1, r.value2, r.value3)
}
```

Now, let's say we want our C library to provide these results, set them, and then print the string returned by `*Result.String()`. How do we do this with `runtime/cgo`?

First of all, we need a way for our C library to create a new `Result` value. We'd do this in Go using a `NewResult()` function, and we'll do the same here, but using handles instead of returning the value directly:

```go
//export CNewResult
func CNewResult() C.uintptr_t {
    result := &Result{}
    handle := cgo.NewHandle(result)
    return C.uintptr_t(handle)
}
```

This function creates a new `*Result` using `&Result{}`. Then, it creates a new handle for this value using `cgo.NewHandle()`. This handle is a `uintptr` as I mentioned above, so it can be converted to C's `C.uintptr_t` and returned.

Now we have a number corresponding to our `Result` value, but how do we call a method? Since C doesn't have methods, we'll need to create functions that call them from Go, but since C also doesn't have direct access to the value, we'll have to get it back out from the handle. Since Go is still holding onto the value, we just convert the `C.uintptr_t` back into a `Handle` and get its value. It'll return an interface{}, so we'll want to use a type assertion to get back the `*Result`.

```go
//export CResultSet
func CResultSet(handle C.uintptr_t, val1 C.int16_t, val2 C.int64_t, val3 C.uint32_t) {
    // Get the *Result back
    result := cgo.Handle(handle).Value().(*Result)
    // Call the method we wanted to use from C,
    // converting the C values back to Go values.
    result.Set(int16(val1), int64(val2), uint32(val3))
}

//export CResultString
func CResultString(handle C.uintptr_t) *C.char {
    // Get the *Result back
    result := cgo.Handle(handle).Value().(*Result)
    // Call the method we wanted to use from C,
    str := result.String()
    // Since string is a Go type, we'll need to convert to C's *C.char
    // using this function that Go includes for us when we import C.
    cStr := C.CString(str)
    return cStr
}
```

As you can see, all you need to do is

```go
result := cgo.Handle(handle).Value().(*Result)
```

and you get the value back from C to do whatever you need.

Now, there's one more issue. As I mentioned before, Go is a garbage-collected language. What we did with the handles stopped the value from being garbage collected so that C could use it without worrying that it might be collected by the garbage collector. The issue is that since our value is no longer being deleted, if we keep making new ones, they'll just fill up the computer's RAM for no reason. To solve this, `Handle` has a method called `Delete()`, which removes the reference that `runtime/cgo` was holding onto, allowing the garbage collector to collect the value again. We need to call this from C so that it can notify us when it's done with the value.

```go
//export CFreeResult
func CFreeResult(handle C.uintptr_t) {
    cgo.Handle(handle).Delete()
}
```

That's it. Using what we have created from C is pretty easy. Simply call the functions we created:

```c
// Go creates this file for us. It contains all the exported functions.
#include "_cgo_export.h"

#include <stdint.h>
#include <stdio.h>

void foo() {
    uintptr_t result = CNewResult();
    CResultSet(result, -1, 123, 456);
    char* str = CResultString(result);
    printf("%s\n", str);
    CFreeResult(result);
}
```

Calling the `foo()` function should print:

```text
1: -1, 2: 123, 3: 456
```