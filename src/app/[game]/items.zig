const std = @import("std");
const conf = @import("../../config.zig");

const e = @import("../../engine/engine.m.zig");

pub fn awake() !void {}

pub fn init() !void {}

pub fn update() !void {}

pub fn deinit() !void {}

/// If the id of an item is 0 it's a prefab.
pub const prefabs = struct {
    pub const hands: conf.Item = .{
        .id = 0,
        .T = .weapon,
        .weapon_type = .daggers,

        .damage = 10,
        .weapon_projectile_scale_light = e.Vec2(64, 64),

        .weapon_heavy = .{
            .sprite = "sprites/projectiles/player/generic/heavy.png",
            .attack_speed_modifier = 2,
        },

        .name = "Hands",
        .equipped = true,
        .unequippable = false,

        .attack_speed = 0.25,

        .icon = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
        .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
    };

    pub const commons = struct {
        pub const weapons = struct {};
    };

    pub const epics = struct {
        pub const weapons = struct {
            pub const piercing_sword: conf.Item = .{
                .T = .weapon,
                .rarity = .epic,
                .damage = 10,

                .name = "Piercing Sword",

                .weapon_light = .{
                    .projectile_health = 500,
                },
                .weapon_heavy = .{
                    .projectile_health = 1000,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },

                .icon = "sprites/weapons/steel_sword.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/steel_sword.png",
            };
        };
        pub const amethysts = struct {
            pub const test_amethyst: conf.Item = .{
                .T = .amethyst,
                .rarity = .epic,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .name = "Epic Amethyst",

                .icon = "sprites/entity/player/weapons/gloves/left.png",
                .weapon_sprite_left = "sprites/entity/player/weapons/gloves/left.png",
                .weapon_sprite_right = "sprites/entity/player/weapons/gloves/right.png",
            };
        };
    };

    pub const legendaries = struct {
        pub const weapons = struct {
            pub const legendary_sword: conf.Item = .{
                .id = 0,
                .T = .weapon,
                .rarity = .legendary,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .level = 999,

                .attack_speed = 0.2,

                .name = "Legendary Sword",
                .weapon_light = .{
                    .projectile_array = [5]?f32{ -75, -45, 0, 45, 75 } ++ ([_]?f32{null} ** 11),
                },
                .weapon_heavy = .{
                    .projectile_array = [5]?f32{ -25, -15, 0, 15, 25 } ++ ([_]?f32{null} ** 11),
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },

                .icon = "sprites/weapons/steel_sword_heavy.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/steel_sword_heavy.png",
            };

            pub const trident: conf.Item = .{
                .T = .weapon,
                .level = 10,
                .weapon_type = .polearm,
                .rarity = .legendary,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .name = "Trident",

                .attack_speed = 0.15,

                .weapon_light = .{
                    .projectile_array = [3]?f32{ -60, 0, 60 } ++ ([_]?f32{null} ** 13),
                    .projectile_health = 500,
                    .projectile_on_hit_effect = .energized,
                },
                .weapon_heavy = .{
                    .projectile_health = 1000,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },
                .weapon_dash = .{
                    .projectile_array = [5]?f32{ -100, -60, 0, 60, 100 } ++ ([_]?f32{null} ** 11),
                    .projectile_health = 750,
                    .projectile_speed = 720,
                },

                .icon = "sprites/weapons/fork.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/fork.png",
            };

            pub const daggers: conf.Item = .{
                .T = .weapon,
                .weapon_type = .daggers,
                .rarity = .legendary,
                .damage = 10,
                .weapon_projectile_scale_light = e.Vec2(64, 64),

                .name = "Daggers of the Gods",

                .weapon_light = .{
                    .projectile_array = [2]?f32{ -20, 20 } ++ ([_]?f32{null} ** 14),
                    .projectile_health = 500,
                },
                .weapon_heavy = .{
                    .projectile_array = [3]?f32{ -20, 0, 20 } ++ ([_]?f32{null} ** 13),
                    .projectile_health = 1000,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                },

                .icon = "sprites/weapons/dagger.png",
                .weapon_sprite_left = "sprites/weapons/dagger.png",
                .weapon_sprite_right = "sprites/weapons/dagger.png",
            };

            pub const claymore: conf.Item = .{
                .T = .weapon,
                .weapon_type = .claymore,
                .rarity = .legendary,
                .damage = 120,
                .weapon_projectile_scale_light = e.Vec2(64, 128),

                .name = "Claymore",
                .attack_speed = 1,

                .weapon_light = .{
                    .projectile_array = [4]?f32{ -180, -90, 0, 90 } ++ ([_]?f32{null} ** 12),
                    .projectile_health = 2000,
                    .projectile_scale = e.Vec2(128, 64),
                    // .projectile_on_hit_effect = .stengthen,
                },
                .weapon_heavy = .{
                    .projectile_array = conf.createProjectileArray(
                        8,
                        [_]?f32{ -180, -135, -90, -45, 0, 45, 90, 135 },
                    ),
                    .projectile_health = 5000,
                    .projectile_scale = e.Vec2(256, 128),
                    .attack_speed_modifier = 2.5,
                    .sprite = "sprites/projectiles/player/generic/heavy.png",
                    // .projectile_on_hit_effect = .stengthen,
                },
                .weapon_dash = .{
                    .projectile_array = [1]?f32{0} ++ ([_]?f32{null} ** 15),
                    .projectile_health = 3500,
                    .projectile_scale = e.Vec2(385, 128),
                    .attack_speed_modifier = 2,
                    .projectile_speed = 720,
                },

                .icon = "sprites/weapons/claymore.png",
                .weapon_sprite_left = e.MISSINGNO,
                .weapon_sprite_right = "sprites/weapons/claymore.png",
            };
        };
    };
};

pub fn usePrefab(prefab: conf.Item) conf.Item {
    var it: conf.Item = prefab;

    it.id = e.uuid.v7.new();

    return it;
}
