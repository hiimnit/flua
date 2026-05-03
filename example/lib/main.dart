import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flua/flua.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _output = '';

  @override
  void initState() {
    super.initState();
    _runDemo();
  }

  Future<void> _runDemo() async {
    final state = LuaState();
    final buffer = StringBuffer();

    try {
      buffer.writeln('1. Execute Lua code:');
      state.doString('print("Hello from Lua!")');
      buffer.writeln('   Lua ran successfully\n');

      buffer.writeln('2. Set and get global variables:');
      state['x'] = 10;
      state['y'] = 3.14;
      state['name'] = 'Flua';
      state['active'] = true;
      buffer.writeln('   x = ${state['x']}');
      buffer.writeln('   y = ${state['y']}');
      buffer.writeln('   name = "${state['name']}"');
      buffer.writeln('   active = ${state['active']}\n');

      buffer.writeln('3. Call Lua functions:');
      state.doString('''
        function add(a, b)
          return a + b
        end
        
        function greet(name)
          return "Hello, " .. name .. "!"
        end
        
        function multiReturn()
          return 1, 2, 3
        end
      ''');
      final addResult = state.call('add', [5, 7]);
      buffer.writeln('   add(5, 7) = ${addResult.first}\n');

      final greetResult = state.call('greet', ['World']);
      buffer.writeln('   greet("World") = "${greetResult.first}"\n');

      final multiResult = state.call('multiReturn');
      buffer.writeln('   multiReturn() = ${multiResult.join(", ")}\n');

      buffer.writeln('4. Error handling:');
      try {
        state.doString('this will fail');
      } on LuaException catch (e) {
        buffer.writeln('   Caught error: ${e.message}\n');
      }
    } finally {
      state.close();
    }

    setState(() {
      _output = buffer.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flua Demo')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16.0,
            children: [
              ElevatedButton(
                onPressed: _runDemo,
                child: const Text('Run Demo'),
              ),
              if (_output.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
