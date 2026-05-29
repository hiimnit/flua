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
    expect(state['y'], closeTo(3.14, 0.001));

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

    state.doString('''
      function get_table()
        return {a = 1, b = "hello", c = true}
      end
    ''');

    final results = state.call('get_table');
    expect(results.length, 1);
    final table = results[0] as Map;
    expect(table['a'], 1);
    expect(table['b'], 'hello');
    expect(table['c'], isTrue);
  });

  test('set and get list as table', () {
    final state = LuaState();
    addTearDown(state.close);

    state.doString('''
      function get_list()
        return {10, 20, 30}
      end
    ''');

    final results = state.call('get_list');
    expect(results.length, 1);
    final list = results[0] as Map;
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

  test('_registryIndex matches C LUA_REGISTRYINDEX', () {
    expect(kLuaRegistryIndex, equals(bindings.flua_lua_registryindex()));
  });

  test('pushFunction registers a C function in Lua', () {
    final state = LuaState();
    addTearDown(state.close);

    final ptr = Pointer.fromFunction<flua_CFunctionFunction>(_testCFunction, 0);
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
}
