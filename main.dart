import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const TNetApp());

class TNetApp extends StatelessWidget {
  const TNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TNET - Offline Mesh',
      theme: ThemeData.dark(), // Dark mode for cool dev vibes
      home: const MeshScreen(),
    );
  }
}

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  // 1. Unique ID initialization
  final String myUniqueId = const Uuid().v4().substring(0, 8).toUpperCase();
  final Strategy strategy = Strategy.P2P_CLUSTER; // Supports multi-endpoint mesh
  
  Map<String, String> connectedNeighbors = {}; 
  List<String> chatHistory = [];
  
  // Infinite loop atkanor jonno Message Cache map
  // Key: messageId, Value: true (Otheba timestamp)
  Map<String, bool> processedMessages = {};

  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _targetIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    requestPermissions();
    activateMeshNetwork();
  }

  void requestPermissions() async {
    await Nearby().askLocationPermission();
    // Android 12+ er jonno Bluetooth permissions lagte pare
  }

  void activateMeshNetwork() async {
    try {
      // Background-e nijer discovery identity open rakha
      await Nearby().startAdvertising(
        myUniqueId,
        strategy,
        onConnectionInitiated: onConnectionSetup,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            setState(() => connectedNeighbors[id] = id);
          }
        },
        onDisconnected: (id) {
          setState(() => connectedNeighbors.remove(id));
        },
      );

      // Alpaser onno device automatic khuje connect kora
      await Nearby().startDiscovery(
        myUniqueId,
        strategy,
        onDeviceFound: (id, name, serviceId) {
          Nearby().requestConnection(myUniqueId, id, onConnectionInitiated: onConnectionSetup);
        },
        onDeviceLost: (id) {},
      );
    } catch (e) {
      debugPrint("Mesh Network Error: $e");
    }
  }

  void onConnectionSetup(String id, ConnectionInfo info) {
    // Kono manual tap charai automatic mesh peer accept hobe
    Nearby().acceptConnection(
      id,
      onPayloadReceived: (endId, payload) {
        if (payload.type == PayloadType.BYTES) {
          String rawJson = utf8.decode(payload.bytes!);
          processMeshPacket(rawJson);
        }
      },
    );
  }

  // --- FLOOD ROUTING PROTOCOL (Dhaka to Jessore Logic) ---
  void processMeshPacket(String rawJson) {
    try {
      Map<String, dynamic> packet = jsonDecode(rawJson);
      String msgId = packet['msgId'];
      String sender = packet['sender'];
      String target = packet['target'];
      String content = packet['content'];

      // Step A: Ei unique message ti ami age dekhchi? Dekhle skip (Loop prevention)
      if (processedMessages.containsKey(msgId)) return;

      // Mark as seen/processed
      processedMessages[msgId] = true;

      // Step B: Message ta ki amar jonno asche?
      if (target == myUniqueId) {
        setState(() {
          chatHistory.add("📩 [$sender]: $content");
        });
      } else {
        // Step C: Amar jonno na! Tar mane ami rasta (Hop point). Ebar baki shobaike forward kori.
        setState(() {
          chatHistory.add("🔄 Forwarded packet: $msgId from $sender to $target");
        });
        floodPacketToNeighbors(rawJson);
      }
    } catch (e) {
      debugPrint("Packet Parsing Error: $e");
    }
  }

  void initiateMessage(String destination, String messageText) {
    String uniqueMsgId = const Uuid().v4().substring(0, 6);
    
    Map<String, dynamic> packet = {
      'msgId': uniqueMsgId,
      'sender': myUniqueId,
      'target': destination.toUpperCase().trim(),
      'content': messageText
    };

    String payloadString = jsonEncode(packet);
    processedMessages[uniqueMsgId] = true; // Set current user message tracking

    floodPacketToNeighbors(payloadString);

    setState(() {
      chatHistory.add("📤 Sent to [$destination]: $messageText");
    });
  }

  void floodPacketToNeighbors(String packetData) {
    // Tar kache thaka dynamic net-er shob bonded device e data throw kora
    connectedNeighbors.forEach((endpointId, _) {
      Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(packetData)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("TNET Peer: $myUniqueId"),
        actions: [
          Chip(
            label: Text("Peers: ${connectedNeighbors.length}"),
            backgroundColor: Colors.green,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: TextField(
              controller: _targetIdController,
              decoration: const InputDecoration(
                labelText: "Target Device Unique ID (Jessore Peer)",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: chatHistory.length,
              itemBuilder: (context, index) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  value: Text(chatHistory[index]),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black26,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(hintText: "Type offline message..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () {
                    if (_targetIdController.text.isNotEmpty && _msgController.text.isNotEmpty) {
                      initiateMessage(_targetIdController.text, _msgController.text);
                      _msgController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
