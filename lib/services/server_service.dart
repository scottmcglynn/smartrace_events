// lib/services/server_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/weather_event.dart';
import 'govee_service.dart';
import 'govee_bluetooth_service.dart';

class ServerService {
  final GoveeService goveeService;
  final GoveeBluetoothService goveeBluetoothService;
  HttpServer? _server;
  
  // Server configuration
  static const String SERVER_IP = '192.168.68.64';
  static const int SERVER_PORT = 8080;

  ServerService({
    required this.goveeService,
    required this.goveeBluetoothService,
  });

  Future<void> startServer() async {
    if (_server != null) {
      print('Server already running');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress(SERVER_IP), SERVER_PORT);
      print('Server running on http://$SERVER_IP:$SERVER_PORT/');

      _server?.listen(_handleRequest);
    } catch (e) {
      print('Error starting server: $e');
      rethrow;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'POST');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('');
      await request.response.close();
      return;
    }

    if (request.method == 'POST' &&
        request.headers.contentType?.mimeType == 'application/json') {
      try {
        final content = await utf8.decoder.bind(request).join();
        final jsonData = jsonDecode(content) as Map<String, dynamic>;
        print('Received event data: $jsonData');

        final eventType = WeatherEvent.fromString(jsonData['event_type']);
        final eventData = jsonData['event_data'];

        // Handle the event using both services
        await _handleWeatherEvent(eventType, eventData);

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'status': 'success',
            'message': 'Event handled successfully',
          }));
      } catch (e) {
        print('Error handling request: $e');
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'status': 'error',
            'message': 'Error processing request: $e',
          }));
      }
    } else {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'status': 'error',
          'message': 'Only POST requests are supported',
        }));
    }

    await request.response.close();
  }

  Future<void> _handleWeatherEvent(WeatherEvent eventType, dynamic eventData) async {
    print('ServerService: Handling weather event - Type: $eventType, Data: $eventData');
    
    // Handle UDP service
    print('ServerService: Sending event to UDP service...');
    await goveeService.handleEvent(eventType, eventData).catchError((e) {
      print('Error handling UDP event: $e');
    });

    // Handle Bluetooth service
    print('ServerService: Sending event to Bluetooth service...');
    try {
      await goveeBluetoothService.handleWeatherEvent(eventType, eventData);
      print('ServerService: Bluetooth event handled successfully');
    } catch (e) {
      print('Error handling Bluetooth event: $e');
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    print('Server stopped');
  }

  bool get isRunning => _server != null;
}