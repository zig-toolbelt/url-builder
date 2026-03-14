//! URL Builder library — construct URLs with query parameters.
//! Follows RFC 3986 percent-encoding for query param keys and values.
const std = @import("std");

pub const Param = struct {
    key: []u8,
    value: []u8,
};

pub const UrlBuilder = struct {
    allocator: std.mem.Allocator,
    base: []u8,
    path: ?[]u8,
    params: std.ArrayList(Param),

    /// Initialize a new UrlBuilder with a base URL.
    /// Copies base — caller may free their copy immediately.
    /// Must call deinit() when done.
    pub fn init(allocator: std.mem.Allocator, base: []const u8) !UrlBuilder {
        return .{
            .allocator = allocator,
            .base = try allocator.dupe(u8, base),
            .path = null,
            .params = .empty,
        };
    }

    /// Free all resources owned by this builder.
    pub fn deinit(self: *UrlBuilder) void {
        self.allocator.free(self.base);
        if (self.path) |p| self.allocator.free(p);
        for (self.params.items) |param| {
            self.allocator.free(param.key);
            self.allocator.free(param.value);
        }
        self.params.deinit(self.allocator);
    }

    /// Set the URL path. Replaces any previously set path.
    pub fn setPath(self: *UrlBuilder, path: []const u8) !void {
        if (self.path) |p| self.allocator.free(p);
        self.path = try self.allocator.dupe(u8, path);
    }

    /// Add a query parameter. Duplicate keys are allowed (?tag=zig&tag=systems).
    pub fn addParam(self: *UrlBuilder, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);
        try self.params.append(self.allocator, .{ .key = key_copy, .value = value_copy });
    }

    /// Set a query parameter. Replaces the first occurrence of key,
    /// or appends a new param if key is not found.
    pub fn setParam(self: *UrlBuilder, key: []const u8, value: []const u8) !void {
        for (self.params.items) |*param| {
            if (std.mem.eql(u8, param.key, key)) {
                self.allocator.free(param.value);
                param.value = try self.allocator.dupe(u8, value);
                return;
            }
        }
        try self.addParam(key, value);
    }

    /// Build the URL string. Caller owns the returned slice.
    /// Does not mutate the builder — safe to call multiple times.
    pub fn build(self: *const UrlBuilder) ![]u8 {
        var buf: std.ArrayList(u8) = .empty;
        errdefer buf.deinit(self.allocator);

        // Base URL: strip trailing slashes
        var base = self.base;
        while (base.len > 0 and base[base.len - 1] == '/') {
            base = base[0 .. base.len - 1];
        }
        try buf.appendSlice(self.allocator, base);

        // Path
        if (self.path) |path| {
            if (path.len > 0) {
                if (path[0] != '/') try buf.append(self.allocator, '/');
                try buf.appendSlice(self.allocator, path);
            }
        }

        // Query params
        if (self.params.items.len > 0) {
            try buf.append(self.allocator, '?');
            for (self.params.items, 0..) |param, i| {
                if (i > 0) try buf.append(self.allocator, '&');

                const enc_key = try percentEncode(self.allocator, param.key);
                defer self.allocator.free(enc_key);
                const enc_val = try percentEncode(self.allocator, param.value);
                defer self.allocator.free(enc_val);

                try buf.appendSlice(self.allocator, enc_key);
                try buf.append(self.allocator, '=');
                try buf.appendSlice(self.allocator, enc_val);
            }
        }

        return buf.toOwnedSlice(self.allocator);
    }
};

/// Percent-encode a string per RFC 3986.
/// Safe chars (not encoded): A-Z a-z 0-9 - _ . ~
/// Caller owns the returned slice.
pub fn percentEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);

    for (input) |c| {
        if (isSafeChar(c)) {
            try buf.append(allocator, c);
        } else {
            try buf.appendSlice(allocator, &.{ '%', nibbleToHex(c >> 4), nibbleToHex(c & 0x0f) });
        }
    }

    return buf.toOwnedSlice(allocator);
}

fn isSafeChar(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => true,
        else => false,
    };
}

fn nibbleToHex(nibble: u8) u8 {
    return if (nibble < 10) '0' + nibble else 'A' + nibble - 10;
}

// ── Tests ────────────────────────────────────────────────────────────────────

test "simple URL — no path, no params" {
    const a = std.testing.allocator;
    var b = try UrlBuilder.init(a, "https://api.github.com");
    defer b.deinit();
    const url = try b.build();
    defer a.free(url);
    try std.testing.expectEqualStrings("https://api.github.com", url);
}

test "URL with path and params" {
    const a = std.testing.allocator;
    var b = try UrlBuilder.init(a, "https://api.github.com");
    defer b.deinit();
    try b.setPath("/search/repositories");
    try b.addParam("q", "zig");
    try b.addParam("sort", "stars");
    const url = try b.build();
    defer a.free(url);
    try std.testing.expectEqualStrings(
        "https://api.github.com/search/repositories?q=zig&sort=stars",
        url,
    );
}

test "percent-encoding: spaces and special chars" {
    const a = std.testing.allocator;
    var b = try UrlBuilder.init(a, "https://example.com");
    defer b.deinit();
    try b.addParam("q", "zig language");
    try b.addParam("filter", "a=b&c=d");
    const url = try b.build();
    defer a.free(url);
    try std.testing.expectEqualStrings(
        "https://example.com?q=zig%20language&filter=a%3Db%26c%3Dd",
        url,
    );
}

test "setParam replaces existing key" {
    const a = std.testing.allocator;
    var b = try UrlBuilder.init(a, "https://example.com");
    defer b.deinit();
    try b.addParam("sort", "stars");
    try b.setParam("sort", "updated");
    const url = try b.build();
    defer a.free(url);
    try std.testing.expectEqualStrings("https://example.com?sort=updated", url);
}

test "addParam allows duplicate keys" {
    const a = std.testing.allocator;
    var b = try UrlBuilder.init(a, "https://example.com");
    defer b.deinit();
    try b.addParam("tag", "zig");
    try b.addParam("tag", "systems");
    const url = try b.build();
    defer a.free(url);
    try std.testing.expectEqualStrings("https://example.com?tag=zig&tag=systems", url);
}

test "base trailing slash + path leading slash — no double slash" {
    const a = std.testing.allocator;
    var b = try UrlBuilder.init(a, "https://example.com/");
    defer b.deinit();
    try b.setPath("/api/v1");
    const url = try b.build();
    defer a.free(url);
    try std.testing.expectEqualStrings("https://example.com/api/v1", url);
}

test "build is non-mutating — safe to call twice" {
    const a = std.testing.allocator;
    var b = try UrlBuilder.init(a, "https://example.com");
    defer b.deinit();
    try b.addParam("q", "zig");
    const url1 = try b.build();
    defer a.free(url1);
    const url2 = try b.build();
    defer a.free(url2);
    try std.testing.expectEqualStrings(url1, url2);
}
