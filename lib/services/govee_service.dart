// lib/services/govee_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/weather_event.dart';
import 'audio_service.dart';

class GoveeService {
  // UDP configuration
  static const int portSend = 4001;
  static const int portReceive = 4002;
  static const String multicastAddress = '239.255.255.250';

  final ValueNotifier<String> lightIpNotifier = ValueNotifier<String>('Initializing...');
  final AudioService _audioService = AudioService();
  String _trackevent = 'events.weather_change';
  String _trackstatus = 'dry';

  // Getter for light IP
  String get lightIp => lightIpNotifier.value;

  Future<void> initialize() async {
    print('Starting GoveeService initialization...');
    try {
      final ip = await _initializeGovee();
      lightIpNotifier.value = ip;
      print('GoveeService initialized with IP: $ip');
    } catch (e) {
      print('Error initializing GoveeService: $e');
      lightIpNotifier.value = 'Failed to initialize';
    }
  }

  Future<String> _initializeGovee() async {
    final multicastAddr = InternetAddress(multicastAddress);
    final command = jsonEncode({
      "msg": {
        "cmd": "scan",
        "data": {"account_topic": "reserve"}
      }
    });

    print('Sending scan command to discover Govee lights...');
    
    try {
      // Create a UDP socket to send the scan command
      final sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sendSocket.send(utf8.encode(command), multicastAddr, portSend);
      sendSocket.close();

      // Create a UDP socket to listen for responses
      final receiveSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, portReceive);
      print('Listening for responses on port $portReceive...');

      final completer = Completer<String>();
      Timer? timeoutTimer;

      // Set a timeout
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          receiveSocket.close();
          completer.completeError('Timeout waiting for Govee light response');
        }
      });

      receiveSocket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = receiveSocket.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            print('Received response from Govee: $response');

            try {
              final Map<String, dynamic> responseData = jsonDecode(response);
              final ip = responseData['msg']?['data']?['ip'];

              if (ip != null) {
                print('Found Govee light IP: $ip');
                timeoutTimer?.cancel();
                receiveSocket.close();
                completer.complete(ip);
              }
            } catch (e) {
              print('Error parsing Govee response: $e');
            }
          }
        }
      });

      return completer.future;
    } catch (e) {
      print('Error in _initializeGovee: $e');
      rethrow;
    }
  }

  Future<void> handleEvent(WeatherEvent eventType, dynamic eventData) async {
    if (lightIp == 'Initializing...' || lightIp == 'Failed to initialize') {
      print('Light not initialized, attempting to reinitialize...');
      await initialize();
      if (lightIp == 'Failed to initialize') {
        print('Failed to reinitialize light');
        return;
      }
    }

    switch (eventType) {
      case WeatherEvent.weatherUpdate:
        await _handleWeatherUpdate(eventData);
        break;
      case WeatherEvent.weatherChange:
        await _handleWeatherChange(eventData);
        break;
      case WeatherEvent.statusChange:
        await _handleStatusChange(eventData);
        break;
    }
  }

  Future<void> _handleWeatherUpdate(String status) async {
    _trackevent = 'events.weather_update';
    _trackstatus = status;
    
    switch (status) {
      case 'about_to_rain':
        await sendGoveeColorCommand(255, 0, 255); // Purple
        break;
      case 'about_to_dry_up':
        await sendGoveeColorCommand(0, 255, 0); // Green
        break;
    }
  }

  Future<void> _handleWeatherChange(String status) async {
    _trackevent = 'events.weather_change';
    _trackstatus = status;
    
    switch (status) {
      case 'wet':
        await sendGoveeColorCommand(0, 10, 255); // Blue
        await _audioService.playRainSound();
        break;
      case 'dry':
        await sendGoveeColorCommand(255, 255, 255); // White
        await _audioService.stopRainSound();
        break;
    }
  }

  Future<void> _handleStatusChange(Map<String, dynamic> status) async {
    if (status['new'] == 'suspended') {
      await sendGoveeColorCommand(255, 0, 0); // Red
    } else if (status['new'] == 'running' || status['new'] == 'restarting') {
      if (_trackevent.isNotEmpty && 
          (_trackstatus == 'about_to_rain' || 
           _trackstatus == 'about_to_dry_up' || 
           _trackstatus == 'wet' || 
           _trackstatus == 'dry')) {
        await handleEvent(WeatherEvent.fromString(_trackevent), _trackstatus);
      }
    }
  }

  Future<void> sendGoveeColorCommand(int red, int green, int blue) async {
    if (lightIp == 'Initializing...' || lightIp == 'Failed to initialize') {
      print('Cannot send command - light not initialized');
      return;
    }

    try {
      final command = jsonEncode({
        "msg": {
          "cmd": "colorwc",
          "data": {
            "color": {"r": red, "g": green, "b": blue},
            "colorTemInKelvin": 0
          }
        }
      });

      final sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      sendSocket.send(utf8.encode(command), InternetAddress(lightIp), portSend);
      sendSocket.close();
      print('Sent color command to Govee light: $command');
    } catch (e) {
      print('Error sending command to Govee light: $e');
    }
  }
}