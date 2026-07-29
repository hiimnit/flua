import 'dart:ffi';

import 'package:test/test.dart';

import 'package:flua/flua.dart';
import 'package:flua/flua_bindings_generated.dart' as bindings;

int _testCFunction(Pointer<Void> L) => 0;

void main() {
  test('create and close Lua state', () {
    final state = LuaState();
    expect(state.isClosed, isFalse);
    state.close();
    expect(state.isClosed, isTrue);
  });

  test('execute Lua code', () {
    final state = LuaState();
    addTearDown(state.close);
    expect(() => state.doString('x = 1 + 2'), returnsNormally);
  });

  test('set and get global variables', () {
    final state = LuaState();
    addTearDown(state.close);

    state['x'] = 42;
    expect(state['x'], 42);

    state['y'] = 3.14;
    expect(state['y'], 3.14);

    state['name'] = 'Flua';
    expect(state['name'], 'Flua');

    state['active'] = true;
    expect(state['active'], isTrue);

    state['nil'] = null;
    expect(state['nil'], isNull);
  });

  test('call Lua functions', () {
    final state = LuaState();
    addTearDown(state.close);

    state.doString('''
      function add(a, b)
        return a + b
      end
    ''');

    final result = state.call('add', [5, 7]);
    expect(result, [12.0]);
  });

  test('error handling', () {
    final state = LuaState();
    addTearDown(state.close);

    expect(
      () => state.doString('invalid syntax!!!'),
      throwsA(isA<LuaException>()),
    );
  });

  test('Lua state type checking', () {
    final state = LuaState();
    addTearDown(state.close);

    state['x'] = 10;
    expect(state.typeOf('x'), LuaType.number);

    state['name'] = 'test';
    expect(state.typeOf('name'), LuaType.string);

    expect(state.typeOf('nonexistent'), LuaType.nil);
  });

  test('finalizer closes Lua state', () {
    final state = LuaState();
    expect(state.isClosed, isFalse);
    state.close();
    expect(state.isClosed, isTrue);
  });

  test('set and get tables', () {
    final state = LuaState();
    addTearDown(state.close);

    state['table'] = {'a': 1, 'b': "hello", 'c': true};

    final result = state['table'];
    expect(result is Map, isTrue);

    final table = result as Map;
    expect(table['a'], 1);
    expect(table['b'], 'hello');
    expect(table['c'], isTrue);
  });

  test('set and get list as table', () {
    final state = LuaState();
    addTearDown(state.close);

    state['list'] = [10, 20, 30];

    final result = state['list'];
    expect(result is Map, isTrue);

    final list = result as Map;
    expect(list[1], 10);
    expect(list[2], 20);
    expect(list[3], 30);
  });

  test('negative integer values', () {
    final state = LuaState();
    addTearDown(state.close);

    state['neg'] = -42;
    expect(state['neg'], -42);
  });

  test('boolean false', () {
    final state = LuaState();
    addTearDown(state.close);

    state['flag'] = false;
    expect(state['flag'], isFalse);
  });

  test('kLuaRegistryIndex matches C LUA_REGISTRYINDEX', () {
    expect(kLuaRegistryIndex, equals(bindings.registryindex()));
  });

  test('pushFunction registers a C function in Lua', () {
    final state = LuaState();
    addTearDown(state.close);

    final ptr = Pointer.fromFunction<CFunctionFunction>(_testCFunction, 0);
    state.pushFunction(ptr);
    state.setGlobal('dartfunction');
    expect(state.typeOf('dartfunction'), LuaType.function);
  });

  test('get function from Lua, call it, unref it', () {
    final state = LuaState();
    addTearDown(state.close);

    state.doString('''
      function make_adder(x)
        return function(a) return a + x end
      end
    ''');

    final results = state.call('make_adder', [5]);
    expect(results.length, 1);
    expect(results[0], isA<LuaFunction>());

    final fn = results[0] as LuaFunction;
    expect(fn.valid, isTrue);

    final callResults = fn.call([10]);
    expect(callResults, [15.0]);

    fn.unref();
    expect(fn.valid, isFalse);
  });

  group('async functions', () {
    test(
      'await an async Dart function from Lua by loading and executing string',
      () async {
        final state = LuaState();
        addTearDown(state.close);

        state.registerGlobalAsyncFunction('fetch', (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ['result for ${args.first}'];
        });

        final results = await state.runAsync('''
        local data = fetch("url")
        return data, "done"
      ''');

        expect(results, ['result for url', 'done']);
      },
    );

    test(
      'await an async Dart function from Lua by calling existing Lua function',
      () async {
        final state = LuaState();
        addTearDown(state.close);

        state.registerGlobalAsyncFunction('fetch', (args) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ['result for ${args.first}'];
        });

        state.doString('''
        function fetch_url()
          return fetch("url")
        end
      ''');

        final value = state['fetch_url'];
        expect(value, TypeMatcher<LuaFunction>());
        final function = value as LuaFunction;

        final results = await function.callAsync();
        expect(results, ['result for url']);
      },
    );

    test('async calls run in order and see side effects', () async {
      final state = LuaState();
      addTearDown(state.close);

      final calls = <int>[];
      state.registerGlobalAsyncFunction('step', (args) async {
        final n = (args.first as num).toInt();
        await Future<void>.delayed(Duration(milliseconds: 10 - n));
        calls.add(n);
        return [n * 10];
      });

      final results = await state.runAsync('''
        local a = step(1)
        local b = step(2)
        local c = step(3)
        return a + b + c
      ''');

      expect(calls, [1, 2, 3]);
      expect(results, [60.0]);
    });

    test('multiple arguments and multiple return values', () async {
      final state = LuaState();
      addTearDown(state.close);

      state.registerGlobalAsyncFunction('divmod', (args) async {
        final a = (args[0] as num).toInt();
        final b = (args[1] as num).toInt();
        return [a ~/ b, a % b];
      });

      final results = await state.runAsync('''
        local q, r = divmod(17, 5)
        return q, r
      ''');

      expect(results, [3.0, 2.0]);
    });

    test('handler error is raised in Lua and catchable via pcall', () async {
      final state = LuaState();
      addTearDown(state.close);

      state.registerGlobalAsyncFunction('boom', (args) async {
        throw StateError('kaboom');
      });

      final results = await state.runAsync('''
        local ok, err = pcall(function() return boom() end)
        return ok, err
      ''');

      expect(results[0], isFalse);
      expect(results[1], contains('kaboom'));
    });

    test('uncaught handler error propagates as LuaException', () async {
      final state = LuaState();
      addTearDown(state.close);

      state.registerGlobalAsyncFunction('boom', (args) async {
        throw StateError('kaboom');
      });

      await expectLater(
        state.runAsync('return boom()'),
        throwsA(isA<LuaException>()),
      );
    });

    test('async call followed by a bare yield is rejected', () async {
      final state = LuaState();
      addTearDown(state.close);

      state.registerGlobalAsyncFunction('ping', (args) async => ['pong']);

      await expectLater(
        state.runAsync('''
          local r = ping()
          coroutine.yield(r)
        '''),
        throwsA(isA<LuaException>()),
      );
    });

    test('bare top-level yield is rejected', () async {
      final state = LuaState();
      addTearDown(state.close);

      state.registerGlobalAsyncFunction('noop', (args) async => []);

      await expectLater(
        state.runAsync('coroutine.yield(1, 2, 3)'),
        throwsA(isA<LuaException>()),
      );
    });

    test('valueless and non-numeric yields are rejected', () async {
      final state = LuaState();
      addTearDown(state.close);

      state.registerGlobalAsyncFunction('noop', (args) async => []);

      for (final rogue in ['coroutine.yield()', 'coroutine.yield("x")']) {
        await expectLater(
          state.runAsync(rogue),
          throwsA(isA<LuaException>()),
          reason: 'expected $rogue to be rejected',
        );
      }
    });

    test('out-of-range id yield is rejected', () async {
      final state = LuaState();
      addTearDown(state.close);

      state.registerGlobalAsyncFunction('noop', (args) async => []);

      await expectLater(
        state.runAsync('coroutine.yield(99)'),
        throwsA(isA<LuaException>()),
      );
    });

    test('args are separated from the leading id', () async {
      final state = LuaState();
      addTearDown(state.close);

      late List<Object?> seen;
      state.registerGlobalAsyncFunction('capture', (args) async {
        seen = args;
        return [];
      });

      await state.runAsync('capture(0, "a", true)');
      expect(seen, [0.0, 'a', true]);

      await state.runAsync('capture()');
      expect(seen, isEmpty);
    });
  });
}
