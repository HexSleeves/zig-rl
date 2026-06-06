const std = @import("std");

/// ABGR (0xAABBGGRR) colors — matches zgui draw-list expectations.
pub const Palette = struct {
    background: u32 = 0xFF120A06, // #060A12
    panel: u32 = 0xFF22140C, // #0C1422
    map_void: u32 = 0xFF18100A, // #0A1018
    text: u32 = 0xFFE8D49F, // #9FD4E8
    bright: u32 = 0xFFFEFF73, // #73FFFE
    accent: u32 = 0xFFFFA85F, // #5FA8FF
    dim: u32 = 0xFF66503A, // #3A5066
    border: u32 = 0xFF785A2C, // #2C5A78
    wall: u32 = 0xFF653E38, // #383E65
};

pub const palette = Palette{};

pub const AlertState = enum { nominal, caution, elevated, alert, lockdown };

const ramp_nominal: u32 = 0xFF66FF33; // #33FF66
const ramp_caution: u32 = 0xFF00CCFF; // #FFCC00
const ramp_elevated: u32 = 0xFF1E8AFF; // #FF8A1E
const ramp_alert: u32 = 0xFF303BFF; // #FF3B30
const ramp_lockdown: u32 = 0xFF2010C8; // #C81020

pub fn alertState(level: u8) AlertState {
    if (level >= 80) return .lockdown;
    if (level >= 70) return .alert;
    if (level >= 40) return .elevated;
    if (level >= 1) return .caution;
    return .nominal;
}

/// Component-wise lerp of two ABGR colors. t in [0,1].
pub fn lerp(a: u32, b: u32, t: f32) u32 {
    const tc = std.math.clamp(t, 0.0, 1.0);
    var out: u32 = 0;
    inline for (.{ 0, 8, 16, 24 }) |shift| {
        const ca: f32 = @floatFromInt((a >> shift) & 0xFF);
        const cb: f32 = @floatFromInt((b >> shift) & 0xFF);
        const cv: u32 = @intFromFloat(@round(ca + (cb - ca) * tc));
        out |= (cv & 0xFF) << shift;
    }
    return out;
}

/// Interpolated hazard color for the current alert level (0..100).
pub fn alertTint(level: u8) u32 {
    const l: f32 = @floatFromInt(level);
    if (level < 40) return lerp(ramp_nominal, ramp_caution, l / 40.0);
    if (level < 70) return lerp(ramp_caution, ramp_elevated, (l - 40.0) / 30.0);
    if (level < 80) return lerp(ramp_elevated, ramp_alert, (l - 70.0) / 10.0);
    return lerp(ramp_alert, ramp_lockdown, std.math.clamp((l - 80.0) / 20.0, 0.0, 1.0));
}

/// Dim a color toward black by factor (0=black, 1=unchanged), keeping alpha.
pub fn dim(c: u32, factor: f32) u32 {
    const f = std.math.clamp(factor, 0.0, 1.0);
    var out: u32 = c & 0xFF000000;
    inline for (.{ 0, 8, 16 }) |shift| {
        const cv: f32 = @floatFromInt((c >> shift) & 0xFF);
        const nv: u32 = @intFromFloat(@round(cv * f));
        out |= (nv & 0xFF) << shift;
    }
    return out;
}

pub fn withAlpha(c: u32, alpha: u8) u32 {
    return (c & 0x00FFFFFF) | (@as(u32, alpha) << 24);
}

test "alertState thresholds" {
    try std.testing.expectEqual(AlertState.nominal, alertState(0));
    try std.testing.expectEqual(AlertState.caution, alertState(1));
    try std.testing.expectEqual(AlertState.caution, alertState(39));
    try std.testing.expectEqual(AlertState.elevated, alertState(40));
    try std.testing.expectEqual(AlertState.elevated, alertState(69));
    try std.testing.expectEqual(AlertState.alert, alertState(70));
    try std.testing.expectEqual(AlertState.alert, alertState(79));
    try std.testing.expectEqual(AlertState.lockdown, alertState(80));
    try std.testing.expectEqual(AlertState.lockdown, alertState(100));
}

test "alertTint anchors" {
    try std.testing.expectEqual(ramp_nominal, alertTint(0));
    try std.testing.expectEqual(ramp_caution, alertTint(40));
    try std.testing.expectEqual(ramp_elevated, alertTint(70));
    try std.testing.expectEqual(ramp_alert, alertTint(80));
    try std.testing.expectEqual(ramp_lockdown, alertTint(100));
}

test "lerp endpoints and midpoint" {
    try std.testing.expectEqual(@as(u32, 0xFF000000), lerp(0xFF000000, 0xFFFFFFFF, 0.0));
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), lerp(0xFF000000, 0xFFFFFFFF, 1.0));
    try std.testing.expectEqual(@as(u32, 0xFF808080), lerp(0xFF000000, 0xFFFFFFFF, 0.5));
}

test "dim halves channels, keeps alpha" {
    try std.testing.expectEqual(@as(u32, 0xFF804020), dim(0xFFFF8040, 0.5));
}
