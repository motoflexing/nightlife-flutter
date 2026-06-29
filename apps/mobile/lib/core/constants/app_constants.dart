class AppConstants {
  static const appName = 'Nightlife Platform';

  // TODO: Replace with the real hosted Privacy Policy / Terms URLs before store
  // submission. These PLACEHOLDER values must not ship to the App Store / Play.
  static const String privacyPolicyUrl =
      'https://PLACEHOLDER-REPLACE-ME.example.com/privacy';
  static const String termsOfServiceUrl =
      'https://PLACEHOLDER-REPLACE-ME.example.com/terms';
  static const cities = ['All', 'Guwahati', 'Delhi', 'Mumbai', 'Bengaluru', 'Kolkata', 'Shillong'];
  static const defaultCity = 'Guwahati';
  static const roles = ['user', 'promoter', 'clubAdmin'];
  static const requestableRoles = ['user', 'promoter', 'clubAdmin'];
  static const userStatuses = [
    'pending',
    'pending_review',
    'approved',
    'rejected',
  ];
  static const rsvpStatuses = ['confirmed', 'pending', 'approved', 'rejected'];
  static const eventPageSize = 50;
}
