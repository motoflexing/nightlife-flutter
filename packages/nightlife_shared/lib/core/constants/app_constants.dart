class AppConstants {
  static const appName = 'Nightlife Platform';
  static const cities = ['All', 'Guwahati', 'Delhi', 'Mumbai', 'Bengaluru', 'Kolkata', 'Shillong'];
  static const defaultCity = 'Guwahati';
  static const roles = ['user', 'promoter', 'clubAdmin', 'superAdmin'];
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
