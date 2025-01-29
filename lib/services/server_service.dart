import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/weather_event.dart';
import 'govee_service.dart';
import 'govee_bluetooth_service.dart';

class ServerService {
  final GoveeService goveeService;
  final GoveeBluetoothService goveeBluetoothService;
  HttpServer? _server;
  static const int SERVER_PORT = 8080;
  
  final ValueNotifier<String> serverAddressNotifier = ValueNotifier<String>('Server not running');

  ServerService({
    required this.goveeService,
    required this.goveeBluetoothService,
  });

  Future<String> _detectLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      final validInterfaces = interfaces.where((interface) {
        return !interface.name.contains('docker') && 
               !interface.name.contains('lo');
      });

      for (var interface in validInterfaces) {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.168.') || 
              addr.address.startsWith('10.') || 
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }

      throw Exception('No valid local network IP address found');
    } catch (e) {
      print('Error detecting local IP: $e');
      throw Exception('Failed to detect local IP address: $e');
    }
  }

  Future<void> startServer() async {
    if (_server != null) {
      print('Server already running');
      return;
    }

    try {
      final localIP = await _detectLocalIP();
      _server = await HttpServer.bind(InternetAddress(localIP), SERVER_PORT);
      serverAddressNotifier.value = '$localIP:$SERVER_PORT';
      print('Server running on http://${serverAddressNotifier.value}/');
      _server?.listen(_handleRequest);
    } catch (e) {
      serverAddressNotifier.value = 'Error: $e';
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

    print('ServerService: Sending event to UDP service...');
    await goveeService.handleEvent(eventType, eventData).catchError((e) {
      print('Error handling UDP event: $e');
    });

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
    serverAddressNotifier.value = 'Server not running';
    print('Server stopped');
  }

  bool get isRunning => _server != null;
}