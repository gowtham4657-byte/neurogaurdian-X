class EmergencyConfig {
  const EmergencyConfig._();

  static const backendUrl = String.fromEnvironment(
    'NGX_BACKEND_URL',
    defaultValue: '',
  );

  static const backendToken = String.fromEnvironment(
    'NGX_BACKEND_TOKEN',
    defaultValue: '',
  );

  static const guardianPushTarget = String.fromEnvironment(
    'NGX_GUARDIAN_PUSH_TARGET',
    defaultValue: '',
  );

  // Keep service credentials/configuration out of the normal wearer UI.
  static const showAdvancedSosSettings = bool.fromEnvironment(
    'NGX_SHOW_ADVANCED_SOS_SETTINGS',
    defaultValue: false,
  );
}
