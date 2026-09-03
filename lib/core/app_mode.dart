class AppMode {
  const AppMode._();

  // Production builds hide demo buttons by default.
  // To show test tools: flutter run --dart-define=NGX_DEMO_MODE=true
  static const enableDemoTools = bool.fromEnvironment(
    'NGX_DEMO_MODE',
    defaultValue: false,
  );
}
