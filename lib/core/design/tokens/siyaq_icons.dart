import 'package:flutter/material.dart';

/// Icon size scale.
class SiyaqIconSize {
  SiyaqIconSize._();

  static const xs = 12.0;
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  static const scale = <(String, double)>[
    ('xs', xs),
    ('sm', sm),
    ('md', md),
    ('lg', lg),
    ('xl', xl),
    ('xxl', xxl),
  ];
}

/// Canonical icon set.
///
/// The audit found emoji used as UI icons — `🔥 💡 🔒 ✓ 🐾 ⚽ 💻 🍽️ 🗺️ 🌍`
/// (audit §6.6). Emoji render per-platform, ignore [IconTheme], cannot be
/// tinted by state, and are invisible to screen readers.
///
/// This table maps each semantic role to a tintable [IconData] so components
/// built from Phase 3 onward never reach for a glyph. **No screen is migrated in
/// this phase** — replacing the emoji at their ~10 call sites is per-screen work
/// that belongs with the component rebuild.
class SiyaqIcons {
  SiyaqIcons._();

  // Gameplay
  static const hot = Icons.local_fire_department_rounded; // 🔥
  static const hint = Icons.lightbulb_rounded; // 💡
  static const locked = Icons.lock_rounded; // 🔒
  static const correct = Icons.check_rounded; // ✓
  static const best = Icons.bookmark_rounded;
  static const rank = Icons.tag_rounded;
  static const trendUp = Icons.arrow_upward_rounded;
  static const trendDown = Icons.arrow_downward_rounded;

  // Navigation
  static const home = Icons.home_rounded;
  static const ranked = Icons.military_tech_rounded;
  static const social = Icons.groups_rounded;
  static const profile = Icons.person_rounded;
  static const leaderboard = Icons.leaderboard_rounded;
  static const settings = Icons.settings_rounded;
  static const back = Icons.arrow_back_rounded;
  static const play = Icons.play_arrow_rounded;
  static const close = Icons.close_rounded;

  // Status / feedback
  static const success = Icons.check_circle_rounded;
  static const error = Icons.error_rounded;
  static const warning = Icons.warning_rounded;
  static const info = Icons.info_rounded;
  static const offline = Icons.wifi_off_rounded;
  static const emptyBox = Icons.inbox_rounded;
  static const timer = Icons.schedule_rounded;
  static const attempts = Icons.lightbulb_outline_rounded;

  // Identity & account
  static const edit = Icons.edit_rounded;
  static const playerId = Icons.badge_outlined;
  static const copy = Icons.copy_rounded;
  static const signIn = Icons.login_rounded;
  static const apple = Icons.apple;
  static const verified = Icons.verified_rounded;
  static const synced = Icons.cloud_done_outlined;
  static const privacy = Icons.shield_outlined;

  // Multiplayer
  static const addCircle = Icons.add_circle_outline_rounded;
  static const room = Icons.meeting_room_outlined;

  // Selection & room actions
  static const checkCircle = Icons.check_circle_rounded;
  static const radioOff = Icons.circle_outlined;
  static const share = Icons.ios_share_rounded;
  static const leave = Icons.logout_rounded;
  static const invite = Icons.person_add_alt_1_rounded;
  static const add = Icons.add_rounded;

  // Theme
  static const themeSystem = Icons.brightness_auto_rounded;
  static const themeLight = Icons.light_mode_rounded;
  static const themeDark = Icons.dark_mode_rounded;

  // Categories (replacing the emoji map in `siyag_create_room_screen.dart`)
  static const catAnimals = Icons.pets_rounded; // 🐾
  static const catSports = Icons.sports_soccer_rounded; // ⚽
  static const catAgriculture = Icons.agriculture_rounded;
  static const catTechnology = Icons.computer_rounded; // 💻
  static const catFood = Icons.restaurant_rounded; // 🍽️
  static const catGeography = Icons.map_rounded; // 🗺️
  static const catGeneral = Icons.public_rounded; // 🌍

  /// Icon for a backend category key. Falls back to [catGeneral].
  static IconData category(String key) {
    final k = key.toLowerCase();
    if (k.contains('animal') || k.contains('حيوان')) return catAnimals;
    if (k.contains('sport') || k.contains('رياض')) return catSports;
    if (k.contains('agri') || k.contains('farm') || k.contains('زراع')) {
      return catAgriculture;
    }
    if (k.contains('tech') || k.contains('تقني')) return catTechnology;
    if (k.contains('food') || k.contains('طعام')) return catFood;
    if (k.contains('geo') || k.contains('جغراف')) return catGeography;
    return catGeneral;
  }
}
