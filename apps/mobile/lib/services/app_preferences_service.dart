import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  AppPreferencesService._();

  static final instance = AppPreferencesService._();
  static const selectedCityKey = 'selected_city';

  Future<String> loadSelectedCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(selectedCityKey) ?? 'All';
  }

  Future<void> saveSelectedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedCityKey, city);
  }
}
