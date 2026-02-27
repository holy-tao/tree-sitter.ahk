#Requires AutoHotkey v2.0 64-bit

#Include TSNode.ahk
#Include TSQuery.ahk
#Include TSQueryCursor.ahk

/**
 * A tree-sitter parse tree
 */
class TSTree {

    /**
     * Get the root node of the syntax tree.
     */
    Root {
        get {
            node := TSNode(this)
            DllCall("tree-sitter\ts_tree_root_node", "ptr", node, "ptr", this.ptr, "cdecl")
            return node
        }
    }

    __New(ptr, lang, source?, encoding?) {
        this.ptr := ptr
        this.language := lang
        if IsSet(source)
            this._source := source
        this._encoding := encoding ?? 0
    }

    /**
     * Map TSInputEncoding enum value to a StrGet-compatible encoding string.
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
     * string and returns a `TSQueryCursor` that you can use to iterate the matches
     * 
     * @param {TSQuery | String} queryOrExpression the query to run
     * @returns {TSQueryCursor} a cursor that you can use to iterate the query
     */
    Query(queryOrExpression) {
        if(queryOrExpression is String) {
            queryOrExpression := TSQuery(this.language, queryOrExpression)
        }

        cursor := TSQueryCursor()
        cursor.Exec(queryOrExpression, this.Root)
        return cursor
    }

    __Delete() {
        DllCall("tree-sitter\ts_tree_delete", "ptr", this, "cdecl")
    }
}