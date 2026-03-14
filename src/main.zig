const std = @import("std");
const url_builder = @import("url_builder");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // GitHub repository search — same as JS URLSearchParams example
    var b = try url_builder.UrlBuilder.init(allocator, "https://api.github.com");
    defer b.deinit();

    try b.setPath("/search/repositories");
    try b.addParam("q", "zig language");
    try b.addParam("sort", "stars");
    try b.addParam("order", "desc");
    try b.addParam("per_page", "30");
    try b.addParam("page", "1");

    const url = try b.build();
    defer allocator.free(url);

    std.debug.print("{s}\n", .{url});

    // Multi-value params example
    var b2 = try url_builder.UrlBuilder.init(allocator, "https://example.com");
    defer b2.deinit();

    try b2.setPath("/search");
    try b2.addParam("tag", "zig");
    try b2.addParam("tag", "systems");
    try b2.addParam("tag", "c");

    const url2 = try b2.build();
    defer allocator.free(url2);

    std.debug.print("{s}\n", .{url2});
}
