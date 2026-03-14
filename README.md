<div align="center">

[![Zig](https://img.shields.io/badge/Zig-%3E%3D0.15.2-blue?logo=zig&logoColor=white)](https://ziglang.org)
[![Tests](https://img.shields.io/badge/build-passing-brightgreen)](zig%20build%20test)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](LICENSE)

</div>

<hr>
<br>

**url-builder** is a minimal URL builder for [Zig](https://ziglang.org/), inspired by the JS [URLSearchParams](https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams) API. RFC 3986 percent-encoding, zero external dependencies.

**Features:**
- `addParam` — append query params, duplicate keys allowed (`?tag=zig&tag=systems`).
- `setParam` — set/replace a query param by key.
- `setPath` — set the URL path.
- `build` — produce the final URL string (caller owns the memory).
- RFC 3986 percent-encoding for all keys and values.
- Proper memory management (`init` / `deinit`).


## Installation

1. Run `zig fetch` to add the dependency:

```sh
zig fetch --save https://github.com/etroynov/url-builder/archive/refs/tags/0.1.0.tar.gz
```

This will automatically add the entry to your `build.zig.zon`:

```zon
.dependencies = .{
    .url_builder = .{
        .url = "https://github.com/etroynov/url-builder/archive/refs/tags/0.1.0.tar.gz",
        .hash = "<computed by zig fetch>",
    },
},
```

2. In `build.zig` import the module:

```zig
const url_builder_dep = b.dependency("url_builder", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("url_builder", url_builder_dep.module("url_builder"));
```


## Quick Start

```zig
const std = @import("std");
const url_builder = @import("url_builder");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var b = try url_builder.UrlBuilder.init(allocator, "https://api.github.com");
    defer b.deinit();

    try b.setPath("/search/repositories");
    try b.addParam("q", "zig language");
    try b.addParam("sort", "stars");
    try b.addParam("order", "desc");
    try b.addParam("per_page", "30");

    const url = try b.build();
    defer allocator.free(url);

    std.debug.print("{s}\n", .{url});
    // https://api.github.com/search/repositories?q=zig%20language&sort=stars&order=desc&per_page=30
}
```

Run with: `zig build run`

## API

```zig
const url_builder = @import("url_builder");
```

### UrlBuilder

```zig
// Init
var b = try url_builder.UrlBuilder.init(allocator, "https://api.example.com");
defer b.deinit();

// Set path
try b.setPath("/search");

// Add params (duplicates allowed)
try b.addParam("tag", "zig");
try b.addParam("tag", "systems");     // → ?tag=zig&tag=systems

// Set param (replaces first match, or appends)
try b.setParam("sort", "stars");
try b.setParam("sort", "updated");   // → ?sort=updated

// Build URL — caller owns the returned []u8
const url = try b.build();
defer allocator.free(url);
```

### Param

```zig
pub const Param = struct {
    key: []u8,
    value: []u8,
};
```

### percentEncode

```zig
// Percent-encode a string per RFC 3986. Caller owns the returned []u8.
const encoded = try url_builder.percentEncode(allocator, "hello world");
defer allocator.free(encoded);
// → "hello%20world"
```

## Contributing

Contributions are welcome! Please:

1. Fork the repo.
2. Create your feature branch (`git checkout -b feature/foo`).
3. Commit changes (`git commit -am 'Add some foo'`).
4. Push to branch (`git push origin feature/foo`).
5. Create Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file.
