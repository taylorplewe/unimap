//! Interface which each view of the app should implement

const App = @import("../App.zig");

doFrame: *const fn (*App) void,
