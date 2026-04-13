//! Interface which each view of the app should implement

const App = @import("../App.zig");

frame: *const fn (*App) void,
