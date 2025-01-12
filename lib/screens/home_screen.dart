// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../services/govee_service.dart';
import '../services/server_service.dart';
import '../services/govee_bluetooth_service.dart';
import '../widgets/weather_control_buttons.dart';

class HomeScreen extends StatelessWidget {
  final GoveeService goveeService;
  final ServerService serverService;
  final GoveeBluetoothService goveeBluetoothService;

  const HomeScreen({
    super.key,
    required this.goveeService,
    required this.serverService,
    required this.goveeBluetoothService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Govee Light Control Server')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Govee Light IP:'),
            const SizedBox(height: 20),
            ValueListenableBuilder<String>(
              valueListenable: goveeService.lightIpNotifier,
              builder: (context, ip, _) => Text(
                ip,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Server IP: ${ServerService.SERVER_IP}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
            // const SizedBox(height: 30),
            // ElevatedButton(
            //   onPressed: serverService.stopServer,
            //   child: const Text('Stop Server'),
            // ),
            const SizedBox(height: 20),
            WeatherControlButtons(
              goveeService: goveeService,
              goveeBluetoothService: goveeBluetoothService,
            ),
          ],
        ),
      ),
    );
  }
}