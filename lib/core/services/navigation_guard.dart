/// Guards navigation when there are unsaved changes in the current page.
///
/// Pages with unsaved changes register a [hasUnsavedChanges] callback.
/// The shell checks [shouldBlock] before navigating and shows a
/// confirmation dialog when needed.
class NavigationGuard {
  bool Function()? hasUnsavedChanges;
  VoidCallback? onDiscard;

  bool get shouldBlock => hasUnsavedChanges?.call() ?? false;

  void clear() {
    hasUnsavedChanges = null;
    onDiscard = null;
  }
}

/// Replacement for dart:ui VoidCallback to avoid importing dart:ui.
typedef VoidCallback = void Function();
