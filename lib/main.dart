// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/server_service.dart';
import 'services/govee_service.dart';
import 'services/govee_bluetooth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize UDP service first and wait for it
  final goveeService = GoveeService();
  print('Initializing UDP Govee light...');
  await goveeService.initialize(); // Make sure this method exists and waits for initialization
  print('UDP Govee light initialized. IP: ${goveeService.lightIp}');
  
  // Initialize Bluetooth service
  final goveeBluetoothService = GoveeBluetoothService();
  
  // Pass both services to the server service
  final serverService = ServerService(
    goveeService: goveeService,
    goveeBluetoothService: goveeBluetoothService,
  );
  
  // Start server
  await serverService.startServer();
  
  runApp(MyApp(
    serverService: serverService,
    goveeService: goveeService,
    goveeBluetoothService: goveeBluetoothService,
  ));
}

class MyApp extends StatelessWidget {
  final ServerService serverService;
  final GoveeService goveeService;
  final GoveeBluetoothService goveeBluetoothService;
  
  const MyApp({
    super.key,
    required this.serverService,
    required this.goveeService,
    required this.goveeBluetoothService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Govee Weather Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(
        serverService: serverService,
        goveeService: goveeService,
        goveeBluetoothService: goveeBluetoothService,  // Added this line
      ),
    );
  }
}