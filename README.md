# flua

Embed Lua 5.4 in Flutter applications via Dart FFI. Execute Lua code, exchange data, and call Lua functions from Dart.

## Features

- Execute Lua code strings and files
- Get/set global variables with native Dart types
- Call Lua functions with arguments and receive results
- Call async Dart functions from Lua

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
  
  lua.close();
}
```

### Async Dart Functions

Register asynchronous Dart functions and call them from Lua as if they were ordinary functions. Under the hood the script runs inside a Lua coroutine: when it calls an async function the coroutine yields, the Dart `Future` is awaited, and the coroutine is resumed with the result. The Lua code reads as plain sequential logic with no explicit callbacks.

```dart
final lua = LuaState();

// Expose an async Dart function to Lua as the global `fetch`.
lua.registerAsyncFunction('fetch', (args) async {
  final url = args.first as String;
  final response = await http.get(Uri.parse(url));
  return [response.body]; // return values handed back to Lua
});

// Run a script that calls it. `fetch(...)` suspends until the Future completes.
final results = await lua.runAsync('''
  local page = fetch("https://example.com")
  return page
''');

print(results);

lua.close();
```

### Type Support

The following Dart types can be passed to and from Lua:

| Dart Type | Lua Type |
| --------- | -------- |
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

## Lua Version

This package embeds [Lua 5.4.8](https://www.lua.org/).
