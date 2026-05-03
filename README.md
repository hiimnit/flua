# flua

Embed Lua 5.4 in Flutter applications via Dart FFI. Execute Lua code, exchange data, and call Lua functions from Dart with a clean, high-level API.

## Features

- Execute Lua code strings and files
- Get/set global variables with native Dart types
- Call Lua functions with arguments and receive results
- Automatic memory management with finalizers
- Error handling with `LuaException`
- No manual Lua stack manipulation required

## Getting Started

Add `flua` to your `pubspec.yaml`:

```yaml
dependencies:
  flua:
    path: ../flua
```

## Usage

### Basic Usage

```dart
import 'package:flua/flua.dart';

void main() {
  final lua = LuaState();
  
  // Execute Lua code
  lua.doString('print("Hello from Lua!")');
  
  // Set global variables
  lua['x'] = 10;
  lua['name'] = 'Flua';
  
  // Get global variables
  print(lua['x']);       // 10
  print(lua['name']);    // Flua
  
  // Define and call Lua functions
  lua.doString('''
    function add(a, b)
      return a + b
    end
  ''');
  
  final result = lua.call('add', [5, 7]);
  print(result);  // [12.0]
  
  // Clean up
  lua.close();
}
```

### Error Handling

```dart
try {
  lua.doString('invalid syntax!!!');
} on LuaException catch (e) {
  print('Lua error: ${e.message}');
}
```

### Type Support

The following Dart types can be passed to and from Lua:

| Dart Type | Lua Type |
|-----------|----------|
| `null` | `nil` |
| `bool` | `boolean` |
| `int` / `double` | `number` |
| `String` | `string` |

## Project Structure

- `src/flua.h` / `src/flua.c` - C wrapper providing a high-level API over Lua
- `src/lua/` - Lua 5.4 source (git submodule)
- `lib/flua.dart` - Dart API wrapping the FFI bindings
- `lib/flua_bindings_generated.dart` - Auto-generated FFI bindings
- `hook/build.dart` - Native build configuration

## Building

The native code is built automatically as part of the Flutter build process. The `hook/build.dart` file compiles both the Lua source and the C wrapper into a single library.

To regenerate FFI bindings after modifying `src/flua.h`:

```bash
dart run ffigen --config ffigen.yaml
```

## Platform Support

| Platform | Status |
|----------|--------|
| Android  | Supported |
| iOS      | Supported |
| macOS    | Supported |
| Linux    | Supported |
| Windows  | Supported |

## Lua Version

This package embeds [Lua 5.4.8](https://www.lua.org/).
