/// SoDesk Studio - Custom extensions for RustDesk fork
///
/// All studio-specific customizations live under this directory
/// to minimize merge conflicts with upstream RustDesk updates.
///
/// Structure:
///   pages/   - Custom page widgets (screen wall, studio home, etc.)
///   widgets/ - Reusable studio-specific widgets
///   models/  - Studio data models and state management

export 'studio_theme.dart';
export 'pages/studio_home_page.dart';
export 'pages/screen_wall_page.dart';

// Models
export 'models/screen_wall_model.dart';
export 'models/screen_wall_session.dart';
export 'models/device_group.dart';

// Widgets
export 'widgets/wall_cell_widget.dart';
export 'widgets/wall_remote_view.dart';
export 'widgets/wall_fullscreen_view.dart';
export 'widgets/wall_texture_renderer.dart';
export 'widgets/device_picker_dialog.dart';
export 'widgets/studio_nav_sidebar.dart';
export 'widgets/studio_device_tree.dart';
