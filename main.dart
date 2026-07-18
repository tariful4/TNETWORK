import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const MeshApp());

class MeshApp extends StatelessWidget {
  const MeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MeshScreen(),
    );
  }
}

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  final String myUniqueId = const Uuid().v4().substring(0, 8); // Example Unique ID
  final Strategy strategy = Strategy.P2P_CLUSTER; // Hajar hajar device connect korar jonno ideal
  
  // Connected direct neighbors track korar jonno
  Map<String, String> connectedDevices = {}; 
  List<String> messages = [];
  
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _targetIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkPermissions();
    startMeshNetwork();
  }

  // Bluetooth, Location permission check (Mesh network er jonno must)
  void checkPermissions() async {
    bool hasLocation = await Nearby().checkLocationPermission();
    if (!hasLocation) {
      await Nearby().askLocationPermission();
    }
  }

  // Network shuru kora - Advertising and Discovering eksathe chalano
  void startMeshNetwork() async {
    try {
      // 1. Advertise kora (Nijeke onnor kache drisshomankora)
      await Nearby().startAdvertising(
        myUniqueId,
        strategy,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            setState(() => connectedDevices[id] = id);
          }
        },
        onDisconnected: (id) {
          setState(() => connectedDevices.remove(id));
        },
      );

      // 2. Discover kora (Alpaser onno device khoja)
      await Nearby().startDiscovery(
        myUniqueId,
        strategy,
        onDeviceFound: (id, name, serviceId) {
          // Automatic connection request pathano
          Nearby().requestConnection(
            myUniqueId,
            id,
            onConnectionInitiated: onConnectionInitiated,
          );
        },
        onDeviceLost: (id) {},
      );
    } catch (e) {
      print("Error starting mesh: $e");
    }
  }

  // Connection process handler
  void onConnectionInitiated(String id, ConnectionInfo info) {
    // Automatic accept connection
    Nearby().acceptConnection(
      id,
      onPayloadReceived: (endId, payload) {
        if (payload.type == PayloadType.BYTES) {
          String jsonStr = utf8.decode(payload.bytes!);
          handleIncomingMessage(jsonStr);
        }
      },
    );
  }

  // Routing Logic: Message nije rakha naki agiye dewa (Hop kora)
  void handleIncomingMessage(String jsonStr) {
    Map<String, dynamic> data = jsonDecode(jsonStr);
    String target = data['target'];
    String sender = data['sender'];
    String body = data['body'];
    String msgId = data['msgId'];

    if (target == myUniqueId) {
      // Message amari jonno asche!
      setState(() {
        messages.add("From $sender: $body");
      });
    } else {
      // Amari jonno na, tai networking routing onujayi message arekjonke pass forward korbo
      forwardMessage(jsonStr);
    }
  }

  // Routing Function
  void sendMessage(String target, String body) {
    Map<String, dynamic> packet = {
      'msgId': Random().nextInt(100000).toString(),
      'sender': myUniqueId,
      'target': target,
      'body': body
    };
    
    String jsonStr = jsonEncode(packet);
    
    // Tar kache thaka shob direct connected node e message pathano
    connectedDevices.forEach((id, value) {
      Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(jsonStr)));
    });
    
    setState(() {
      messages.add("To $target: $body");
    });
  }

  void forwardMessage(String jsonStr) {
    // Message forward kora onno device gulote jara direct connected ache
    connectedDevices.forEach((id, value) {
      Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(jsonStr)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mesh ID: $myUniqueId (Active Nodes: ${connectedDevices.length})")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _targetIdController,
              decoration: const InputDecoration(labelText: "Target Unique ID (e.g. Jessore User)"),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(labelText: "Type Message"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_targetIdController.text.isNotEmpty && _msgController.text.isNotEmpty) {
                      sendMessage(_targetIdController.text, _msgController.text);
                      _msgController.clear();
                    }
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (c, i) => ListTile(title: Text(messages[i])),
            ),
          ),
        ],
      ),
    );
  }
}
