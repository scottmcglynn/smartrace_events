// lib/models/weather_event.dart
enum WeatherEvent {
  weatherUpdate,
  weatherChange,
  statusChange;

  static WeatherEvent fromString(String event) {
    switch (event) {
      case 'events.weather_update':
        return WeatherEvent.weatherUpdate;
      case 'events.weather_change':
        return WeatherEvent.weatherChange;
      case 'event.change_status':
        return WeatherEvent.statusChange;
      default:
        throw ArgumentError('Unknown event type: $event');
    }
  }
  /// Converts the WeatherEvent enum value to its corresponding string representation.
  String toEventString() {
    switch (this) {
      case WeatherEvent.weatherUpdate:
        return 'events.weather_update';
      case WeatherEvent.weatherChange:
        return 'events.weather_change';
      case WeatherEvent.statusChange:
        return 'event.change_status';
    }
  }
}