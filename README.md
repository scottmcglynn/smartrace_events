# smartrace_events

A flutter project to consume SmartRace data events and update Govee bluetooth and Network aware light systems to reflect certain data events. The system currently updates weather events with different colors to help drivers know the current track conditions (dry, about to rain, wet, about to dry up) as well as race stop and restart events.

The weather wet event also plays a rain sound file on loop until the track drys up again.


Currently tested and working with Govee H7020 and H613E lights. 

The code for the H7020 works via LAN and should work for any Govee RGB lights on your LAN. The H613E code is via Bluetooth and currently is configured to look for a device with that name. Update this variable near the top of the govee_bluetooth_service.dar file as necessary if you have a different device. The other UUID values you see there are fairly common in Govee bluetooth so this should work with other models as well. There is a full Govee BT library on Github that could be used to make this code much more versatile. Perhaps in the future I'll try to put this in.

  static const String DEVICE_NAME_PATTERN = "ihoment_H613E"; 

On startup, the system will scan your LAN and look for a Govee device on it and initialize commununication with it if found. It will scan your network ports for a suitable local IP and display this in the UI. Use this IP in Smartrace for the data interface settings. 

While this project can be compiled as is for MacOS, Windows, iOS, Android, and Linux, the details of setting each one up are beyond the scope of this help file but many resources are available at flutter.dev and elsewhere. You will likely need to set some specific Bluetooth permissions in your build files for it to complie with BT functionality.
