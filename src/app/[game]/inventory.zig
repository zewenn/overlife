const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");
const GUI = e.GUI;

const u = GUI.u;
const toUnit = GUI.toUnit;

const prefabs = @import("items.zig").prefabs;
const usePrefab = @import("items.zig").usePrefab;

const bag_pages: comptime_int = 3;
const bag_page_rows: comptime_int = 4;
const bag_page_cols: comptime_int = 7;
const bag_size: comptime_int = bag_pages * bag_page_rows * bag_page_cols;
const bag_page_size: comptime_int = bag_page_cols * bag_page_rows;

pub const Item = conf.Item;

pub var delete_mode: bool = false;
pub var delete_mode_last_frame: bool = false;

pub var HandsWeapon: Item = undefined;

pub var bag: [bag_size]?conf.Item = [_]?conf.Item{null} ** bag_size;
pub var sorted_bag: []*?conf.Item = undefined;

pub var animation_mapping_dummy: e.entities.Entity = undefined;
pub var dummy_animator: e.Animator = undefined;

pub const equippedbar = struct {
    pub var current_weapon: *Item = &HandsWeapon;
    pub var ring: ?*Item = null;
    pub var amethyst: ?*Item = null;
    pub var wayfinder: ?*Item = null;

    pub fn equip(item: *Item) void {
        switch (item.T) {
            .weapon => {
                unequip(current_weapon);
                current_weapon = item;
            },
            .ring => {
                if (ring != null) unequip(ring.?);
                ring = item;
            },
            .amethyst => {
                if (amethyst != null) unequip(amethyst.?);
                amethyst = item;
            },
            .wayfinder => {
                if (wayfinder != null) unequip(wayfinder.?);
                wayfinder = item;
            },
        }

        item.equipped = true;
    }

    pub fn autoEquip() void {
        for (bag, 0..) |itemornull, index| {
            if (itemornull == null) continue;
            const item: *Item = &(bag[index].?);
            if (!item.equipped) continue;

            equippedbar.equip(item);
        }
    }

    pub fn unequip(item: *Item) void {
        item.equipped = false;
        switch (item.T) {
            .weapon => {
                current_weapon = &HandsWeapon;
                HandsWeapon.equipped = true;
            },
            .ring => ring = null,
            .amethyst => amethyst = null,
            .wayfinder => wayfinder = null,
        }
    }

    pub fn get(comptime T: conf.ItemStats) f32 {
        const fieldname: []const u8 = comptime switch (T) {
            .damage => "damage",
            .health => "health",
            .crit_rate => "crit_rate",
            .crit_damage => "crit_damage",
            .movement_speed => "movement_speed",
            .tenacity => "tenacity",
            .dash_charges => "dash_charges",
        };

        return @field(current_weapon, fieldname) +
            if (ring) |i| @field(i, fieldname) else 0 +
            if (amethyst) |i| @field(i, fieldname) else 0 +
            if (wayfinder) |i| @field(i, fieldname) else 0;
    }
};

var INVENTORY_GUI: *GUI.GUIElement = undefined;
var shown: bool = false;
var bag_element: *GUI.GUIElement = undefined;
var is_preview_heap_loaded = false;
var slots: []*GUI.GUIElement = undefined;

const current_page = struct {
    var value: usize = 0;

    pub fn set(to: usize) void {
        if (to >= bag_pages) return;
        if (to < 0) return;

        value = to;
    }

    pub fn get() usize {
        return value;
    }
};

const SLOT_SIZE: f32 = 5;
const PREVIEW_FONT_COLOR = e.Color.white;

const WIDTH_VW: f32 = SLOT_SIZE * 7 + 6;
const HEIGHT_VW: f32 = SLOT_SIZE * 4 + 3;

const PREVIEW_2x1 = "sprites/gui/preview_2x1.png";
const PREVIEW_4x1 = "sprites/gui/preview_4x1.png";
const PREVIEW_2x2 = "sprites/gui/preview_2x2.png";
const PREVIEW_EPIC_2x2 = "sprites/gui/preview_epic_2x2.png";
const PREVIEW_LEGENDARY_2x2 = "sprites/gui/preview_legendary_2x2.png";

pub const preview = struct {
    var is_shown = false;
    var selected = false;
    var selected_item: ?*Item = null;

    pub var element: *GUI.GUIElement = undefined;

    pub var display: *GUI.GUIElement = undefined;
    pub var display_item: *GUI.GUIElement = undefined;
    pub var level_number: *GUI.GUIElement = undefined;
    pub var name: *GUI.GUIElement = undefined;
    pub var damage: *GUI.GUIElement = undefined;
    pub var health: *GUI.GUIElement = undefined;
    pub var crit_rate: *GUI.GUIElement = undefined;
    pub var crit_damage: *GUI.GUIElement = undefined;
    pub var move_speed: *GUI.GUIElement = undefined;
    pub var attack_speed: *GUI.GUIElement = undefined;
    pub var tenacity: *GUI.GUIElement = undefined;
    pub var upgrade_title_text: *GUI.GUIElement = undefined;
    pub var upgrade_cost_text: *GUI.GUIElement = undefined;
    pub var upgrade_currency_shower: *GUI.GUIElement = undefined;
    pub var equip: *GUI.GUIElement = undefined;

    pub const generic_stat_button_style = GUI.StyleSheet{
        .background = .{
            .image = e.MISSINGNO,
        },
        .width = .{
            .value = SLOT_SIZE * 2 + 1,
            .unit = .vw,
        },
        .height = .{
            .value = (SLOT_SIZE - 1) / 2,
            .unit = .vw,
        },

        .translate = .{
            .x = .min,
            .y = .center,
        },

        .font = .{
            .size = 10,
            .shadow = .{
                .color = e.Color{
                    .r = 100,
                    .g = 100,
                    .b = 100,
                    .a = 255,
                },
                .offset = e.Vec2(2, 2),
            },
        },
    };

    pub fn select() void {
        element = GUI.assertSelect("#item-preview");

        display = GUI.assertSelect("#preview-display");
        display_item = GUI.assertSelect("#preview-display-item");
        level_number = GUI.assertSelect("#preview-level-number");
        name = GUI.assertSelect("#preview-item-name");
        damage = GUI.assertSelect("#preview-damage-number");
        health = GUI.assertSelect("#preview-health-number");
        crit_rate = GUI.assertSelect("#preview-crit-rate-number");
        crit_damage = GUI.assertSelect("#preview-crit-damage-number");
        move_speed = GUI.assertSelect("#preview-move-speed-number");
        attack_speed = GUI.assertSelect("#preview-attack-speed-number");
        tenacity = GUI.assertSelect("#preview-tenacity-number");
        upgrade_title_text = GUI.assertSelect("#preview-upgrade-title");
        upgrade_cost_text = GUI.assertSelect("#preview-upgrade-text");
        upgrade_currency_shower = GUI.assertSelect("#preview-upgrade-currency");
        equip = GUI.assertSelect("#preview-equip-button");

        selected = true;
    }

    pub fn toNamedHeapString(elem: *GUI.GUIElement, string: []const u8, number: f32, percent: bool) !void {
        const named_damage_string = try std.fmt.allocPrint(e.ALLOCATOR, "{s}: {d:.0}{s}", .{ string, number, if (percent) "%" else "" });
        defer e.ALLOCATOR.free(named_damage_string);

        elem.contents = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, named_damage_string);
        elem.is_content_heap = true;
    }

    pub fn show(item: *Item) !void {
        selected_item = item;

        if (!selected) {
            std.log.warn("Element weren't selectedd!", .{});
            select();
        }

        free();

        display.options.style.background.image = switch (item.rarity) {
            .common => PREVIEW_2x2,
            .epic => PREVIEW_EPIC_2x2,
            .legendary => PREVIEW_LEGENDARY_2x2,
        };

        display_item.options.style.background.image = item.icon;

        const level_string = try e.zlib.arrays.NumberToString(e.ALLOCATOR, item.level);
        defer e.ALLOCATOR.free(level_string);

        level_number.contents = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, level_string);
        level_number.is_content_heap = true;

        name.contents = item.name;

        try toNamedHeapString(damage, "DAMAGE", item.damage, false);
        try toNamedHeapString(health, "HEALTH", item.health, false);
        try toNamedHeapString(crit_rate, "CRIT RATE", item.crit_rate, true);
        try toNamedHeapString(crit_damage, "CRIT DMG", item.crit_damage_multiplier, true);
        try toNamedHeapString(move_speed, "MOVE SPEED", item.movement_speed, false);
        try toNamedHeapString(attack_speed, "ATK SPEED", @round(1 / item.attack_speed), false);
        try toNamedHeapString(tenacity, "TENACITY", item.tenacity, false);

        const upgrade_text_string = try e.zlib.arrays.NumberToString(
            e.ALLOCATOR,
            item.base_upgrade_cost + item.cost_per_level * item.level,
        );
        defer e.ALLOCATOR.free(upgrade_text_string);

        upgrade_cost_text.contents = try e.zlib.arrays.toManyItemPointerSentinel(e.ALLOCATOR, upgrade_text_string);
        upgrade_cost_text.is_content_heap = true;

        upgrade_cost_text.options.style.width = .{
            .value = e.loadf32(upgrade_text_string.len) * upgrade_cost_text.options.style.font.size,
            .unit = .px,
        };

        upgrade_cost_text.options.style.left = .{
            .value = -1 * (upgrade_cost_text.options.style.font.size) / 2,
            .unit = .px,
        };

        upgrade_currency_shower.options.style.left = toUnit(
            e.loadf32(upgrade_text_string.len - 1) / 2 * upgrade_cost_text.options.style.font.size,
        );

        upgrade_title_text.contents = switch (e.input.input_mode) {
            .Keyboard => "UPGRADE (U)",
            .KeyboardAndMouse => "UPGRADE",
        };

        equip.contents = switch (e.input.input_mode) {
            .KeyboardAndMouse => switch (item.equipped) {
                true => "UNEQUIP",
                false => "EQUIP",
            },
            .Keyboard => switch (item.equipped) {
                true => "UNEQUIP (E)",
                false => "EQUIP (E)",
            },
        };
        equip.options.style.color = switch (item.unequippable) {
            true => PREVIEW_FONT_COLOR,
            false => e.Color.gray,
        };

        showElement();
    }

    pub fn free() void {
        if (level_number.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, level_number.contents.?);
        }
        if (damage.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, damage.contents.?);
        }
        if (health.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, health.contents.?);
        }
        if (crit_rate.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, crit_rate.contents.?);
        }
        if (crit_damage.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, crit_damage.contents.?);
        }
        if (move_speed.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, move_speed.contents.?);
        }
        if (attack_speed.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, attack_speed.contents.?);
        }
        if (tenacity.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, tenacity.contents.?);
        }
        if (upgrade_cost_text.is_content_heap) {
            e.zlib.arrays.freeManyItemPointerSentinel(e.ALLOCATOR, upgrade_cost_text.contents.?);
        }
    }

    pub fn showElement() void {
        if (!selected) {
            std.log.warn("Element' weren't selectedd!", .{});
            select();
        }

        element.options.style.top = u("50%");
        is_shown = true;
    }

    pub fn hideElement() void {
        if (!selected) {
            std.log.warn("Element' weren't selectedd!", .{});
            select();
        }

        selected_item = null;
        element.options.style.top = u("-100%");
        is_shown = false;
    }

    pub fn equippButtonCallback() !void {
        const it = preview.selected_item;
        const item: *Item = if (it) |i| i else return;
        //
        if (!item.unequippable) return;
        //
        switch (item.equipped) {
            true => equippedbar.unequip(item),
            false => equippedbar.equip(item),
        }
        //
        sortBag();
        try updateGUI();
        try preview.show(preview.selected_item.?);
    }
};

/// Turns the Item.T value into a usize.
fn getValurFromItemType(T: conf.ItemTypes) usize {
    return switch (T) {
        .weapon => 0,
        .ring => 1,
        .amethyst => 2,
        .wayfinder => 3,
    };
}

/// The sorting function `sortBag()` uses.
fn sort(_: void, a: *?conf.Item, b: *?conf.Item) bool {
    if (b.* == null) return true;
    if (a.* == null) return false;

    if (a.*.?.equipped and !b.*.?.equipped) return true;
    if (!a.*.?.equipped and b.*.?.equipped) return false;

    if (b.*.?.rarity == .common and a.*.?.rarity != .common) return true;
    if (b.*.?.rarity == .epic and a.*.?.rarity == .legendary) return true;

    const a_val = getValurFromItemType(a.*.?.T);
    const b_val = getValurFromItemType(b.*.?.T);
    if (b.*.?.rarity == a.*.?.rarity) return a_val <= b_val;

    if (a.*.?.rarity == .common and b.*.?.rarity != .common) return false;
    if (a.*.?.rarity == .epic and b.*.?.rarity == .legendary) return false;

    std.log.warn("Something went wrong in the sort...", .{});
    return false;
}

/// Sorts the bag, result is in `sorted_bag`.
/// `null`s will be at the end of the array.
pub fn sortBag() void {
    std.sort.insertion(
        *?conf.Item,
        sorted_bag,
        {},
        sort,
    );
}

/// Return `true` when the item was picked up successfully,
/// `false` when the inventory is full.
pub fn pickUp(item: conf.Item) bool {
    for (bag, 0..) |it, index| {
        if (it != null) continue;

        bag[index] = item;
        return true;
    }
    return false;
}

/// Picks up the item, if the inventory is full returns `false` else `true`.
/// Sorts the bag by calling `sortBag()`.
pub fn pickUpSort(item: conf.Item) bool {
    const res = pickUp(item);
    sortBag();
    return res;
}

/// Refreses the UI to contain all items on the page
pub fn updateGUI() !void {
    for (0..bag_page_rows) |row| {
        for (0..bag_page_cols) |col| {
            const index = current_page.get() *
                bag_page_size +
                row *
                bag_page_cols +
                col;

            const element_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(element_selector);

            const button_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-btn-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(button_selector);

            const shower_selector = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "#slot-btn-shower-{d}-{d}",
                .{
                    row,
                    col,
                },
            );
            defer e.ALLOCATOR.free(shower_selector);

            const element: *GUI.GUIElement = if (GUI.select(element_selector)) |el| el else continue;
            const button: *GUI.GUIElement = if (GUI.select(button_selector)) |el| el else continue;
            const shower: *GUI.GUIElement = if (GUI.select(shower_selector)) |el| el else continue;

            const item = sorted_bag[index].*;

            if (item) |it| {
                shower.options.style.background.image = it.icon;

                element.options.style.background.image = switch (it.equipped) {
                    false => switch (it.rarity) {
                        .common => "sprites/gui/item_slot.png",
                        .epic => "sprites/gui/item_slot_epic.png",
                        .legendary => "sprites/gui/item_slot_legendary.png",
                    },
                    true => switch (it.rarity) {
                        .common => e.MISSINGNO,
                        .epic => e.MISSINGNO,
                        .legendary => e.MISSINGNO,
                    },
                };

                if (delete_mode) {
                    button.options.hover.background.image = "sprites/gui/delete_slot.png";
                    continue;
                }
                button.options.hover.background.image = "sprites/gui/slot_highlight.png";
                continue;
            }

            button.options.hover.background.image = switch (delete_mode) {
                false => "sprites/gui/slot_highlight.png",
                true => "sprites/gui/slot_highlight_delete.png",
            };

            shower.options.style.background.image = null;
            element.options.style.background.image = "sprites/gui/item_slot_empty.png";
        }
    }

    const delete_button = GUI.assertSelect("#delete_mode_shower");
    switch (delete_mode) {
        true => {
            delete_button.options.style.rotation = 15;
        },
        false => {
            delete_button.options.style.rotation = 0;
        },
    }

    const base_tags = [_][]const u8{
        "weapon",
        "ring",
        "amethyst",
        "wayfinder",
    };
    const enum_tags = [_]conf.ItemTypes{
        .weapon,
        .ring,
        .amethyst,
        .wayfinder,
    };

    for (base_tags, enum_tags) |tag, etag| {
        const element_selector = try std.fmt.allocPrint(
            e.ALLOCATOR,
            "#equipped_{s}",
            .{tag},
        );
        defer e.ALLOCATOR.free(element_selector);

        const button_selector = try std.fmt.allocPrint(
            e.ALLOCATOR,
            "#equipped_{s}_btn",
            .{tag},
        );
        defer e.ALLOCATOR.free(button_selector);

        const shower_selector = try std.fmt.allocPrint(
            e.ALLOCATOR,
            "#equipped_{s}_shower",
            .{tag},
        );
        defer e.ALLOCATOR.free(shower_selector);

        const element: *GUI.GUIElement = if (GUI.select(element_selector)) |el| el else continue;
        const button: *GUI.GUIElement = if (GUI.select(button_selector)) |el| el else continue;
        const shower: *GUI.GUIElement = if (GUI.select(shower_selector)) |el| el else continue;

        const item: ?*Item = switch (etag) {
            .weapon => equippedbar.current_weapon,
            .ring => equippedbar.ring,
            .amethyst => equippedbar.amethyst,
            .wayfinder => equippedbar.wayfinder,
        };

        if (item == null) {
            button.options.hover.background.image = switch (delete_mode) {
                false => "sprites/gui/slot_highlight.png",
                true => "sprites/gui/slot_highlight_delete.png",
            };

            shower.options.style.background.image = null;
            element.options.style.background.image = "sprites/gui/item_slot_empty.png";
            continue;
        }

        const it = item.?;

        shower.options.style.background.image = it.icon;

        element.options.style.background.image = switch (it.rarity) {
            .common => "sprites/gui/item_slot.png",
            .epic => "sprites/gui/item_slot_epic.png",
            .legendary => "sprites/gui/item_slot_legendary.png",
        };

        if (delete_mode) {
            button.options.hover.background.image = "sprites/gui/delete_slot.png";
            continue;
        }
        button.options.hover.background.image = "sprites/gui/slot_highlight.png";
    }

    // if (e.input.input_mode == .Keyboard) try autoSelect();
}

pub fn logSortedBag() void {
    std.log.debug("Sorted bag: ", .{});
    for (sorted_bag, 0..) |it, i| {
        std.debug.print("{d}: ", .{i});
        if (it.*) |item| {
            std.debug.print("{s}\n", .{item.icon});
            continue;
        }
        std.debug.print("null\n", .{});
    }
}

pub fn autoSelect() !void {
    const button: *GUI.GUIElement = if (GUI.hovered_button) |x| x else return;

    if (button.button_interface_ptr == null) return;

    if (std.mem.containsAtLeast(u8, button.options.id, 1, "slot") or
        std.mem.containsAtLeast(u8, button.options.id, 1, "equipped"))
    {
        const dm_original = delete_mode;
        delete_mode = false;
        try button.button_interface_ptr.?.callback_fn();
        delete_mode = dm_original;
    }
}

/// Generates the button/slot interface
inline fn MainSlotButton(
    id: []const u8,
    btn_id: []const u8,
    shower_id: []const u8,
    col_start: f32,
    col: usize,
    row: usize,
    container_width: f32,
    container_height: f32,
    func: ?*const fn () anyerror!void,
) !*GUI.GUIElement {
    return try GUI.Container(.{
        .id = id,
        .style = .{
            .width = .{
                .value = SLOT_SIZE,
                .unit = .vw,
            },
            .height = .{
                .value = SLOT_SIZE,
                .unit = .vw,
            },
            .left = .{
                .value = -1 * (container_width / 2) + (@as(f32, @floatFromInt(col))) * (SLOT_SIZE + 1),
                .unit = .vw,
            },
            .top = .{
                .value = -1 * (container_height / 2) + (@as(f32, @floatFromInt(row))) * (SLOT_SIZE + 1),
                .unit = .vw,
            },
            .background = .{
                .image = "sprites/gui/item_slot.png",
            },
        },
    }, @constCast(&[_]*GUI.GUIElement{
        try GUI.Button(
            .{
                .id = btn_id,
                .style = .{
                    .width = u("100%"),
                    .height = u("100%"),
                    .top = u("0%"),
                    .left = u("0%"),
                },
                .hover = .{
                    .background = .{
                        .image = "sprites/gui/slot_highlight.png",
                    },
                },
            },
            "",
            e.Vec2(0 + col + col_start, 0 + row),
            if (func) |fun| fun else (struct {
                pub fn callback() anyerror!void {
                    const item = sorted_bag[
                        bag_page_size *
                            current_page.get() +
                            row * bag_page_cols +
                            col
                    ];
                    //
                    if (delete_mode) {
                        if (col_start != 0)
                            item.* = null;
                        sortBag();
                        try updateGUI();
                        return;
                    }
                    //
                    if (item.* == null) {
                        preview.hideElement();
                        return;
                    }
                    try preview.show(
                        try e.zlib.nullAssertOptionalPointer(Item, item),
                    );
                }
            }).callback,
        ),
        try GUI.Empty(.{
            .id = shower_id,
            .style = .{
                .width = u("75%"),
                .height = u("75%"),
                .top = u("50%"),
                .left = u("50%"),
                .translate = .{
                    .x = .center,
                    .y = .center,
                },
                .background = .{
                    .image = "sprites/entity/player/weapons/gloves/left.png",
                    .fill = .contain,
                },
            },
        }),
    }));
}

/// Generates the button/slot interface
inline fn EquippedSlotButton(
    id: []const u8,
    btn_id: []const u8,
    shower_id: []const u8,
    col_start: f32,
    col: usize,
    row: usize,
    container_width: f32,
    container_height: f32,
    item_type: conf.ItemTypes,
    func: ?*const fn () anyerror!void,
) !*GUI.GUIElement {
    return try GUI.Container(.{
        .id = id,
        .style = .{
            .width = .{
                .value = SLOT_SIZE,
                .unit = .vw,
            },
            .height = .{
                .value = SLOT_SIZE,
                .unit = .vw,
            },
            .left = .{
                .value = -1 * (container_width / 2) + (@as(f32, @floatFromInt(col))) * (SLOT_SIZE + 1),
                .unit = .vw,
            },
            .top = .{
                .value = -1 * (container_height / 2) + (@as(f32, @floatFromInt(row))) * (SLOT_SIZE + 1),
                .unit = .vw,
            },
            .background = .{
                .image = "sprites/gui/item_slot.png",
            },
        },
    }, @constCast(&[_]*GUI.GUIElement{
        try GUI.Button(
            .{
                .id = btn_id,
                .style = .{
                    .width = u("100%"),
                    .height = u("100%"),
                    .top = u("0%"),
                    .left = u("0%"),
                },
                .hover = .{
                    .background = .{
                        .image = "sprites/gui/slot_highlight.png",
                    },
                },
            },
            "",
            e.Vec2(0 + col + col_start, 0 + row),
            if (func) |fun| fun else (struct {
                pub fn callback() anyerror!void {
                    const item: ?*Item = switch (item_type) {
                        .weapon => equippedbar.current_weapon,
                        .ring => equippedbar.ring,
                        .amethyst => equippedbar.amethyst,
                        .wayfinder => equippedbar.wayfinder,
                    };
                    if (item == null) {
                        preview.hideElement();
                        return;
                    }
                    const it = item.?;
                    if (delete_mode) {
                        if (!std.mem.eql(u8, std.mem.span(it.name), std.mem.span(HandsWeapon.name))) {
                            equippedbar.unequip(it);
                            // const x = @as(*?Item, @ptrCast(it));
                            // x.* = null;
                        }
                        preview.hideElement();
                        sortBag();
                        try updateGUI();
                        return;
                    }
                    try preview.show(it);
                }
            }).callback,
        ),
        try GUI.Empty(.{
            .id = shower_id,
            .style = .{
                .width = u("75%"),
                .height = u("75%"),
                .left = u("50%"),
                .top = u("50%"),
                .translate = .{
                    .x = .center,
                    .y = .center,
                },
                .background = .{
                    .image = "sprites/entity/player/weapons/gloves/left.png",
                    .fill = .contain,
                },
            },
        }),
    }));
}

/// Generates the button/slot interface
inline fn PageButton(
    id: []const u8,
    btn_id: []const u8,
    text: [*:0]const u8,
    page: usize,
    col: usize,
    row: usize,
    container_width: f32,
    container_height: f32,
    func: ?*const fn () anyerror!void,
) !*GUI.GUIElement {
    return try GUI.Container(
        .{
            .id = id,
            .style = .{
                .width = .{
                    .value = SLOT_SIZE * 2 + 1,
                    .unit = .vw,
                },
                .height = .{
                    .value = SLOT_SIZE,
                    .unit = .vw,
                },
                .left = .{
                    .value = -1 * (container_width / 2) + (@as(f32, @floatFromInt(col))) * (SLOT_SIZE + 1) - 1.5 + SLOT_SIZE / 2,
                    .unit = .vw,
                },
                .top = .{
                    .value = -1 * (container_height / 2) + (@as(f32, @floatFromInt(row))) * (SLOT_SIZE + 1),
                    .unit = .vw,
                },
                .background = .{
                    .image = "sprites/gui/page_btn_inactive.png",
                },
            },
        },
        @constCast(&[_]*GUI.GUIElement{
            try GUI.Button(
                .{
                    .id = btn_id,
                    .style = .{
                        .top = u("50%"),
                        .left = u("50%"),
                        .width = u("100%"),
                        .height = u("100%"),
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .font = .{
                            .size = 18,
                        },
                        .color = e.Color.black,
                    },
                    .hover = .{
                        .color = e.Color.black,
                        .background = .{
                            .image = "sprites/gui/page_btn.png",
                        },
                    },
                },
                text,
                e.Vec2(0 + col, 0 + row),
                if (func) |fun| fun else (struct {
                    pub fn callback() anyerror!void {
                        current_page.set(page);
                        //
                        sortBag();
                        try updateGUI();
                        //
                        const p0: *GUI.GUIElement = if (GUI.select("#page1")) |el| el else return;
                        const p1: *GUI.GUIElement = if (GUI.select("#page2")) |el| el else return;
                        const p2: *GUI.GUIElement = if (GUI.select("#page3")) |el| el else return;
                        //
                        p0.options.style.background.image = "sprites/gui/page_btn_inactive.png";
                        p1.options.style.background.image = "sprites/gui/page_btn_inactive.png";
                        p2.options.style.background.image = "sprites/gui/page_btn_inactive.png";
                        //
                        const selector = try std.fmt.allocPrint(e.ALLOCATOR, "#page{d}", .{page + 1});
                        defer e.ALLOCATOR.free(selector);
                        const self: *GUI.GUIElement = if (GUI.select(selector)) |el| el else return;
                        self.options.style.background.image = "sprites/gui/page_btn.png";
                    }
                }).callback,
            ),
        }),
    );
}

pub fn show() void {
    GUI.BM3D.setLayer(1);
    // INVENTORY_GUI.options.style.top = u("0%");
    dummy_animator.play("slide_down") catch {};

    e.input.ui_mode = true;
    shown = true;
}

pub fn hide() void {
    GUI.BM3D.resetLayer();
    dummy_animator.play("slide_up") catch {};

    e.input.ui_mode = false;
    shown = false;
}

pub fn toggle() void {
    dummy_animator.stop("slide_up");
    dummy_animator.stop("slide_down");
    if (shown) hide() else show();
}

pub fn awake() !void {
    animation_mapping_dummy = e.entities.Entity.dummy();
    dummy_animator = e.Animator.init(&e.ALLOCATOR, &animation_mapping_dummy);
    {
        var slide_down = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "slide_down",
            e.Animator.interpolation.ease_in_out,
            0.25,
        );
        {
            slide_down.chain(
                0,
                .{
                    .y = -100,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = 0,
                    },
                },
            );
            slide_down.chain(
                1,
                .{
                    .y = 0,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = @intFromFloat(@round(@as(f32, 255) * @as(f32, 0.75))),
                    },
                },
            );
        }
        try dummy_animator.chain(slide_down);

        var slide_up = e.Animator.Animation.init(
            &e.ALLOCATOR,
            "slide_up",
            e.Animator.interpolation.ease_in_out,
            0.25,
        );
        {
            slide_up.chain(
                0,
                .{
                    .y = 0,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = @intFromFloat(@round(@as(f32, 255) * @as(f32, 0.85))),
                    },
                },
            );
            slide_up.chain(
                1,
                .{
                    .y = -100,
                    .tint = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = 0,
                    },
                },
            );
        }
        try dummy_animator.chain(slide_up);
    }

    GUI.BM3D.setLayer(1);
    HandsWeapon = usePrefab(prefabs.hands);

    sorted_bag = try e.ALLOCATOR.alloc(*?conf.Item, bag_size);

    for (0..bag.len) |index| {
        sorted_bag[index] = &(bag[index]);
    }

    sortBag();

    // Auto equip last equipped items, since the equipped bar ain't saved
    // for (bag) |itemornull| {
    //     const item: *Item = if (itemornull) |*t| @constCast(t) else continue;
    //     if (!item.equipped) continue;

    //     equippedbar.equip(item);
    // }

    // Slot Generation
    slots = try e.ALLOCATOR.alloc(*GUI.GUIElement, bag_page_rows * bag_page_cols);

    inline for (0..bag_page_rows) |row| {
        inline for (0..bag_page_cols) |col| {
            const id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-{d}-{d}",
                .{ row, col },
            );
            const button_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-btn-{d}-{d}",
                .{ row, col },
            );
            const button_shower_id = try std.fmt.allocPrint(
                e.ALLOCATOR,
                "slot-btn-shower-{d}-{d}",
                .{ row, col },
            );

            slots[row * bag_page_cols + col] = try MainSlotButton(
                id,
                button_id,
                button_shower_id,
                1,
                col,
                row,
                WIDTH_VW,
                HEIGHT_VW + SLOT_SIZE + 1,
                null,
            );

            slots[row * bag_page_cols + col].heap_id = true;
            slots[row * bag_page_cols + col].children.?.items[0].heap_id = true;
            slots[row * bag_page_cols + col].children.?.items[1].heap_id = true;
        }
    }

    // The main GUI
    INVENTORY_GUI = try GUI.Container(
        .{
            .id = "InventoryParentBackground",
            .style = .{
                .background = .{
                    .color = e.Color.init(0, 0, 0, 128),
                },
                .top = u("-100%"),
                .width = u("100w"),
                .height = u("100h"),
            },
        },
        @constCast(&[_]*GUI.GUIElement{
            // Main inventory
            try GUI.Container(
                .{
                    .id = "Bag",
                    .style = .{
                        .width = .{
                            .value = WIDTH_VW,
                            .unit = .vw,
                        },
                        .height = .{
                            .value = HEIGHT_VW,
                            .unit = .vw,
                        },
                        .top = u("50%"),
                        .left = u("41w"),
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.blue,
                        },
                    },
                },
                slots,
            ),
            // Equipped - Delete - Pages
            try GUI.Container(
                .{
                    .id = "equippedShower",
                    .style = .{
                        .width = .{
                            .value = SLOT_SIZE,
                            .unit = .vw,
                        },
                        .height = .{
                            .value = HEIGHT_VW + SLOT_SIZE + 1,
                            .unit = .vw,
                        },
                        .top = u("50%"),
                        .left = u("13w"),
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                        .background = .{
                            // .color = e.Color.green,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    try EquippedSlotButton(
                        "equipped_weapon",
                        "equipped_weapon_btn",
                        "equipped_weapon_shower",
                        0,
                        0,
                        0,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        .weapon,
                        null,
                    ),
                    try EquippedSlotButton(
                        "equipped_ring",
                        "equipped_ring_btn",
                        "equipped_ring_shower",
                        0,
                        0,
                        1,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        .ring,
                        null,
                    ),
                    try EquippedSlotButton(
                        "equipped_amethyst",
                        "equipped_amethyst_btn",
                        "equipped_amethyst_shower",
                        0,
                        0,
                        2,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        .amethyst,
                        null,
                    ),
                    try EquippedSlotButton(
                        "equipped_wayfinder",
                        "equipped_wayfinder_btn",
                        "equipped_wayfinder_shower",
                        0,
                        0,
                        3,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        .wayfinder,
                        null,
                    ),
                    try MainSlotButton(
                        "delete_mode",
                        "delete_mode_btn",
                        "delete_mode_shower",
                        0,
                        0,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        (struct {
                            pub fn callback() anyerror!void {
                                delete_mode = !delete_mode;
                                try updateGUI();
                            }
                        }).callback,
                    ),
                    try PageButton(
                        "page1",
                        "page_1_btn",
                        "Page 1",
                        0,
                        2,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try PageButton(
                        "page2",
                        "page_2_btn",
                        "Page 2",
                        1,
                        4,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                    try PageButton(
                        "page3",
                        "page_3_btn",
                        "Page 3",
                        2,
                        6,
                        4,
                        SLOT_SIZE,
                        HEIGHT_VW + SLOT_SIZE + 1,
                        null,
                    ),
                }),
            ),
            // Preview
            try GUI.Container(
                .{
                    .id = "item-preview",
                    .style = .{
                        .width = .{
                            .value = SLOT_SIZE * 4 + 3,
                            .unit = .vw,
                        },
                        .height = .{
                            .value = SLOT_SIZE * 7 + 6,
                            .unit = .vw,
                        },
                        .top = u("50%"),
                        .left = .{
                            .value = 78,
                            .unit = .vw,
                        },
                        .translate = .{
                            .x = .center,
                            .y = .center,
                        },
                    },
                },
                @constCast(&[_]*GUI.GUIElement{
                    // Display
                    try GUI.Container(
                        .{
                            .id = "preview-display",
                            .style = .{
                                .width = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .height = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .top = u("-50%"),
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1) - 0.5,
                                    .unit = .vw,
                                },
                                .background = .{
                                    .image = "sprites/gui/item_slot_legendary.png",
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Empty(
                                .{
                                    .id = "preview-display-item",
                                    .style = .{
                                        .width = u("75%"),
                                        .height = u("75%"),
                                        .top = u("50%"),
                                        .left = u("50%"),
                                        .background = .{
                                            .image = "sprites/entity/player/weapons/gloves/left.png",
                                            .fill = .contain,
                                        },
                                        .rotation = 135,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                            ),
                        }),
                    ),
                    // Level
                    try GUI.Container(
                        .{
                            .id = "preview-level-container",
                            .style = .{
                                .width = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .height = .{
                                    .value = 2 * SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = -1 * SLOT_SIZE * 3.5 + 2.5,
                                    .unit = .vw,
                                },
                                .left = .{
                                    .value = SLOT_SIZE * 1 + 1,
                                    .unit = .vw,
                                },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .background = .{
                                    .image = PREVIEW_2x2,
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Text(
                                .{
                                    .id = "preview-level-text",
                                    .style = .{
                                        .top = u("-28x"),
                                        .font = .{
                                            .size = 16,
                                            .shadow = preview.generic_stat_button_style.font.shadow,
                                        },
                                        .color = PREVIEW_FONT_COLOR,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "Level",
                            ),
                            try GUI.Text(
                                .{
                                    .id = "preview-level-number",
                                    .style = .{
                                        .top = u("12x"),
                                        .font = .{
                                            .size = 44,
                                            .shadow = preview.generic_stat_button_style.font.shadow,
                                        },
                                        .color = PREVIEW_FONT_COLOR,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "90",
                            ),
                        }),
                    ),
                    // Name
                    try GUI.Text(
                        .{
                            .id = "preview-item-name",
                            .style = .{
                                .width = .{
                                    .value = 100,
                                    .unit = .percent,
                                },
                                .height = .{
                                    .value = SLOT_SIZE,
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = -1 * SLOT_SIZE * 1 - 1,
                                    .unit = .vw,
                                },
                                // .left = .{
                                //     .value = SLOT_SIZE * 1 + 1,
                                //     .unit = .vw,
                                // },
                                .color = PREVIEW_FONT_COLOR,
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .background = .{
                                    .image = PREVIEW_4x1,
                                },
                                .font = .{
                                    .size = 14,
                                    .shadow = preview.generic_stat_button_style.font.shadow,
                                },
                            },
                        },
                        "Item Name",
                    ),
                    // Damage
                    try GUI.Container(
                        .{
                            .id = "preview-damage-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5),
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = -1 * (SLOT_SIZE - 1) / 4,
                                    .unit = .vw,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-damage-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Health
                    try GUI.Container(
                        .{
                            .id = "preview-health-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .top = .{
                                    .value = -1 * (SLOT_SIZE - 1) / 4,
                                    .unit = .vw,
                                },
                                .left = .{
                                    .value = 0.5,
                                    .unit = .vw,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-health-number",
                                        .style = .{
                                            // .top = u("10x"),
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Crit Rate
                    try GUI.Container(
                        .{
                            .id = "preview-crit-rate-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .top = .{
                                    .value = (SLOT_SIZE - 1) / 2,
                                    .unit = .vw,
                                },
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5),
                                    .unit = .vw,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-crit-rate-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Crit Damage
                    try GUI.Container(
                        .{
                            .id = "preview-crit-damage-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .top = .{
                                    .value = (SLOT_SIZE - 1) / 2,
                                    .unit = .vw,
                                },
                                .left = .{
                                    .value = 0.5,
                                    .unit = .vw,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-crit-damage-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Move Speed
                    try GUI.Container(
                        .{
                            .id = "preview-move-speed-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5),
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = SLOT_SIZE + 2 - 1 * ((SLOT_SIZE - 1) / 2),
                                    .unit = .vw,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-move-speed-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Attack Speed
                    try GUI.Container(
                        .{
                            .id = "preview-attack-speed-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = 0.5,
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = SLOT_SIZE + 2 - 1 * ((SLOT_SIZE - 1) / 2),
                                    .unit = .vw,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-attack-speed-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "10",
                                ),
                            },
                        ),
                    ),
                    // Tenacity
                    try GUI.Container(
                        .{
                            .id = "preview-tenacity-container",
                            .style = .{
                                .width = preview.generic_stat_button_style.width,
                                .height = preview.generic_stat_button_style.height,
                                .translate = preview.generic_stat_button_style.translate,
                                .background = preview.generic_stat_button_style.background,
                                .left = .{
                                    .value = -1 * (SLOT_SIZE * 2 + 1.5),
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = 2 * (SLOT_SIZE) - 1 * ((SLOT_SIZE - 1) / 2),
                                    .unit = .vw,
                                },
                            },
                        },
                        @constCast(
                            &[_]*GUI.GUIElement{
                                try GUI.Text(
                                    .{
                                        .id = "preview-tenacity-number",
                                        .style = .{
                                            .font = preview.generic_stat_button_style.font,
                                            .left = u("50%"),
                                            .color = PREVIEW_FONT_COLOR,
                                        },
                                    },
                                    "20",
                                ),
                            },
                        ),
                    ),
                    // Equip
                    try GUI.Button(
                        .{
                            .id = "preview-equip-button",
                            .style = .{
                                .width = .{
                                    .value = SLOT_SIZE * 2 + 1,
                                    .unit = .vw,
                                },
                                .height = .{
                                    .value = SLOT_SIZE,
                                    .unit = .vw,
                                },
                                .left = .{
                                    .value = -1 * SLOT_SIZE - 1,
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = SLOT_SIZE * 3 + 3,
                                    .unit = .vw,
                                },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                                .color = PREVIEW_FONT_COLOR,
                                .background = .{
                                    .image = PREVIEW_2x1,
                                },
                            },
                        },
                        "EQUIP",
                        e.Vec2(9, 5),
                        preview.equippButtonCallback,
                    ),
                    // Upgrade
                    try GUI.Container(
                        .{
                            .id = "preview-level-up",
                            .style = .{
                                .width = .{
                                    .value = SLOT_SIZE * 2 + 1,
                                    .unit = .vw,
                                },
                                .height = .{
                                    .value = SLOT_SIZE,
                                    .unit = .vw,
                                },
                                .left = .{
                                    .value = SLOT_SIZE + 1,
                                    .unit = .vw,
                                },
                                .top = .{
                                    .value = SLOT_SIZE * 3 + 3,
                                    .unit = .vw,
                                },
                                .background = .{
                                    .image = "sprites/gui/page_btn_inactive.png",
                                },
                                .translate = .{
                                    .x = .center,
                                    .y = .center,
                                },
                            },
                        },
                        @constCast(&[_]*GUI.GUIElement{
                            try GUI.Button(
                                .{
                                    .id = "preview-upgrade-button",
                                    .style = .{
                                        .top = u("00%"),
                                        .left = u("00%"),
                                        .width = u("100%"),
                                        .height = u("100%"),
                                        .color = e.Color.black,
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                    .hover = .{
                                        .color = e.Color.black,
                                        .background = .{
                                            .image = "sprites/gui/page_btn.png",
                                        },
                                    },
                                },
                                "",
                                e.Vec2(10, 0 + 5),
                                (struct {
                                    pub fn callback() anyerror!void {
                                        //
                                        sortBag();
                                        try updateGUI();
                                    }
                                }).callback,
                            ),
                            try GUI.Text(
                                .{
                                    .id = "preview-upgrade-title",
                                    .style = .{
                                        .font = .{
                                            .size = 12,
                                        },
                                        .top = u("-8x"),
                                        .z_index = 10,
                                    },
                                },
                                "UPGRADE",
                            ),
                            try GUI.Text(
                                .{
                                    .id = "preview-upgrade-text",
                                    .style = .{
                                        .font = .{
                                            .size = 16,
                                        },
                                        .top = u("8x"),
                                        .left = u("-4x"),
                                        .z_index = 10,
                                        .background = .{
                                            .color = e.Color.blue,
                                        },
                                        .translate = .{
                                            .x = .center,
                                            .y = .center,
                                        },
                                    },
                                },
                                "1",
                            ),
                            try GUI.Empty(
                                .{
                                    .id = "preview-upgrade-currency",
                                    .style = .{
                                        .width = u("16x"),
                                        .height = u("16x"),
                                        .left = u("4x"),
                                        .background = .{
                                            .image = e.MISSINGNO,
                                        },
                                        .z_index = 10,
                                    },
                                },
                            ),
                        }),
                    ),
                }),
            ),
        }),
    );

    const delete_button: *GUI.GUIElement = if (GUI.select("#delete_mode_shower")) |el| el else return;

    delete_button.options.style.background.image = "sprites/gui/delete_toggle.png";
    delete_button.options.style.translate = .{
        .x = .center,
        .y = .center,
    };
    delete_button.options.style.top = u("50%");
    delete_button.options.style.left = u("50%");

    animation_mapping_dummy.transform.position.y = -100;
}

pub fn init() !void {
    preview.select();
    preview.hideElement();

    _ = pickUpSort(
        usePrefab(prefabs.legendaries.weapons.legendary_sword),
    );
    _ = pickUpSort(
        usePrefab(prefabs.epics.weapons.piercing_sword),
    );
    _ = pickUpSort(
        usePrefab(prefabs.epics.amethysts.test_amethyst),
    );
    _ = pickUpSort(
        usePrefab(prefabs.legendaries.weapons.staff),
    );
    _ = pickUpSort(
        usePrefab(prefabs.legendaries.weapons.daggers),
    );
    _ = pickUpSort(
        usePrefab(prefabs.legendaries.weapons.claymore),
    );

    equippedbar.autoEquip();

    sortBag();
    try updateGUI();
}

pub fn update() !void {
    if (e.isKeyPressed(.key_i) or e.isKeyPressed(.key_tab)) toggle();
    if (e.isKeyPressed(.key_escape) and shown) hide();

    dummy_animator.update();

    INVENTORY_GUI.options.style.top = .{
        .value = animation_mapping_dummy.transform.position.y,
        .unit = .percent,
    };
    if (!e.input.ui_mode) return;

    if ((e.isMouseButtonPressed(.mouse_button_left) or
        e.isKeyPressed(.key_enter) or
        e.isKeyPressed(.key_backspace) or
        e.isKeyPressed(.key_space)) and
        delete_mode_last_frame)
    {
        delete_mode = false;
        try updateGUI();
    }

    if (e.isKeyPressed(.key_backspace) and !delete_mode_last_frame) {
        delete_mode = true;
        try updateGUI();
    }

    if (e.isKeyPressed(.key_e) and preview.is_shown) {
        try preview.equippButtonCallback();
    }

    if ((e.isKeyPressed(.key_up) or
        e.isKeyPressed(.key_down) or
        e.isKeyPressed(.key_left) or
        e.isKeyPressed(.key_right)) and
        GUI.hovered_button != null)
    {
        try autoSelect();
    }

    delete_mode_last_frame = delete_mode;
}

pub fn deinit() !void {
    e.ALLOCATOR.free(slots);
    e.ALLOCATOR.free(sorted_bag);
    preview.free();

    dummy_animator.deinit();
    animation_mapping_dummy.deinit();
}
