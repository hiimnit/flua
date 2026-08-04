import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'flua_bindings_generated.dart' as bindings;
export 'flua_bindings_generated.dart' show CFunctionFunction;

class LuaException implements Exception {
  final String message;

  LuaException(this.message);

  @override
  String toString() => 'LuaException: $message';
}

enum LuaType {
  none(-1),
  nil(0),
  boolean(1),
  lightuserdata(2),
  number(3),
  string(4),
  table(5),
  function(6),
  userdata(7),
  thread(8);

  final int value;

  const LuaType(this.value);

  static LuaType? from(int input) {
    for (final type in LuaType.values) {
      if (type.value == input) {
        return type;
      }
    }
    return null;
  }
}

const kLuaRegistryIndex = -1001000;

typedef LuaAsyncFunction = Future<List<Object?>> Function(List<Object?> args);

class LuaState implements Finalizable {
  final bindings.State _state;
  bool _closed = false;

  static final _finalizer = NativeFinalizer(Native.addressOf(bindings.close));

  final List<LuaAsyncFunction> _asyncHandlers = [];

  LuaState() : _state = bindings.create() {
    if (_state.address == 0) {
      throw LuaException('Failed to create Lua state');
    }
    _finalizer.attach(this, _state, detach: this);
  }

  LuaState.fromState(bindings.State state) : _state = state;

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _finalizer.detach(this);
    bindings.close(_state);
  }

  bool get isClosed => _closed;

  void doString(String code) {
    final nativeCode = code.toNativeUtf8();
    try {
      final status = bindings.dostring(_state, nativeCode.cast());
      if (status != 0) {
        throw LuaException(_errorMessage(_state));
      }
    } finally {
      malloc.free(nativeCode);
    }
  }

  LuaType? typeOf(String name) {
    final nativeName = name.toNativeUtf8();
    try {
      final type = bindings.getglobaltype(_state, nativeName.cast());
      return LuaType.from(type);
    } finally {
      malloc.free(nativeName);
    }
  }

  LuaType? typeAt(int idx) {
    final type = bindings.type(_state, idx);
    return LuaType.from(type);
  }

  Object? operator [](String name) {
    final nativeName = name.toNativeUtf8();
    try {
      final type = bindings.getglobal(_state, nativeName.cast());
      return _getValueOfType(-1, LuaType.from(type));
    } finally {
      malloc.free(nativeName);
    }
  }

  void operator []=(String name, Object? value) {
    final nativeName = name.toNativeUtf8();
    try {
      pushValue(value);
      bindings.setglobal(_state, nativeName.cast());
    } finally {
      malloc.free(nativeName);
    }
  }

  void createTable(int narray, int nrec) =>
      bindings.createtable(_state, narray, nrec);

  void newLib(Map<String, LuaAsyncFunction> funcs) {
    bindings.createtable(_state, 0, funcs.length);

    for (final MapEntry(:key, value: func) in funcs.entries) {
      final nativeKey = key.toNativeUtf8();
      try {
        pushAsyncFunction(func);
        bindings.setfield(_state, -2, nativeKey.cast());
      } finally {
        malloc.free(nativeKey);
      }
    }
  }

  void pushNewStringMapTable(Map<String, dynamic> table) {
    bindings.createtable(_state, 0, table.length);

    for (final MapEntry(:key, :value) in table.entries) {
      final nativeKey = key.toNativeUtf8();
      try {
        pushValue(value);
        bindings.setfield(_state, -2, nativeKey.cast());
      } finally {
        malloc.free(nativeKey);
      }
    }
  }

  void pushNewMapTable(Map table) {
    bindings.createtable(_state, 0, table.length);

    for (final MapEntry(:key, :value) in table.entries) {
      pushValue(key);
      pushValue(value);
      bindings.settable(_state, -3);
    }
  }

  void pushNewListTable(List<dynamic> list) {
    bindings.createtable(_state, list.length, 0);

    for (final (i, value) in list.indexed) {
      pushValue(value);
      bindings.rawseti(_state, -2, i + 1);
    }
  }

  List<Object?> call(String funcName, [List<Object?> args = const []]) {
    final pretop = bindings.gettop(_state);

    final type = _allocTryFree(
      funcName,
      (funcName) => bindings.getglobal(_state, funcName),
    );

    if (LuaType.from(type) != LuaType.function) {
      throw LuaException('$funcName is not a function.');
    }

    return _invokeFunction(pretop, args);
  }

  List<Object?> _callLuaFunction(LuaFunction func, List<Object?> args) {
    final pretop = bindings.gettop(_state);

    final type = bindings.rawgeti(_state, kLuaRegistryIndex, func.ref);
    if (LuaType.from(type) != LuaType.function) {
      // TODO: no cleanup?
      throw LuaException('$func is not a function.');
    }

    return _invokeFunction(pretop, args);
  }

  List<Object?> _invokeFunction(int pretop, List<Object?> args) {
    for (final arg in args) {
      pushValue(arg);
    }

    final status = bindings.pcall(_state, args.length);
    if (status != 0) {
      throw LuaException(_errorMessage(_state));
    }

    return popResults(pretop);
  }

  void _unref(int ref) => bindings.unref(_state, kLuaRegistryIndex, ref);

  void pushFunction(Pointer<NativeFunction<bindings.CFunctionFunction>> fp) =>
      bindings.pushcfunction(_state, fp);

  void setGlobal(String name) {
    final nativeName = name.toNativeUtf8();
    try {
      bindings.setglobal(_state, nativeName.cast());
    } finally {
      malloc.free(nativeName);
    }
  }

  void setField(int idx, String name) {
    final nativeName = name.toNativeUtf8();
    try {
      bindings.setfield(_state, idx, nativeName.cast());
    } finally {
      malloc.free(nativeName);
    }
  }

  void pushValue(Object? value) {
    if (value == null) {
      pushNull();
    } else if (value is bool) {
      pushBool(value);
    } else if (value is int) {
      pushInt(value);
    } else if (value is double) {
      pushDouble(value);
    } else if (value is num) {
      pushDouble(value.toDouble());
    } else if (value is String) {
      pushString(value);
    } else if (value is Map<String, dynamic>) {
      pushNewStringMapTable(value);
    } else if (value is Map) {
      pushNewMapTable(value);
    } else if (value is List<dynamic>) {
      pushNewListTable(value);
    } else {
      throw LuaException('Invalid value type: ${value.runtimeType}');
    }
  }

  void pushNull() {
    bindings.pushnil(_state);
  }

  void pushBool(bool value) {
    bindings.pushbool(_state, value ? 1 : 0);
  }

  void pushInt(int value) {
    bindings.pushint(_state, value);
  }

  void pushDouble(double value) {
    bindings.pushdouble(_state, value);
  }

  void pushString(String value) {
    final nativeValue = value.toNativeUtf8();
    try {
      bindings.pushstring(_state, nativeValue.cast());
    } finally {
      malloc.free(nativeValue);
    }
  }

  List<Object?> popResults(int pretop) {
    final count = bindings.gettop(_state) - pretop;
    final results = <Object?>[];
    for (int i = 0; i < count; ++i) {
      final stackIndex = -(count - i);

      results.add(getValueAt(stackIndex));
    }

    bindings.settop(_state, pretop);

    return results;
  }

  Object? getValueAt(int idx) {
    final type = typeAt(idx);
    return _getValueOfType(idx, type);
  }

  Object? _getValueOfType(int idx, LuaType? type) {
    switch (type) {
      case LuaType.none:
      case LuaType.nil:
        return null;
      case LuaType.boolean:
        return bindings.toboolean(_state, idx) != 0;
      case LuaType.number:
        return bindings.tonumber(_state, idx);
      case LuaType.string:
        final ptr = bindings.tostring(_state, idx);
        return ptr.address != 0 ? ptr.cast<Utf8>().toDartString() : null;
      case LuaType.table:
        return _traverseTable(idx);
      case LuaType.function:
        // copy the value to the top of the stack
        bindings.pushvalue(_state, idx);
        // create a reference in registry
        final ref = bindings.ref(_state, kLuaRegistryIndex);
        return LuaFunction(ref, this);
      case LuaType.lightuserdata:
        return const LuaLightUserData();
      case LuaType.userdata:
        return const LuaUserData();
      case LuaType.thread:
        return const LuaThread();
      case null:
        throw LuaException('Unknown lua type.');
    }
  }

  LuaValue getLuaValue(String name) {
    final nativeName = name.toNativeUtf8();
    try {
      final type = bindings.getglobal(_state, nativeName.cast());
      return getLuaValueOfType(-1, LuaType.from(type));
    } finally {
      malloc.free(nativeName);
    }
  }

  LuaValue getLuaValueAt(int idx) {
    final type = typeAt(idx);
    return getLuaValueOfType(idx, type);
  }

  LuaValue getLuaValueOfType(int idx, LuaType? type) {
    switch (type) {
      case LuaType.none:
        return const LuaNone();
      case LuaType.nil:
        return const LuaNil();
      case LuaType.boolean:
        return LuaBool(bindings.toboolean(_state, idx) != 0);
      case LuaType.number:
        return LuaNumber(bindings.tonumber(_state, idx));
      case LuaType.string:
        final ptr = bindings.tostring(_state, idx);
        return LuaString(
          ptr.address != 0 ? ptr.cast<Utf8>().toDartString() : null,
        );
      case LuaType.table:
        return LuaTable(_traverseTable(idx));
      case LuaType.function:
        // copy the value to the top of the stack
        bindings.pushvalue(_state, idx);
        // create a reference in registry
        final ref = bindings.ref(_state, kLuaRegistryIndex);
        return LuaFunction(ref, this);
      case LuaType.lightuserdata:
        return const LuaLightUserData();
      case LuaType.userdata:
        return const LuaUserData();
      case LuaType.thread:
        return const LuaThread();
      case null:
        return const LuaUnknown();
    }
  }

  double checkNumber(int arg) => bindings.checknumber(_state, arg);

  double optNumber(int arg, double defaultValue) =>
      bindings.optnumber(_state, arg, defaultValue);

  int checkInteger(int arg) => bindings.checkinteger(_state, arg);

  int optInteger(int arg, int defaultValue) =>
      bindings.optinteger(_state, arg, defaultValue);

  String checkString(int arg) {
    final ptr = bindings.checklstring(_state, arg);
    return ptr.cast<Utf8>().toDartString();
  }

  String optString(int arg, String defaultValue) {
    final nativeDef = defaultValue.toNativeUtf8();
    try {
      final ptr = bindings.optlstring(_state, arg, nativeDef.cast());
      return ptr.cast<Utf8>().toDartString();
    } finally {
      malloc.free(nativeDef);
    }
  }

  void checkStack(int extraSlots, String message) {
    final nativeMsg = message.toNativeUtf8();
    try {
      bindings.checkstack(_state, extraSlots, nativeMsg.cast());
    } finally {
      malloc.free(nativeMsg);
    }
  }

  void checkType(int arg, LuaType type) =>
      bindings.checktype(_state, arg, type.value);

  void checkAny(int arg) => bindings.checkany(_state, arg);

  bool isNoneOrNil(int arg) => bindings.isnoneornil(_state, arg) != 0;

  Map<Object?, Object?> _traverseTable(int idx) {
    idx = bindings.absindex(_state, idx);

    final result = {};

    bindings.pushnil(_state);
    while (bindings.next(_state, idx) != 0) {
      result[getValueAt(-2)] = getValueAt(-1);

      // pop value, keep key on stack for flua_next
      bindings.pop(_state, 1);
    }

    return result;
  }

  int get top => bindings.gettop(_state);

  void pushAsyncFunction(LuaAsyncFunction handler) {
    _asyncHandlers.add(handler);
    final id = _asyncHandlers.length - 1;
    bindings.push_async_function(_state, id);
  }

  void registerGlobalAsyncFunction(String name, LuaAsyncFunction handler) {
    pushAsyncFunction(handler);
    setGlobal(name);
  }

  Future<List<Object?>> runAsync(String code) async {
    return _runAsync((co) {
      final status = _allocTryFree(
        code,
        (code) => bindings.loadstring(co._state, code),
      );
      if (status != 0) {
        throw LuaException(_errorMessage(co._state));
      }
      return 0;
    });
  }

  Future<List<Object?>> _callLuaFunctionAsync(
    LuaFunction func,
    List<Object?> args,
  ) async {
    return _runAsync((co) {
      final type = bindings.rawgeti(co._state, kLuaRegistryIndex, func.ref);
      if (LuaType.from(type) != LuaType.function) {
        // TODO: no cleanup?
        throw LuaException('$func is not a function.');
      }

      for (final arg in args) {
        co.pushValue(arg);
      }
      return args.length;
    });
  }

  Future<List<Object?>> _runAsync(
    int Function(LuaState co) pushFunction,
  ) async {
    final co = LuaState.fromState(bindings.newthread(_state));
    final threadRef = bindings.ref(_state, kLuaRegistryIndex);

    try {
      int nargs = pushFunction(co);

      while (true) {
        final status = bindings.resume(co._state, _state, nargs);

        if (status == 1) {
          nargs = await _handleAsyncYield(co);
          continue;
        }

        if (status != 0) {
          throw LuaException(_errorMessage(co._state));
        }

        final results = <Object?>[];
        final resultTop = bindings.gettop(co._state);
        for (int i = 1; i <= resultTop; ++i) {
          results.add(co.getValueAt(i));
        }
        bindings.settop(co._state, 0);
        return results;
      }
    } finally {
      bindings.unref(_state, kLuaRegistryIndex, threadRef);
    }
  }

  Future<int> _handleAsyncYield(LuaState co) async {
    final yieldTop = co.top;

    final id = co.typeAt(1) == LuaType.number
        ? bindings.tointeger(co._state, 1)
        : -1;
    if (id < 0 || id >= _asyncHandlers.length) {
      bindings.settop(co._state, 0);
      throw LuaException(
        'Unexpected yield from Lua coroutine: only calls to registered async '
        'functions may yield to Dart.',
      );
    }

    final args = <Object?>[];
    for (int i = 2; i <= yieldTop; ++i) {
      args.add(co.getValueAt(i));
    }
    bindings.settop(co._state, 0);

    List<Object?> results;
    bool ok;
    try {
      results = await _asyncHandlers[id](args);
      ok = true;
    } catch (e) {
      results = [e.toString()];
      ok = false;
    }

    co.pushBool(ok);
    for (final result in results) {
      co.pushValue(result);
    }
    return 1 + results.length;
  }

  static T _allocTryFree<T>(String string, T Function(Pointer<Char>) work) {
    final nativeString = string.toNativeUtf8();
    try {
      return work(nativeString.cast());
    } finally {
      malloc.free(nativeString);
    }
  }

  static String _errorMessage(bindings.State state) {
    final ptr = bindings.error(state);
    return ptr.address != 0 ? ptr.cast<Utf8>().toDartString() : 'Unknown error';
  }
}

sealed class LuaValue {
  const LuaValue();
}

class LuaNone extends LuaValue {
  const LuaNone();
}

class LuaNil extends LuaValue {
  const LuaNil();
}

class LuaBool extends LuaValue {
  final bool value;

  const LuaBool(this.value);
}

class LuaLightUserData extends LuaValue {
  const LuaLightUserData();
}

class LuaNumber extends LuaValue {
  final double value;

  const LuaNumber(this.value);
}

class LuaString extends LuaValue {
  final String? value;

  const LuaString(this.value);
}

class LuaTable extends LuaValue {
  final Map value;

  const LuaTable(this.value);
}

class LuaFunction extends LuaValue {
  final int ref;
  final LuaState _state;
  bool _valid;

  LuaFunction(this.ref, LuaState state) : _state = state, _valid = true;

  bool get valid => _valid;

  List<Object?> call([List<Object?> args = const []]) {
    if (!_valid) {
      throw LuaException('Function reference is not valid.');
    }
    return _state._callLuaFunction(this, args);
  }

  Future<List<Object?>> callAsync([List<Object?> args = const []]) {
    if (!_valid) {
      throw LuaException('Function reference is not valid.');
    }
    return _state._callLuaFunctionAsync(this, args);
  }

  void unref() {
    if (!_valid) {
      return;
    }
    _state._unref(ref);
    _valid = false;
  }
}

class LuaUserData extends LuaValue {
  const LuaUserData();
}

class LuaThread extends LuaValue {
  const LuaThread();
}

class LuaUnknown extends LuaValue {
  const LuaUnknown();
}
