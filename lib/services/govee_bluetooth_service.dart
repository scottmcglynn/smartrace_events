// lib/services/govee_bluetooth_service.dart
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/weather_event.dart';
import 'audio_service.dart';

class GoveeBluetoothService {
  static final GoveeBluetoothService _instance = GoveeBluetoothService._internal();
  factory GoveeBluetoothService() => _instance;
  
  // Govee specific UUIDs
  static const String GOVEE_SERVICE_UUID = "00010203-0405-0607-0809-0a0b0c0d1910";
  static const String GOVEE_CHARACTERISTIC_UUID = "00010203-0405-0607-0809-0a0b0c0d2b11";
  static const String DEVICE_NAME_PATTERN = "ihoment_H613E";
  DateTime? _lastCommandTime;
  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isReconnecting = false;
  StreamSubscription? _connectionSubscription;
  // final AudioService _audioService = AudioService();
  
  String _trackevent = 'events.weather_change';
  String _trackstatus = 'dry';

  GoveeBluetoothService._internal() {
    _initializeConnection();
  }

  Future<void> _initializeConnection() async {
  print('Initializing Bluetooth connection...');
  try {
    // Instead of turning on, check the state
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    
    if (state != BluetoothAdapterState.on) {
      print('Bluetooth is not enabled. Please enable Bluetooth in System Settings.');
      return;
    }
    
    await _connectToDevice();
    
    if (!_isConnected) {
      Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (!_isConnected) {
          print('Attempting to reconnect...');
          await _connectToDevice();
        } else {
          timer.cancel();
        }
      });
    }
  } catch (e) {
    print('Error initializing Bluetooth: $e');
  }
}

  Future<void> _handleDisconnection() async {
    print('Handle disconnection called');
    if (_isReconnecting) return;
    
    _isConnected = false;
    _writeCharacteristic = null;

    _isReconnecting = true;
    bool reconnected = false;
    int attempts = 0;
    const maxAttempts = 3;

    while (!reconnected && attempts < maxAttempts) {
      attempts++;
      print('Reconnection attempt $attempts of $maxAttempts');
      
      try {
        reconnected = await _reconnectToDevice();
        if (reconnected) {
          print('Reconnection successful');
          _isConnected = true;
          break;
        }
      } catch (e) {
        print('Reconnection attempt failed: $e');
      }

      if (!reconnected && attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }

    _isReconnecting = false;
    if (!reconnected) {
      print('All reconnection attempts failed');
      _connectToDevice();
    }
  }

  Future<bool> _checkConnectionStatus() async {
    if (_targetDevice == null) return false;
    
    try {
      // In flutter_blue_plus, we can check the connection state directly
      final state = await _targetDevice!.connectionState.first;
      bool isStillConnected = state == BluetoothConnectionState.connected;
      
      if (!isStillConnected) {
        _isConnected = false;
        _writeCharacteristic = null;
      }
      
      return isStillConnected;
    } catch (e) {
      print('Error checking connection status: $e');
      _isConnected = false;
      _writeCharacteristic = null;
      return false;
    }
  }

  Future<bool> _reconnectToDevice() async {
    if (_targetDevice == null) return false;
    print('Attempting to reconnect to device: ${_targetDevice!.platformName}');
    
    try {
      await _targetDevice!.connect(timeout: const Duration(seconds: 15));
      
      // Get just the service we need
      final targetService = await _targetDevice!.discoverServices()
          .then((services) => services.firstWhere(
            (s) => s.uuid.str == GOVEE_SERVICE_UUID,
            orElse: () => throw Exception('Service not found'),
          ));
      
      // Get the characteristic we need
      final targetChar = targetService.characteristics.firstWhere(
        (c) => c.uuid.str == GOVEE_CHARACTERISTIC_UUID,
        orElse: () => throw Exception('Characteristic not found'),
      );

      // Set up notifications to maintain connection
      if (targetChar.properties.notify) {
        await targetChar.setNotifyValue(true);
        targetChar.onValueReceived.listen((value) {
          // Just keeping connection alive
          print('Received notification from device');
        });
      }

      _writeCharacteristic = targetChar;
      _isConnected = true;
      _setupDeviceStateListener(_targetDevice!);
      return true;

    } catch (e) {
      print('Error reconnecting: $e');
      _isConnected = false;
      _writeCharacteristic = null;
      return false;
    }
  }

  Future<void> _connectToDevice() async {
    print('Starting Bluetooth connection process...');
    if (_isConnected || _isScanning) {
      print('Already connected or scanning, skipping connection process');
      return;
    }

    _isScanning = true;
    print('Starting scan for Govee device...');
    
    Set<String> attemptedDevices = {};
    StreamSubscription? scanSubscription;
    
    try {
      // Start fresh scan
      await FlutterBluePlus.stopScan();
      
      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        if (!_isConnected) {
          for (ScanResult result in results) {
            if (attemptedDevices.contains(result.device.remoteId.str)) {
              continue;
            }
            if (!result.device.platformName.contains(DEVICE_NAME_PATTERN)) {
              continue;
            }
            
            attemptedDevices.add(result.device.remoteId.str);
            print('Found target device: ${result.device.platformName} (${result.device.remoteId})');
            
            bool isGoveeDevice = await _checkAndConnectGoveeDevice(result.device);
            if (isGoveeDevice) {
              await FlutterBluePlus.stopScan();
              scanSubscription?.cancel();
              _isScanning = false;
              break;
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false
      );
      
      await Future.delayed(const Duration(seconds: 10));
      
      if (_isScanning) {
        await FlutterBluePlus.stopScan();
        scanSubscription.cancel();
        _isScanning = false;
      }
    } catch (e) {
      print('Error during scan/connect: $e');
      _isScanning = false;
      await FlutterBluePlus.stopScan();
    }
  }

  Future<bool> _checkAndConnectGoveeDevice(BluetoothDevice device) async {
  try {
    print('Attempting to connect to device: ${device.platformName} (${device.remoteId})');
    
    await device.connect(timeout: const Duration(seconds: 15), mtu: 23);
    print('Basic connection established');
    
    try {
      await device.createBond();
      print('Bond created with device');
    } catch (e) {
      print('Bond creation not supported or failed: $e');
    }
    
    print('Discovering target service...');
    BluetoothService? targetService;
    List<BluetoothService> services = await device.discoverServices();
    targetService = services.cast<BluetoothService?>().firstWhere(
      (s) => s?.uuid.str == GOVEE_SERVICE_UUID,
      orElse: () => null
    );
    
    if (targetService == null) {
      print('Target service not found');
      await device.disconnect();
      return false;
    }

    print('Found target service, getting characteristics...');
    
    // Get both characteristics
    BluetoothCharacteristic? writeChar = targetService.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
      (c) => c?.uuid.str == GOVEE_CHARACTERISTIC_UUID,
      orElse: () => null
    );

    BluetoothCharacteristic? notifyChar = targetService.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
      (c) => c?.uuid.str == "00010203-0405-0607-0809-0a0b0c0d2b10",
      orElse: () => null
    );

    if (writeChar == null) {
      print('Write characteristic not found');
      await device.disconnect();
      return false;
    }

    print('Found characteristics, setting up connection...');

    // Set up notifications on the notification characteristic
    if (notifyChar != null && notifyChar.properties.notify) {
      print('Setting up notifications on 2b10 characteristic...');
      try {
        await notifyChar.setNotifyValue(true);
        notifyChar.lastValueStream.listen(
          (value) {
            print('2b10 Notification received: ${value.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(', ')}');
          },
          onError: (error) {
            print('2b10 Notification error: $error');
          }
        );
        print('2b10 notification listener set up successfully');
      } catch (e) {
        print('Error setting up 2b10 notifications: $e');
        // Continue even if notification setup fails
      }
    }

    // Set up notifications on the write characteristic if it supports it
    if (writeChar.properties.notify) {
      print('Setting up notifications on write characteristic...');
      try {
        await writeChar.setNotifyValue(true);
        writeChar.lastValueStream.listen(
          (value) {
            print('Write char notification: ${value.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(', ')}');
          },
          onError: (error) {
            print('Write char notification error: $error');
          }
        );
        print('Write characteristic notification listener set up successfully');
      } catch (e) {
        print('Error setting up write characteristic notifications: $e');
      }
    }

    // Store connection info
    _writeCharacteristic = writeChar;
    _targetDevice = device;
    _isConnected = true;
    
    // Set up connection monitoring
    _setupDeviceStateListener(device);
    
    print('Device setup completed successfully');
    return true;

  } catch (e) {
    print('Error in connection process: $e');
    try {
      await device.disconnect();
    } catch (e) {
      print('Error disconnecting after failure: $e');
    }
    return false;
  }
}

void _setupDeviceStateListener(BluetoothDevice device) {
  _connectionSubscription?.cancel();
  _connectionSubscription = device.connectionState.listen((state) {
    print('Connection state changed: $state');
    print('Current time: ${DateTime.now()}');
    print('Last successful command time: $_lastCommandTime');
    if (state == BluetoothConnectionState.disconnected) {
      print('Device disconnected. Device ID: ${device.remoteId}');
      _handleDisconnection();
    }
  });
}

  Future<void> _sendCommand(List<int> command) async {
    print('GoveeBluetoothService: Attempting to send command: ${command.map((e) => '0x${e.toRadixString(16).padLeft(2, '0')}').join(', ')}');
    
    bool isStillConnected = await _checkConnectionStatus();
    if (!isStillConnected) {
      print('GoveeBluetoothService: Not connected - attempting to reconnect before sending command');
      bool reconnected = await _reconnectToDevice();
      if (!reconnected) {
        print('GoveeBluetoothService: Still not connected - command not sent');
        return;
      }
    }

    try {
      await _writeCharacteristic!.write(command, withoutResponse: true);
      _lastCommandTime = DateTime.now();
      print('GoveeBluetoothService: Command sent successfully');
    } catch (e) {
      print('GoveeBluetoothService: Error sending command: $e');
      _isConnected = false;
      await _reconnectToDevice();
      if (_isConnected && _writeCharacteristic != null) {
        try {
          await _writeCharacteristic!.write(command, withoutResponse: true);
          print('GoveeBluetoothService: Command sent successfully after reconnection');
        } catch (e) {
          print('GoveeBluetoothService: Error sending command after reconnection: $e');
        }
      }
    }
  }

  Future<void> handleWeatherEvent(WeatherEvent eventType, dynamic eventData) async {
    print('GoveeBluetoothService: Received weather event - Type: $eventType, Data: $eventData');
    
    if (!_isConnected) {
      print('GoveeBluetoothService: Not connected, attempting to connect...');
      await _connectToDevice();
      if (!_isConnected) {
        print('GoveeBluetoothService: Failed to connect to device');
        return;
      }
    }

    print('GoveeBluetoothService: Processing event...');
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
        await _sendCommand(commandColor(255, 0, 255)); // Purple
        break;
      case 'about_to_dry_up':
        await _sendCommand(commandColor(0, 255, 0)); // Green
        break;
    }
  }

  Future<void> _handleWeatherChange(String status) async {
    _trackevent = 'events.weather_change';
    _trackstatus = status;
    
    switch (status) {
      case 'wet':
        await _sendCommand(commandColor(0, 10, 255)); // Blue
        // await _audioService.playRainSound();
        break;
      case 'dry':
        await _sendCommand(commandColor(255, 255, 255)); // White
        // await _audioService.stopRainSound();
        break;
    }
  }

  Future<void> _handleStatusChange(Map<String, dynamic> status) async {
    if (status['new'] == 'suspended') {
      await _sendCommand(commandColor(255, 0, 0)); // Red
    } else if (status['new'] == 'running' || status['new'] == 'restarting') {
      if (_trackevent.isNotEmpty && 
          (_trackstatus == 'about_to_rain' || 
           _trackstatus == 'about_to_dry_up' || 
           _trackstatus == 'wet' || 
           _trackstatus == 'dry')) {
        await handleWeatherEvent(WeatherEvent.fromString(_trackevent), _trackstatus);
      }
    }
  }

  static List<int> commandColor(int r, int g, int b) {
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);
    return [0x33, 0x05, 0x02, r, g, b, 0x00, 0xFF, 0xAE, 0x54, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, (0x31 ^ r ^ g ^ b)];
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _targetDevice?.disconnect();
  }
}