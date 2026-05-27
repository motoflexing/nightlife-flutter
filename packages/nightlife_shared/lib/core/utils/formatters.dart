import 'package:intl/intl.dart';

class Formatters {
  static final _dateTime = DateFormat('EEE, d MMM - h:mm a');

  static String eventDate(DateTime value) => _dateTime.format(value);

  static String titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
