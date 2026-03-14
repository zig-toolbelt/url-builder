//! Consumer-side integration tests.
//! Imports url_builder as an external user would — verifies the public API surface.
const std = @import("std");
const url_builder = @import("url_builder");

test "consumer: GitHub repository search URL" {
    const a = std.testing.allocator;
    var b = try url_builder.UrlBuilder.init(a, "https://api.github.com");
    defer b.deinit();

    try b.setPath("/search/repositories");
    try b.addParam("q", "zig language");
    try b.addParam("sort", "stars");
    try b.addParam("order", "desc");
    try b.addParam("per_page", "30");
    try b.addParam("page", "1");

    const url = try b.build();
    defer a.free(url);

    try std.testing.expectEqualStrings(
        "https://api.github.com/search/repositories?q=zig%20language&sort=stars&order=desc&per_page=30&page=1",
        url,
    );
}

test "consumer: multi-value filter params" {
    const a = std.testing.allocator;
    var b = try url_builder.UrlBuilder.init(a, "https://example.com");
    defer b.deinit();

    try b.setPath("/search");
    try b.addParam("tag", "zig");
    try b.addParam("tag", "systems");
    try b.addParam("tag", "c");

    const url = try b.build();
    defer a.free(url);

    try std.testing.expectEqualStrings(
        "https://example.com/search?tag=zig&tag=systems&tag=c",
        url,
    );
}

test "consumer: percentEncode is accessible" {
    const a = std.testing.allocator;
    const encoded = try url_builder.percentEncode(a, "hello world & more");
    defer a.free(encoded);
    try std.testing.expectEqualStrings("hello%20world%20%26%20more", encoded);
}
