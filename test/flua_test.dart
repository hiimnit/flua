import 'package:test/test.dart';

import 'package:flua/flua.dart';

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
}
