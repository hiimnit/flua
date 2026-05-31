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

class LuaState implements Finalizable {
  final bindings.State _state;
  bool _closed = false;

  static final _finalizer = NativeFinalizer(Native.addressOf(bindings.close));

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
      final result = bindings.dostring(_state, nativeCode.cast());
      if (result != 0) {
        final errorPtr = bindings.error(_state);
        final error = errorPtr.address != 0
            ? errorPtr.cast<Utf8>().toDartString()
            : 'Unknown error';
        throw LuaException(error);
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
    final nativeName = funcName.toNativeUtf8();
    try {
      final pretop = bindings.gettop(_state);

      final type = bindings.getglobal(_state, nativeName.cast());
      if (LuaType.from(type) != LuaType.function) {
        throw LuaException('$funcName is not a function.');
      }

      return _invokeFunction(pretop, args);
    } finally {
      malloc.free(nativeName);
    }
  }

  List<Object?> _callLuaFunction(LuaFunction func, List<Object?> args) {
    final pretop = bindings.gettop(_state);

    final type = bindings.rawgeti(_state, kLuaRegistryIndex, func.ref);
    if (LuaType.from(type) != LuaType.function) {
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
      final errorPtr = bindings.error(_state);
      final error = errorPtr.address != 0
          ? errorPtr.cast<Utf8>().toDartString()
          : 'Unknown error';
      throw LuaException(error);
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

  // TODO different impl with a wrapper without throw?
  Object? _getValueOfType(int idx, LuaType? type) {
    switch (type) {
      case LuaType.none: // TODO: different handling for none?
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
      default:
        // TODO: LuaUnknown?
        throw LuaException('Unknown lua type.');
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
}

class LuaFunction {
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

  void unref() {
    _state._unref(ref);
    _valid = false;
  }
}

class LuaLightUserData {
  const LuaLightUserData();
}

class LuaUserData {
  const LuaUserData();
}

class LuaThread {
  const LuaThread();
}
