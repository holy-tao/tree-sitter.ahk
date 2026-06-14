#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import Node
#Import Query
#Import QueryCursor

/**
 * A tree-sitter parse tree.
 *
 * This is a wrapper *class* (not a struct) because, beyond the `TSTree*`, it
 * also holds AHK-side state that has no binary representation: the source
 * buffer, the language and the encoding. A `Node` is a pure struct and can't
 * hold a reference back to this wrapper, so trees register the per-tree state
 * here keyed by the raw `TSTree*`. `Node.Text` looks it up via `Tree.InfoOf`.
 */
export default class Tree {

    /**
     * Per-tree state keyed by the raw `TSTree*` pointer. Holds plain data
     * (`{source, encoding, language}`), NOT the Tree wrapper, so the wrapper can
     * still be collected and `__Delete` can run to free the tree and purge here.
     * @type {Map}
     */
    static _info := Map()

    /**
     * Look up the AHK-side state for a tree by its raw `TSTree*` pointer.
     * @param {Integer} treePtr the raw pointer (a `Node`'s `tree` field)
     * @returns {Object | 0} `{source, encoding, language}`, or 0 if unknown
     */
    static InfoOf(treePtr) => Tree._info.Has(treePtr) ? Tree._info[treePtr] : 0

    /**
     * Get the root node of the syntax tree.
     */
    Root {
        get {
            result := Node()
            DllCall("tree-sitter\ts_tree_root_node", Node.Ptr, result, "ptr", this.ptr, "cdecl")
            return result
        }
    }

    __New(ptr, lang, source?, encoding?) {
        this.ptr := ptr
        this.language := lang
        this._source := source ?? 0
        this._encoding := encoding ?? 0

        Tree._info[ptr] := {
            source: this._source,
            encoding: this._StrGetEncoding,
            language: lang
        }
    }

    /**
     * Map InputEncoding enum value to a StrGet-compatible encoding string.
     * @type {String}
     */
    _StrGetEncoding => (this._encoding == 1) ? "UTF-16"
        : (this._encoding == 2) ? "CP1201"
        : "UTF-8"

    /**
     * Write a {@link https://graphviz.org/doc/info/lang.html DOT graph} describing the syntax
     * tree to the given file. The file's contents, if any, are overwritten. The file will be
     * created if it does not exist.
     *
     * @param {String} filepath the filepath.
     */
    PrintDotGraph(filepath) {
        if(!FileExist(filepath))
            FileAppend("", filepath)

        hFile := DllCall("CreateFileW", "str", filepath, "uint", 0x40000000 | 0x80000000, "uint", 1, "ptr", 0, "uint", 3, "uint", 0, "ptr", 0, "ptr")
        if (hFile = -1)
            throw OSError(A_LastError, , "CreateFileW")

        try {
            ; Get a C runtime file descriptor from the OS handle
            fd := DllCall("ucrtbase\_open_osfhandle", "ptr", hFile, "int", 0, "int")
            DllCall("tree-sitter\ts_tree_print_dot_graph", "ptr", this, "int", fd)
        }
        finally {
            DllCall("ucrtbase\_close", "Int", fd)
        }
    }

    /**
     * A convenience method that queries the tree at it's root using a particular query
     * string and returns a `QueryCursor` that you can use to iterate the matches
     *
     * @param {Query | String} queryOrExpression the query to run
     * @returns {QueryCursor} a cursor that you can use to iterate the query
     */
    Query(queryOrExpression) {
        if(queryOrExpression is String) {
            queryOrExpression := Query(this.language, queryOrExpression)
        }

        cursor := QueryCursor()
        cursor.Exec(queryOrExpression, this.Root)
        return cursor
    }

    __Delete() {
        Tree._info.Delete(this.ptr)
        DllCall("tree-sitter\ts_tree_delete", "ptr", this, "cdecl")
    }
}
