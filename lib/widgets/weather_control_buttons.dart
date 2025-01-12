// lib/widgets/weather_control_buttons.dart
import 'package:flutter/material.dart';
import '../services/govee_service.dart';
import '../services/govee_bluetooth_service.dart';
import '../models/weather_event.dart';

class WeatherControlButtons extends StatelessWidget {
  final GoveeService goveeService;
  final GoveeBluetoothService goveeBluetoothService;

  const WeatherControlButtons({
    super.key,
    required this.goveeService,
    required this.goveeBluetoothService,
  });

  // Helper method to call both services
  Future<void> _handleBothServices(WeatherEvent event, dynamic status) async {
    await goveeBluetoothService.handleWeatherEvent(event, status);
    await goveeService.handleEvent(event, status);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Weather Events', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => _handleBothServices(
            WeatherEvent.weatherUpdate,
            'about_to_rain',
          ),
          child: const Text('About to Rain'),
        ),
        ElevatedButton(
          onPressed: () => _handleBothServices(
            WeatherEvent.weatherUpdate,
            'about_to_dry_up',
          ),
          child: const Text('About to Dry Up'),
        ),
        ElevatedButton(
          onPressed: () => _handleBothServices(
            WeatherEvent.weatherChange,
            'wet',
          ),
          child: const Text('Weather Wet'),
        ),
        ElevatedButton(
          onPressed: () => _handleBothServices(
            WeatherEvent.weatherChange,
            'dry',
          ),
          child: const Text('Weather Dry'),
        ),
        const SizedBox(height: 20),
        const Text('Status Events', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => _handleBothServices(
            WeatherEvent.statusChange,
            {'new': 'running'},
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Running'),
        ),
        ElevatedButton(
          onPressed: () => _handleBothServices(
            WeatherEvent.statusChange,
            {'new': 'restarting'},
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('Restarting'),
        ),
        ElevatedButton(
          onPressed: () => _handleBothServices(
            WeatherEvent.statusChange,
            {'new': 'suspended'},
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Suspended'),
        ),
      ],
    );
  }
}