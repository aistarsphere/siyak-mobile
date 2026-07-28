/// Siyaq design system — single import for tokens, theme access and components.
///
/// ```dart
/// import 'package:context_game/core/design/siyaq_design.dart';
/// ```
///
/// Structure:
///  * `tokens/`     — colour, typography, spacing, radius, elevation, motion, icons
///  * `theme/`      — `ThemeData` assembly and `context.colors` / `context.type`
///  * `components/` — reusable widgets built from the tokens
///  * `a11y/`       — semantics, focus and touch-target primitives
///  * `gallery/`    — debug-only validation harness (not exported here)
library;

export 'a11y/siyaq_a11y.dart';
export 'components/gameplay/siyaq_guess_composer.dart';
export 'components/gameplay/siyaq_guess_highlight.dart';
export 'components/gameplay/siyaq_guess_row.dart';
export 'components/gameplay/siyaq_hint_panel.dart';
export 'components/foundation/siyaq_button.dart';
export 'components/foundation/siyaq_divider.dart';
export 'components/foundation/siyaq_icon.dart';
export 'components/foundation/siyaq_icon_button.dart';
export 'components/foundation/siyaq_pressable.dart';
export 'components/foundation/siyaq_surface.dart';
export 'components/foundation/siyaq_text.dart';
export 'components/shared/siyaq_avatar.dart';
export 'components/shared/siyaq_chip.dart';
export 'components/shared/siyaq_count_badge.dart';
export 'components/shared/siyaq_icon_tile.dart';
export 'components/shared/siyaq_leaderboard.dart';
export 'components/shared/siyaq_list_row.dart';
export 'components/shared/siyaq_modals.dart';
export 'components/shared/siyaq_player_row.dart';
export 'components/shared/siyaq_progress_bar.dart';
export 'components/shared/siyaq_room_code.dart';
export 'components/shared/siyaq_screen_header.dart';
export 'components/shared/siyaq_segmented_control.dart';
export 'components/shared/siyaq_select_tile.dart';
export 'components/shared/siyaq_states.dart';
export 'components/shared/siyaq_stat_card.dart';
export 'components/shared/siyaq_text_field.dart';
export 'feedback/siyaq_feedback.dart';
export 'gameplay/siyaq_heat.dart';
export 'theme/context_tokens.dart';
export 'theme/siyaq_theme_data.dart';
export 'tokens/siyaq_colors.dart';
export 'tokens/siyaq_elevation.dart';
export 'tokens/siyaq_icons.dart';
export 'tokens/siyaq_motion.dart';
export 'tokens/siyaq_spacing.dart';
export 'tokens/siyaq_typography.dart';
