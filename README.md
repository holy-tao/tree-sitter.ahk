# tree-sitter.ahk
Tree sitter bindings for 64-bit AutoHotkey v2

## Reqirements

To get started, you'll need to [aquire the binaries](#aquiring-binaries) for the tree-sitter runtime and at least one langauge of your choice. 

These bindings require 64-bit AutoHotkey and MSVC-built tree-sitter DLLs, but should support either x64 or x86 systems.

> [!WARNING]
> The bindings have only been tested on x64

## Usage

Start by reading the [tree-sitter documentation](https://tree-sitter.github.io/tree-sitter/using-parsers/1-getting-started.html). The bindings don't provide many abstractions on top of tree-sitter's APIs, apart from their object-oriented structure.

### Instantiating a Parser

To parse a file, you'll need to load a language and instantiate a parser for it.

To load your language, you'll need to load the dll and call it's `tree_sitter_<language>` function to obtain the `TSLanguage` pointer, then pass that to a [`TSLanguage`](./TSLanguage.ahk) object+. You'll also need to load `tree-sitter.dll` somewhere in your script (this library doesn't do that for you, since I don't know how your project is organized) via [`#DllLoad`](https://www.autohotkey.com/docs/v2/lib/_DllLoad.htm). Once you have your language pointer, you can pass it into a [`TSParser`](./TSParser.ahk) to create a parser:

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

Once you've instantiated a parser, you parse some source code by calling `Parse` on a byte buffer:

```autohotkey
source := FileRead("C:\Programming\tree-sitter.ahk\TSLanguage.ahk", "RAW")
tree := parser.Parse(source, TSInputEncoding.UTF8)
```

The parsed code is represented by a [`TSTree`](./TSTree.ahk) object. This object doesn't do much on its own, rather, you will generally pass it into other objects to query it or walk the syntax tree. The object has a `Root` property pointing to its root node which serves as the primary entry point for most other operations.

It's generally best to keep a reference to the byte buffer around, as you can use it later to read text from nodes using [`StrGet`](https://www.autohotkey.com/docs/v2/lib/StrGet.htm).

The `Parse` method accepts any [buffer-like](https://www.autohotkey.com/docs/v2/lib/Buffer.htm#like) object. Typically this will simply be a buffer, obtained by reading a file with the [`raw`](https://www.autohotkey.com/docs/v2/lib/FileRead.htm#Binary) option. However, you may wish to [memory-map](https://learn.microsoft.com/en-us/windows/win32/memory/file-mapping) extremely large files or parse a string by using its [pointer](https://www.autohotkey.com/docs/v2/lib/StrPtr.htm) and size (in bytes!).

#### Querying the tree

Tree-sitter supports querying the parse tree using a [query language](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/index.html). To do this, you'll create a [`TSQuery`](./TSQuery.ahk`) object representing the query itself, and then execute it with a [`TSQueryCursor`](./TSQueryCursor.ahk). `TSTree` also has a convenience method for running a single query, which returns a cursor. Once you have a cursor, you can use it to iterate over matches:

```autohotkey
stdout := FileOpen("*", "w")

; Find every string literal in the source code represented by `tree`
queryCursor := tree.Query("(string_literal) @str")

; Loop over the cursor's matches
while(match := queryCursor.NextMatch()) {
    stdout.WriteLine("Match " A_Index " (" match.captures.length " capture(s)): ")

    for(capture in match.captures) {
        ; Since we've already read in our file to a byte buffer, we can use `StrGet` to extract text
        node := capture.node
        text := StrGet(source.Ptr + node.StartByte, node.EndByte - node.StartByte, "UTF-8")
        stdout.WriteLine("`t" A_Index ". " text)
    }
}
```

Read more about the querying APIs in tree-sitter's [documentation](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/4-api.html).

> [!NOTE]
> The AutoHotkey bindings do not yet support the use of [predicates or directives](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/3-predicates-and-directives.html) in queries, but should in the future.

#### Walking the tree

You perform a more conventional tree walk using a [`TSTreeCursor`](./TSTreeCursor.ahk) object. Tree cursors are created for a particular tree at a particular node. That node is considered the cursor's "root", and it cannot move above it:

```autohotkey
cursor := TSTreeCursor(tree.Root)
```

[`ASTViewer`](./ASTViewer.ahk) demonstrates the use of a tree cursor to perform a full tree-walk as well as ways to extract the underlying code from the tree's nodes.

### Aquiring Binaries
You need two `.dll` files to work with tree-sitter: the tree-sitter runtime, and the compiled grammar of your choice. The tree-sitter runtime is available pre-built through a couple of package managers, and you could probably extract it from there. But if you don't want to deal with all that, it's pretty easy to compile yourself.

#### Building the Runtime
To build the tree-sitter runtime, you'll need [CMake](https://cmake.org/download/) and a reasonably modern version of the [Microsoft Visual Studio build tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2026). 

> [!IMPORTANT]
> ***You must use a tree-sitter runtime compiled with MSVC***. The script uses the MSVC calling convention and memory allocator, using a script compiled with any other compiler will not work. If you see frequent OSErrors with the error code `0xc0000005` when performing trivial tasks like instantiating objects, ensure that your tree-sitter runtime was built with the appropriate compiler.

```shell
git clone https://github.com/tree-sitter/tree-sitter
cd tree-sitter

# Replace the -G flag with your version of the build tools
cmake -B build -G "Visual Studio 17 2022" -A x64 -DBUILD_SHARED_LIBS=ON -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
cmake --build build --config Release
```

CMake will tell you where the final `.dll` file is built. Copy it into your project.

#### Grammars

Grab a compiled grammar file for the language you intend to parse. You can also build one by installing the [tree-sitter cli](https://github.com/tree-sitter/tree-sitter/tree/master/crates/cli), checking out the repository for your language, and running

```shell
tree-sitter build
```

The tree-sitter cli requires NodeJS and a C and C++ compiler, which must be MSVC for the reasons described above.