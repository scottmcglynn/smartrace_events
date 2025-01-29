import 'package:flutter/material.dart';
import '../services/govee_service.dart';
import '../services/server_service.dart';
import '../services/govee_bluetooth_service.dart';
import '../widgets/weather_control_buttons.dart';

class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
              valueListenable: widget.goveeService.lightIpNotifier,
              builder: (context, ip, _) => Text(
                ip,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<String>(
              stream: Stream.periodic(const Duration(seconds: 1))
                .map((_) => widget.serverService.currentAddress ?? 'Server not running'),
              builder: (context, snapshot) {
                return Text(
                  'Server IP: ${snapshot.data ?? 'Loading...'}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(height: 20),
            WeatherControlButtons(
              goveeService: widget.goveeService,
              goveeBluetoothService: widget.goveeBluetoothService,
            ),
          ],
        ),
      ),
    );
  }
}