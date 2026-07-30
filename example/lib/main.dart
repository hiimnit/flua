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

      state.pushFunction(_dartPrintNumberPointer);
      state.setGlobal('dartprintnumber');

      state.doString('dartprintnumber(42)');
      buffer.writeln('dartprintnumber(42)');

      buffer.writeln('\n5. Call async Dart functions from Lua:');
      state.registerGlobalAsyncFunction('fetch', (args) async {
        final url = args.isNotEmpty ? args.first : '';
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return ['<html>content of $url</html>'];
      });
      state.registerGlobalAsyncFunction('confirm', (args) async {
        final confirmed = await showConfirmDialog(
          context,
          content: args.first.toString(),
        );
        return [confirmed];
      });

      final asyncResults = await state.runAsync('''
        local confirmed = confirm("Async confirmation?")
        local page = fetch("https://example.com")
        return confirmed, page
      ''');
      buffer.writeln('   confirmed = ${asyncResults.first}');
      buffer.writeln('   body = ${asyncResults.last}');
    } finally {
      state.close();
    }

    setState(() {
      _output = buffer.toString();
    });
  }

  static int dartPrintNumber(Pointer<Void> l) {
    final state = LuaState.fromState(l);
    final arg1 = state.optNumber(1, 0);

    // ignore: avoid_print
    print('> print from dart: $arg1');
    return 0;
  }

  static final _dartPrintNumberPointer =
      Pointer.fromFunction<Int Function(Pointer<Void>)>(dartPrintNumber, 0);

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

class ConfirmDialog extends StatelessWidget {
  final String content;

  const ConfirmDialog({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Warning'),
      content: Text(content),
      actions: <Widget>[
        TextButton(
          child: Text('NO'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ElevatedButton(
          child: Text('YES'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(content: content),
  );

  return result ?? false;
}
