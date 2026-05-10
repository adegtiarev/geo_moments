import 'dart:ui';

enum AppWindowClass { compact, medium, expanded }

abstract final class AppBreakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;
  static const landscapeSplitMinWidth = 700.0;

  static bool isTabletWidth(double width) => width >= tablet;

  static AppWindowClass windowClassFor(Size size) {
    if (size.width >= desktop) {
      return AppWindowClass.expanded;
    }

    if (size.width >= tablet) {
      return AppWindowClass.medium;
    }

    return AppWindowClass.compact;
  }

  static bool useSidePanel(Size size) {
    final isWideEnough = size.width >= tablet;
    final isLandscapePhone =
        size.width >= landscapeSplitMinWidth && size.width > size.height;

    return isWideEnough || isLandscapePhone;
  }

  static double sidePanelWidth(Size size) {
    if (size.width >= desktop) {
      return 440;
    }

    return 360;
  }
}
