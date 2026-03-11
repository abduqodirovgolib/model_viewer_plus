import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Model Viewer Plus'),
        ),
        body: Container(
          color: Colors.red,
          child: ModelViewerPlus(
            modelPath: 'assets/models/heart.glb',
            iblPath: 'assets/models/giuseppe_bridge_4k_ibl.ktx',
            // backgroundPath: 'assets/models/san_giuseppe_bridge_4k.hdr',
          ),
        ),
      ),
    );
  }
}
