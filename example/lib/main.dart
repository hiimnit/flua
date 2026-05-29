import 'dart:ffi';

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
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flua Demo')),
        body: switch (currentPageIndex) {
          0 => SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _TestWidget(),
          ),
          _ => Padding(
            padding: const EdgeInsets.all(8.0),
            child: _ReplWidget(),
          ),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentPageIndex,
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.text_decrease_sharp),
              label: 'Test',
            ),
            NavigationDestination(icon: Icon(Icons.explore), label: 'REPL'),
          ],
        ),
      ),
    );
  }
}

class _ReplWidget extends StatefulWidget {
  const _ReplWidget();

  @override
  State<_ReplWidget> createState() => __ReplWidgetState();
}

class __ReplWidgetState extends State<_ReplWidget> {
  final output = ListChangeNotifier<String>();
  final state = LuaState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: output,
            builder: (context, child) => ListView.builder(
              shrinkWrap: true,
              itemCount: output.length,
              itemBuilder: (context, index) {
                final line = output[index];

                return Text(line);
              },
            ),
          ),
        ),
        TextField(
          onSubmitted: (value) {
            try {
              output.add(value);

              final pretop = state.top;
              state.doString(value);

              final results = state.popResults(pretop);
              final printedResult = results.isEmpty
                  ? '> '
                  : '> ${results.map((e) => e.toString()).join(', ')}';
              output.add(printedResult);

              for (final result in results) {
                if (result is! LuaFunction) {
                  continue;
                }

                final results = result.call();
                final printedResult = results.isEmpty
                    ? '>> '
                    : '>> ${results.map((e) => e.toString()).join(', ')}';
                output.add(printedResult);
              }
            } catch (e) {
              output.add('ERROR: $e');
            }
          },
        ),
      ],
    );
  }
}

class ListChangeNotifier<T> with ChangeNotifier {
  final List<T> list = [];

  void add(T value) {
    list.add(value);
    notifyListeners();
  }

  int get length => list.length;

  T operator [](int index) => list[index];
}

class _TestWidget extends StatefulWidget {
  const _TestWidget();

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> {
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

      state['table'] = {
        'k1': 'v1',
        'k2': 123,
        'k3': {'k4': 1, 'k5': null},
      };
      state.doString('print(table)');
      state.doString('''
        function dump(o)
          if type(o) == 'table' then
              local s = '{ '
              for k,v in pairs(o) do
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..k..'] = ' .. dump(v) .. ','
              end
              return s .. ' }'
          else
              return tostring(o)
          end
        end
        s = dump(table)
      ''');

      buffer.writeln('   dump(table) = ${state['s']}\n');

      state['list'] = [
        1,
        2,
        3,
        {'k': 'value'},
        'text',
      ];
      state.doString('print(list)');
      state.doString('s = dump(list)');
      buffer.writeln('   dump(list) = ${state['s']}\n');

      state['table'] = {
        'k1': 'v1',
        2: 123,
        'k3': {'k4': 1, 'k5': null},
      };
      state.doString('s = dump(table)');
      buffer.writeln('   dump(table) = ${state['s']}\n');

      state.pushFunction(_dartPrintPointer);
      state.setGlobal('dartprint');
      state.doString('dartprint(1)');
      buffer.writeln('dartprint(1)');
    } finally {
      state.close();
    }

    setState(() {
      _output = buffer.toString();
    });
  }

  static int dartPrint(Pointer<Void> state) {
    print('> print from dart, ');
    return 0;
  }

  static final _dartPrintPointer =
      Pointer.fromFunction<Int Function(Pointer<Void>)>(dartPrint, 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16.0,
      children: [
        ElevatedButton(onPressed: _runDemo, child: const Text('Run Demo')),
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
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),
      ],
    );
  }
}
