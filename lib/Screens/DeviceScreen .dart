import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<Widget> characteristicTiles;

  const ServiceTile({
    required this.service,
    required this.characteristicTiles,
  });

  @override
  Widget build(BuildContext context) {
    // Implement the UI for the ServiceTile
    return ListTile(
      title: Text(service.uuid.toString()),
      // Implement the rest of the UI for the ServiceTile
    );
  }
}


class DescriptorTile extends StatelessWidget {
  final BluetoothDescriptor descriptor;
  final VoidCallback onReadPressed;
  final VoidCallback onWritePressed;

  const DescriptorTile({
    required this.descriptor,
    required this.onReadPressed,
    required this.onWritePressed,
  });

  @override
  Widget build(BuildContext context) {
    // Retrieve the descriptor UUID
    final uuid = descriptor.uuid;

    return ListTile(
      // Customize the ListTile based on the descriptor
      title: Text('Descriptor: $uuid'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            child: const Text('Read'),
            onPressed: onReadPressed,
          ),
          ElevatedButton(
            child: const Text('Write'),
            onPressed: onWritePressed,
          ),
        ],
      ),
    );
  }
}

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final VoidCallback onReadPressed;
  final VoidCallback onWritePressed;
  final VoidCallback onNotificationPressed;
  final List<Widget> descriptorTiles;

  const CharacteristicTile({
    required this.characteristic,
    required this.onReadPressed,
    required this.onWritePressed,
    required this.onNotificationPressed,
    required this.descriptorTiles,
  });

  @override
  Widget build(BuildContext context) {
    // Implement the UI for the CharacteristicTile
    return ListTile(
      title: Text(characteristic.uuid.toString()),
      // Implement the rest of the UI for the CharacteristicTile
    );
  }
}
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  List<int> _getRandomBytes() {
    final math = Random();
    return [
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255),
      math.nextInt(255)
    ];
  }

List<Widget> _buildServiceTiles(List<BluetoothService> services) {
  return services.map((s) {
    List<Widget> characteristicTiles = s.characteristics.map((c) {
      List<Widget> descriptorTiles = List<Widget>.from(
        c.descriptors.map(
          (d) => DescriptorTile(
            descriptor: d,
            onReadPressed: () => d.read(),
            onWritePressed: () => d.write(_getRandomBytes()),
          ),
        ),
      );

      return CharacteristicTile(
        characteristic: c,
        onReadPressed: () => c.read(),
        onWritePressed: () async {
          await c.write(_getRandomBytes(), withoutResponse: true);
          await c.read();
        },
        onNotificationPressed: () async {
          await c.setNotifyValue(!c.isNotifying);
          await c.read();
        },
        descriptorTiles: descriptorTiles,
      );
    }).toList();

    return ServiceTile(
      service: s,
      characteristicTiles: characteristicTiles,
    );
  }).toList();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return TextButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        ?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    snapshot.data == BluetoothDeviceState.connected
                        ? const Icon(Icons.bluetooth_connected)
                        : const Icon(Icons.bluetooth_disabled),
                    snapshot.data == BluetoothDeviceState.connected
                        ? StreamBuilder<int>(
                        stream: rssiStream(),
                        builder: (context, snapshot) {
                          return Text(snapshot.hasData ? '${snapshot.data}dBm' : '',
                              style: Theme.of(context).textTheme.caption);
                        })
                        : Text('', style: Theme.of(context).textTheme.caption),
                  ],
                ),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => device.discoverServices(),
                      ),
                      const IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<int>(
              stream: device.mtu,
              initialData: 0,
              builder: (c, snapshot) => ListTile(
                title: const Text('MTU Size'),
                subtitle: Text('${snapshot.data} bytes'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => device.requestMtu(223),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: const [],
              builder: (c, snapshot) {
                return Column(
                  children: List.empty()
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Stream<int> rssiStream() async* {
    var isConnected = true;
    final subscription = device.state.listen((state) {
      isConnected = state == BluetoothDeviceState.connected;
    });
    while (isConnected) {
      yield await device.readRssi();
      await Future.delayed(const Duration(seconds: 1));
    }
    subscription.cancel();
    // Device disconnected, stopping RSSI stream
  }
}