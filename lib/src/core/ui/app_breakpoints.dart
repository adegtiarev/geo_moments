abstract final class AppBreakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;

  static bool isTabletWidth(double width) => width >= tablet;
}
