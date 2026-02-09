const std = @import("std");
const builtin = @import("builtin");

const MAX_INDEX = 99;

fn getEnv(allocator: std.mem.Allocator, env_map: *const std.process.EnvMap, key: []const u8, default_value: []const u8) ![]const u8 {
    if (env_map.get(key)) |val| {
        if (val.len > 0) {
            return try allocator.dupe(u8, val);
        }
    }
    return try allocator.dupe(u8, default_value);
}

fn buildList(allocator: std.mem.Allocator, env_map: *const std.process.EnvMap, prefix: []const u8, default_first: []const u8) ![]const u8 {
    var list: std.ArrayList(u8) = .{};
    defer list.deinit(allocator);
    
    var i: u32 = 0;
    var first = true;
    
    while (i <= MAX_INDEX) : (i += 1) {
        var key_buf: [256]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "{s}__{d}", .{ prefix, i });
        
        var val: []const u8 = "";
        if (env_map.get(key)) |env_val| {
            if (env_val.len > 0) {
                val = env_val;
            }
        }
        
        if (i == 0 and val.len == 0 and default_first.len > 0) {
            val = default_first;
        }
        
        if (val.len > 0) {
            if (!first) {
                try list.writer(allocator).writeAll("\n");
            }
            try list.writer(allocator).print("- {s}", .{val});
            first = false;
        }
    }
    
    if (first and default_first.len > 0) {
        try list.writer(allocator).print("- {s}", .{default_first});
    }
    
    return try list.toOwnedSlice(allocator);
}

fn buildUpstreamList(allocator: std.mem.Allocator, env_map: *const std.process.EnvMap) ![]const u8 {
    var list: std.ArrayList(u8) = .{};
    defer list.deinit(allocator);
    
    var i: u32 = 0;
    var first = true;
    
    while (i <= MAX_INDEX) : (i += 1) {
        var address_key_buf: [256]u8 = undefined;
        const address_key = try std.fmt.bufPrint(&address_key_buf, "STUBBY__UPSTREAM_RECURSIVE_SERVERS__{d}__ADDRESS_DATA", .{i});
        
        var address_data: []const u8 = "";
        if (env_map.get(address_key)) |env_val| {
            if (env_val.len > 0) {
                address_data = env_val;
            }
        }
        
        if (i == 0 and address_data.len == 0) {
            address_data = "194.242.2.2";
        }
        
        if (address_data.len > 0) {
            if (!first) {
                try list.writer(allocator).writeAll("\n");
            }
            try list.writer(allocator).print("- address_data: {s}", .{address_data});
            
            var tls_port_key_buf: [256]u8 = undefined;
            const tls_port_key = try std.fmt.bufPrint(&tls_port_key_buf, "STUBBY__UPSTREAM_RECURSIVE_SERVERS__{d}__TLS_PORT", .{i});
            
            var tls_port: []const u8 = "";
            if (env_map.get(tls_port_key)) |env_val| {
                if (env_val.len > 0) {
                    tls_port = env_val;
                }
            }
            
            if (tls_port.len > 0) {
                try list.writer(allocator).print("\n  tls_port: {s}", .{tls_port});
            } else if (i == 0) {
                try list.writer(allocator).writeAll("\n  tls_port: 853");
            }
            
            var tls_auth_key_buf: [256]u8 = undefined;
            const tls_auth_key = try std.fmt.bufPrint(&tls_auth_key_buf, "STUBBY__UPSTREAM_RECURSIVE_SERVERS__{d}__TLS_AUTH_NAME", .{i});
            
            var tls_auth: []const u8 = "";
            if (env_map.get(tls_auth_key)) |env_val| {
                if (env_val.len > 0) {
                    tls_auth = env_val;
                }
            }
            
            if (tls_auth.len > 0) {
                try list.writer(allocator).print("\n  tls_auth_name: \"{s}\"", .{tls_auth});
            } else if (i == 0) {
                try list.writer(allocator).writeAll("\n  tls_auth_name: \"dns.mullvad.net\"");
            }
            
            first = false;
        }
    }
    
    if (first) {
        try list.writer(allocator).writeAll("- address_data: 194.242.2.2\n  tls_port: 853\n  tls_auth_name: \"dns.mullvad.net\"");
    }
    
    return try list.toOwnedSlice(allocator);
}

fn buildDNSSECTrustAnchors(allocator: std.mem.Allocator, env_map: *const std.process.EnvMap) ![]const u8 {
    var list: std.ArrayList(u8) = .{};
    defer list.deinit(allocator);
    
    var i: u32 = 0;
    var first = true;
    
    while (i <= MAX_INDEX) : (i += 1) {
        var key_buf: [256]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "STUBBY__DNSSEC_TRUST_ANCHORS__{d}", .{i});
        
        if (env_map.get(key)) |val| {
            if (val.len > 0) {
                if (first) {
                    try list.writer(allocator).writeAll("dnssec_trust_anchors:\n");
                    first = false;
                }
                try list.writer(allocator).print("  - \"{s}\"\n", .{val});
            }
        }
    }
    
    return try list.toOwnedSlice(allocator);
}

fn replacePlaceholder(allocator: std.mem.Allocator, content: []const u8, placeholder: []const u8, replacement: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    defer result.deinit(allocator);
    
    var i: usize = 0;
    while (i < content.len) {
        if (std.mem.indexOf(u8, content[i..], placeholder)) |pos| {
            try result.writer(allocator).writeAll(content[i..][0..pos]);
            try result.writer(allocator).writeAll(replacement);
            i += pos + placeholder.len;
        } else {
            try result.writer(allocator).writeAll(content[i..]);
            break;
        }
    }
    
    return try result.toOwnedSlice(allocator);
}

fn replaceMultilinePlaceholder(allocator: std.mem.Allocator, content: []const u8, placeholder: []const u8, replacement: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    defer result.deinit(allocator);
    
    var lines = std.mem.splitSequence(u8, content, "\n");
    var first_line = true;
    
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, placeholder)) |_| {
            var indent: usize = 0;
            while (indent < line.len and (line[indent] == ' ' or line[indent] == '\t')) {
                indent += 1;
            }
            
            var replacement_lines = std.mem.splitSequence(u8, replacement, "\n");
            var first_replacement = true;
            
            while (replacement_lines.next()) |repl_line| {
                if (!first_line or !first_replacement) {
                    try result.writer(allocator).writeAll("\n");
                }
                
                if (repl_line.len > 0) {
                    var j: usize = 0;
                    while (j < indent) : (j += 1) {
                        try result.writer(allocator).writeAll(" ");
                    }
                    try result.writer(allocator).writeAll(repl_line);
                }
                first_replacement = false;
                first_line = false;
            }
        } else {
            if (!first_line) {
                try result.writer(allocator).writeAll("\n");
            }
            try result.writer(allocator).writeAll(line);
            first_line = false;
        }
    }
    
    return try result.toOwnedSlice(allocator);
}

fn replaceDNSSECTrustAnchors(allocator: std.mem.Allocator, content: []const u8, trust_anchors: []const u8) ![]u8 {
    const placeholder = "# __DNSSEC_TRUST_ANCHORS__";
    
    if (trust_anchors.len == 0) {
        var result: std.ArrayList(u8) = .{};
        defer result.deinit(allocator);
        
        var lines = std.mem.splitSequence(u8, content, "\n");
        var first = true;
        
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, placeholder) == null) {
                if (!first) {
                    try result.writer(allocator).writeAll("\n");
                }
                try result.writer(allocator).writeAll(line);
                first = false;
            }
        }
        
        return try result.toOwnedSlice(allocator);
    } else {
        return replacePlaceholder(allocator, content, placeholder, trust_anchors);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();
    
    const template_path = try getEnv(allocator, &env, "TEMPLATE", "/etc/stubby/stubby.yml.template");
    defer allocator.free(template_path);
    
    const conf_path = try getEnv(allocator, &env, "CONF", "/etc/stubby/stubby.yml");
    defer allocator.free(conf_path);
    
    const template_content = try std.fs.cwd().readFileAlloc(allocator, template_path, 1024 * 1024);
    defer allocator.free(template_content);
    
    var content: []u8 = try allocator.dupe(u8, template_content);
    defer allocator.free(content);
    
    const log_level = try getEnv(allocator, &env, "STUBBY__LOG_LEVEL", "GETDNS_LOG_ERR");
    defer allocator.free(log_level);
    content = try replacePlaceholder(allocator, content, "__LOG_LEVEL__", log_level);
    defer allocator.free(content);
    
    const idle_timeout = try getEnv(allocator, &env, "STUBBY__IDLE_TIMEOUT", "10000");
    defer allocator.free(idle_timeout);
    content = try replacePlaceholder(allocator, content, "__IDLE_TIMEOUT__", idle_timeout);
    defer allocator.free(content);
    
    const edns_client_subnet_private = try getEnv(allocator, &env, "STUBBY__EDNS_CLIENT_SUBNET_PRIVATE", "1");
    defer allocator.free(edns_client_subnet_private);
    content = try replacePlaceholder(allocator, content, "__EDNS_CLIENT_SUBNET_PRIVATE__", edns_client_subnet_private);
    defer allocator.free(content);
    
    const round_robin_upstreams = try getEnv(allocator, &env, "STUBBY__ROUND_ROBIN_UPSTREAMS", "0");
    defer allocator.free(round_robin_upstreams);
    content = try replacePlaceholder(allocator, content, "__ROUND_ROBIN_UPSTREAMS__", round_robin_upstreams);
    defer allocator.free(content);
    
    const tls_authentication = try getEnv(allocator, &env, "STUBBY__TLS_AUTHENTICATION", "GETDNS_AUTHENTICATION_REQUIRED");
    defer allocator.free(tls_authentication);
    content = try replacePlaceholder(allocator, content, "__TLS_AUTHENTICATION__", tls_authentication);
    defer allocator.free(content);
    
    const tls_query_padding_blocksize = try getEnv(allocator, &env, "STUBBY__TLS_QUERY_PADDING_BLOCKSIZE", "256");
    defer allocator.free(tls_query_padding_blocksize);
    content = try replacePlaceholder(allocator, content, "__TLS_QUERY_PADDING_BLOCKSIZE__", tls_query_padding_blocksize);
    defer allocator.free(content);
    
    const tls_min_version = try getEnv(allocator, &env, "STUBBY__TLS_MIN_VERSION", "GETDNS_TLS1_2");
    defer allocator.free(tls_min_version);
    content = try replacePlaceholder(allocator, content, "__TLS_MIN_VERSION__", tls_min_version);
    defer allocator.free(content);
    
    const tls_max_version = try getEnv(allocator, &env, "STUBBY__TLS_MAX_VERSION", "GETDNS_TLS1_3");
    defer allocator.free(tls_max_version);
    content = try replacePlaceholder(allocator, content, "__TLS_MAX_VERSION__", tls_max_version);
    defer allocator.free(content);
    
    const dnssec = try getEnv(allocator, &env, "STUBBY__DNSSEC", "GETDNS_EXTENSION_TRUE");
    defer allocator.free(dnssec);
    content = try replacePlaceholder(allocator, content, "__DNSSEC__", dnssec);
    defer allocator.free(content);
    
    const dnssec_return_status = try getEnv(allocator, &env, "STUBBY__DNSSEC_RETURN_STATUS", "GETDNS_EXTENSION_TRUE");
    defer allocator.free(dnssec_return_status);
    content = try replacePlaceholder(allocator, content, "__DNSSEC_RETURN_STATUS__", dnssec_return_status);
    defer allocator.free(content);
    
    const dns_transport_list = try buildList(allocator, &env, "STUBBY__DNS_TRANSPORT_LIST", "GETDNS_TRANSPORT_TLS");
    defer allocator.free(dns_transport_list);
    content = try replaceMultilinePlaceholder(allocator, content, "__DNS_TRANSPORT_LIST__", dns_transport_list);
    defer allocator.free(content);
    
    const listen_addresses = try buildList(allocator, &env, "STUBBY__LISTEN_ADDRESSES", "0.0.0.0@8053");
    defer allocator.free(listen_addresses);
    content = try replaceMultilinePlaceholder(allocator, content, "__LISTEN_ADDRESSES__", listen_addresses);
    defer allocator.free(content);
    
    const upstream_recursive_servers = try buildUpstreamList(allocator, &env);
    defer allocator.free(upstream_recursive_servers);
    content = try replaceMultilinePlaceholder(allocator, content, "__UPSTREAM_RECURSIVE_SERVERS__", upstream_recursive_servers);
    defer allocator.free(content);
    
    const trust_anchors = try buildDNSSECTrustAnchors(allocator, &env);
    defer allocator.free(trust_anchors);
    content = try replaceDNSSECTrustAnchors(allocator, content, trust_anchors);
    defer allocator.free(content);
    
    const conf_dir = std.fs.path.dirname(conf_path) orelse "/etc/stubby";
    try std.fs.cwd().makePath(conf_dir);
    
    try std.fs.cwd().writeFile(.{ .sub_path = conf_path, .data = content });
    
    const stubby_path = "/usr/bin/stubby";
    const args = [_][]const u8{ stubby_path, "-C", conf_path, "-l" };
    
    var env_strings: std.ArrayList(?[*:0]u8) = .{};
    var env_slices: std.ArrayList([]u8) = .{};
    defer {
        for (env_slices.items) |slice| {
            allocator.free(slice);
        }
        env_slices.deinit(allocator);
        env_strings.deinit(allocator);
    }
    
    var env_iterator = env.iterator();
    while (env_iterator.next()) |entry| {
        const env_str_slice = try std.fmt.allocPrint(allocator, "{s}={s}", .{ entry.key_ptr.*, entry.value_ptr.* });
        defer allocator.free(env_str_slice);
        const env_str = try allocator.alloc(u8, env_str_slice.len + 1);
        @memcpy(env_str[0..env_str_slice.len], env_str_slice);
        env_str[env_str_slice.len] = 0;
        const env_str_ptr: [*:0]u8 = @ptrCast(env_str.ptr);
        try env_strings.append(allocator, env_str_ptr);
        try env_slices.append(allocator, env_str);
    }
    try env_strings.append(allocator, null);
    
    var args_z: std.ArrayList(?[*:0]const u8) = .{};
    var args_slices: std.ArrayList([]u8) = .{};
    defer {
        for (args_slices.items) |slice| {
            allocator.free(slice);
        }
        args_slices.deinit(allocator);
        args_z.deinit(allocator);
    }
    
    for (args) |arg| {
        const arg_slice = try allocator.alloc(u8, arg.len + 1);
        @memcpy(arg_slice[0..arg.len], arg);
        arg_slice[arg.len] = 0;
        const arg_ptr: [*:0]const u8 = @ptrCast(arg_slice.ptr);
        try args_z.append(allocator, arg_ptr);
        try args_slices.append(allocator, arg_slice);
    }
    try args_z.append(allocator, null);
    
    const path_slice = try allocator.alloc(u8, stubby_path.len + 1);
    @memcpy(path_slice[0..stubby_path.len], stubby_path);
    path_slice[stubby_path.len] = 0;
    defer allocator.free(path_slice);
    const path_ptr: [*:0]const u8 = @ptrCast(path_slice.ptr);
    
    const args_ptr: [*:null]const ?[*:0]const u8 = @ptrCast(args_z.items.ptr);
    const env_ptr: [*:null]const ?[*:0]u8 = @ptrCast(env_strings.items.ptr);
    _ = std.os.linux.execve(path_ptr, args_ptr, env_ptr);
    return error.ExecveFailed;
}
