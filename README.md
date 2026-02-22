# tree-sitter.ahk
Tree sitter bindings for AutoHotkey v2

## Reqirements

To get started, you'll need to [aquire the binaries](#aquiring-binaries) for the tree-sitter runtime and at least one langauge of your choice. 

These bindings require 64-bit AutoHotkey and MSVC-built tree-sitter DLLs, but should support either x64 or x86 systems.

## Usage

Start by reading the [tree-sitter documentation](https://tree-sitter.github.io/tree-sitter/using-parsers/1-getting-started.html).

### Instantiating a Parser

To load your language, you'll need to load the dll and call it's `tree_sitter_language` function to obtain the `TSLanguage` pointer, then pass that to `TSLanguage`. You'll also need to load `tree-sitter.dll` somewhere in your script (this library doesn't do that for you, since I don't know how your project is organized) via [`#DllLoad`](https://www.autohotkey.com/docs/v2/lib/_DllLoad.htm). Once you have your language pointer, you can pass it into a `TSParser` to create a parser:

```autohotkey
langPtr := DllCall("tree-sitter-autohotkey\tree_sitter_autohotkey", "cdecl ptr")
ahkLang := TSLanguage(langPtr)

parser := TSParser(ahkLang)
```

Another option is to subclass `TSLanguage` and override it's `__New` method with one that loads your language and passes it to the superclass:

```autohotkey
class AutoHotkeyLang extends TSLanguage {
    __New() {
        ptr := DllCall("tree-sitter-autohotkey\tree_sitter_autohotkey", "cdecl ptr")
        super.__New(ptr)
    }
}

lang := AutoHotkeyLang()
parser := TSParser(lang)
```

### Using the bindings

The parsed code is represented by a [`TSTree`](./TSTree.ahk) object. This object doesn't do much on its own, rather, you pass it into other objects to query it or walk the syntax tree.

#### Walking the tree

You can walk the tree using a [`TSTreeCursor`](./TSTreeCursor.ahk) object. 

[`ASTViewer`](./ASTViewer.ahk) demonstrates a full tree-walk as well as ways to extract the underlying code from the tree's nodes.

### Aquiring Binaries
You need two `.dll` files to work with tree-sitter: the tree-sitter runtime, and the compiled grammar of your choice. The tree-sitter runtime is available pre-built through a couple of package managers, and you could probably extract it from there. But if you don't want to deal with all that, it's pretty easy to compile yourself.

#### Building the Runtime
To build the tree-sitter runtime, you'll need [CMake](https://cmake.org/download/) and a reasonably modern version of the [Microsoft Visual Studio build tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2026). 

> [!IMPORTANT]
> ***You must use a tree-sitter runtime compiled with MSVC***. The script uses the MSVC calling convention and memory allocator, using a script compiled with any other compiler will not work. If you see frequent OSErrors with the error code `0xc0000005`, ensure that your tree-sitter runtime was build with the appropriate compiler.

```powershell
git clone https://github.com/tree-sitter/tree-sitter
cd tree-sitter

# Replace the -G flag with your version of the build tools
cmake -B build -G "Visual Studio 17 2022" -A x64 -DBUILD_SHARED_LIBS=ON -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
cmake --build build --config Release
```

CMake will tell you where the final `.dll` file is built. Copy it into your project.

#### Grammars

Grab a compiled grammar file for the language you intend to parse. You can also build one by installing the tree-sitter CLI, checking out the repository for your language, and running

```powershell
tree-sitter build
```