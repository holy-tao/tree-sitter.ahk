#Requires AutoHotkey v2.0.0 64-bit

#Include TSEnums.ahk
#Include TSTree.ahk

; https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h

/**
 * A tree-sitter parser
 */
class TSParser {

    /**
     * An opaque language pointer
     * @type {Integer} 
     */
    _tslang := unset

    /**
     * Creates a new tree-sitter parser
     * @param tslang 
     */
    __New(tslang) {
        this._tslang := tslang

        this.ptr := DllCall("tree-sitter.dll\ts_parser_new", "cdecl ptr")
        DllCall("tree-sitter.dll\ts_parser_set_language", "ptr", this, "ptr", this._tslang, "cdecl int")
    }

    /**
     * Parses some code stored in a Buffer or Buffer-like object into a tree.
     * 
     *      code := FileRead("path/to/file.ahk", "RAW")
     *      myParser.Parse(code)
     * 
     * For very large files, you may want to {@link https://learn.microsoft.com/en-us/windows/win32/memory/file-mapping map}
     * the file into memory instead of reading it directly.
     * 
     * @param {Buffer} code the code to parse
     * @param {TSInputEncoding} encoding the string encoding, if not default
     * @returns {TSTree} the parse tree
     */
    Parse(code, encoding?) {
        if(!(code is Buffer) && !(code.HasProp("ptr") && code.HasProp("size")))
            throw TypeError("Expected a Buffer or buffer-like object but got a(n) " Type(code), -1, code)

        if(IsSet(encoding)) {
            encoding := Integer(encoding)
            if(encoding < 0 || encoding > 3)
                throw ValueError("Invalid encoding", -1, encoding)

            treePtr := DllCall("tree-sitter\ts_parser_parse_string_encoding", 
                "ptr", this, 
                "ptr", 0,     ; Always pass NULL for old_tree - reparsing not supported (yet? maybe ever)
                "ptr", code.ptr, 
                "uint64", code.size,
                "uint", encoding,
                "cdecl ptr")
        }
        else {
            treePtr := DllCall("tree-sitter\ts_parser_parse_string", 
                "ptr", this, 
                "ptr", 0,
                "ptr", code.ptr, 
                "uint64", code.size, 
                "cdecl ptr")
        }

        return TSTree(treePtr, this._tslang, code, encoding?)
    }

    /**
     * Instruct the parser to start the next parse from the beginning.
     *
     * If the parser previously failed because of the progress callback, then
     * by default, it will resume where it left off on the next call to
     * `Parse` or other parsing functions. If you don't want to resume,
     * and instead intend to use this parser to parse some other document, you must
     * call `Reset` first.
     */
    Reset() {
        DllCall("tree-sitter.dll\ts_parser_reset", "ptr", this, "cdecl")
    }

    __Delete() {
        DllCall("tree-sitter.dll\ts_parser_delete", "ptr", this, "cdecl")
    }
}