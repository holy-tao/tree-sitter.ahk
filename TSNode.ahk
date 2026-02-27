#Requires AutoHotkey v2.0 64-bit

;TODO edits

/**
 * A tree-sitter tree node.
 *
 * TSNode is a 32-byte value type in the C API ({ uint32_t context[4]; void *id; TSTree *tree; }).
 * This class extends Buffer to store the struct inline, so `this.ptr` always
 * points to the raw struct data for DllCall use, and functions that receive or
 * return TSNode by value (via x64 hidden-return-buffer convention) work correctly.
 */
class TSNode extends Buffer {

    /**
     * Get the node's type as a null-terminated string.
     * @type {String}
     */
    Type => DllCall("tree-sitter\ts_node_type", "ptr", this, "cdecl astr")

    /**
     * Get the node's type as a numerical id.
     * @type {Integer}
     */
    Symbol => DllCall("tree-sitter\ts_node_symbol", "ptr", this, "cdecl ushort")

    /**
     * Get the node's type as it appears in the grammar ignoring aliases as a
     * null-terminated string.
     * @type {String}
     */
    GrammarType => DllCall("tree-sitter\ts_node_grammar_type", "ptr", this, "cdecl astr")

    /**
     * Get the node's type as a numerical id as it appears in the grammar ignoring
     * aliases. This should be used in `TSLanguage.GetNextState` instead of `Symbol`
     * @type {Integer}
     */
    GrammarSymbol => DllCall("tree-sitter\ts_node_grammar_symbol", "ptr", this, "cdecl ushort")

    /**
     * Get the node's start byte.
     * @type {Integer}
     */
    StartByte => DllCall("tree-sitter\ts_node_start_byte", "ptr", this, "cdecl uint")

    /**
     * Get the node's end byte.
     * @type {Integer}
     */
    EndByte => DllCall("tree-sitter\ts_node_end_byte", "ptr", this, "cdecl uint")

    /**
     * Get the node's start position in terms of rows and columns.
     * @type {TSPoint}
     */
    StartPoint {
        get {
            ; TSPoint ({ uint32_t row, column } = 8 bytes) is a trivial POD struct
            ; that fits in a register, so it is returned in RAX on x64, not via a
            ; hidden pointer. Capture as int64 and unpack the two uint32 fields.
            v := DllCall("tree-sitter\ts_node_start_point", "ptr", this, "cdecl int64")
            return TSPoint(v & 0xFFFFFFFF, (v >> 32) & 0xFFFFFFFF)
        }
    }

    /**
     * Get the node's end position in terms of rows and columns.
     * @type {TSPoint}
     */
    EndPoint {
        get {
            v := DllCall("tree-sitter\ts_node_end_point", "ptr", this, "cdecl int64")
            return TSPoint(v & 0xFFFFFFFF, (v >> 32) & 0xFFFFFFFF)
        }
    }

    /**
     * Get an S-expression representing the node as a string.
     * @type {String}
     */
    NodeString {
        get {
            ; This string is malloc'd by tree-sitter and we must free it
            strPtr := DllCall("tree-sitter\ts_node_string", "ptr", this, "cdecl ptr")
            str := StrGet(strPtr, , "CP0")
            DllCall("ucrtbase\free", "ptr", strPtr)
            
            return str
        }
    }

    /**
     * Get the node's text from the source buffer stored on the tree.
     *
     * Requires that the tree was created via `TSParser.Parse()`, which
     * automatically stores the source buffer.
     * @type {String}
     */
    Text {
        get {
            if !this.tree.HasOwnProp("_source")
                throw Error("Source buffer not available on tree", -1)
            return StrGet(this.tree._source.Ptr + this.StartByte,
                this.EndByte - this.StartByte, this.tree._StrGetEncoding)
        }
    }

    /**
     * Check if the node is null. Functions like `GetChild` and
     * `NextSibling` will return a null node to indicate that no such node
     * was found.
     * @type {Boolean}
     */
    IsNull => DllCall("tree-sitter\ts_node_is_null", "ptr", this, "cdecl uchar")

    /**
     * Check if the node is *named*. Named nodes correspond to named rules in the
     * grammar, whereas *anonymous* nodes correspond to string literals in the
     * grammar.
     * @type {Boolean}
     */
    IsNamed => DllCall("tree-sitter\ts_node_is_named", "ptr", this, "cdecl uchar")

    /**
     * Check if the node is *missing*. Missing nodes are inserted by the parser in
     * order to recover from certain kinds of syntax errors.
     * @type {Boolean}
     */
    IsMissing => DllCall("tree-sitter\ts_node_is_missing", "ptr", this, "cdecl uchar")

    /**
     * Check if the node is *extra*. Extra nodes represent things like comments,
     * which are not required the grammar, but can appear anywhere.
     * @type {Boolean}
     */
    IsExtra => DllCall("tree-sitter\ts_node_is_extra", "ptr", this, "cdecl uchar")

    /**
     * Check if the syntax node has been edited.
     * @type {Boolean}
     */
    HasChanges => DllCall("tree-sitter\ts_node_has_changes", "ptr", this, "cdecl uchar")

    /**
     * Check if the node is a syntax error or contains any syntax errors.
     * @type {Boolean}
     */
    HasError => DllCall("tree-sitter\ts_node_has_error", "ptr", this, "cdecl uchar")

    /**
     * Check if the node is a syntax error.
     * @type {Boolean}
    */
    IsError => DllCall("tree-sitter\ts_node_is_error", "ptr", this, "cdecl uchar")

    /**
     * Get this node's parse state.
     * @type {Integer}
    */
    ParseState => DllCall("tree-sitter\ts_node_parse_state", "ptr", this, "cdecl ushort")

    /**
     * Get the parse state after this node.
     * @type {Integer}
    */
    NextParseState => DllCall("tree-sitter\ts_node_next_parse_state", "ptr", this, "cdecl ushort")

    /**
     * Get the node's immediate parent.
     *
     * Prefer `GetChildWithDescendant` for iterating over the node's ancestors.
     * @type {TSNode}
     */
    Parent {
        get {
            node := TSNode(this.tree)
            DllCall("tree-sitter\ts_node_parent", "ptr", node, "ptr", this, "cdecl")
            return node
        }
    }

    /**
     * Get the node's next sibling
     * @type {TSNode}
     */
    NextSibling {
        get {
            node := TSNode(this.tree)
            DllCall("tree-sitter\ts_node_next_sibling", "ptr", node, "ptr", this, "cdecl")
            return node
        }
    }

    /**
     * Get the node's previous sibling
     * @type {TSNode}
     */
    PreviousSibling {
        get {
            node := TSNode(this.tree)
            DllCall("tree-sitter\ts_node_prev_sibling", "ptr", node, "ptr", this, "cdecl")
            return node
        }
    }

    /**
     * Get the node's next *named* sibling
     * @type {TSNode}
     */
    NextNamedSibling {
        get {
            node := TSNode(this.tree)
            DllCall("tree-sitter\ts_node_next_named_sibling", "ptr", node, "ptr", this, "cdecl")
            return node
        }
    }

    /**
     * Get the node's previous *named* sibling
     * @type {TSNode}
     */
    PreviousNamedSibling {
        get {
            node := TSNode(this.tree)
            DllCall("tree-sitter\ts_node_prev_named_sibling", "ptr", node, "ptr", this, "cdecl")
            return node
        }
    }

    /**
     * Get the node's number of children.
     * @type {Integer}
     */
    ChildCount => DllCall("tree-sitter\ts_node_child_count", "ptr", this, "cdecl uint")

    /**
     * Get the node's number of descendants, including one for the node itself.
     * @type {Integer}
     */
    DescendantCount => DllCall("tree-sitter\ts_node_descendant_count", "ptr", this, "cdecl uint")

    /**
     * Get the node's number of *named* children.
     *
     * See also `IsNamed`
     */
    NamedChildCount => DllCall("tree-sitter\ts_node_named_child_count", "ptr", this, "cdecl uint")

    __New(tree) {
        super.__New(32, 0)
        this.tree := tree
    }

    /**
     * Get the node's child at the given index, where zero represents the first
     * child.
     *
     * @param {Integer} index the index of the child to retrieve
     * @returns {TSNode} the node at `index`
     */
    GetChild(index) {
        this._AssertValidChildIndex(index)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_child",
            "ptr", node,
            "ptr", this,
            "uint", index,
            "cdecl")
        return node
    }

    /**
     * Get the node's *named* child at the given index.
     *
     * See also [`ts_node_is_named`].
     *
     * @param {Integer} index the index of the child to retrieve
     * @returns {TSNode} the node at `index`
     */
    GetNamedChild(index) {
        this._AssertValidNamedChildIndex(index)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_named_child",
            "ptr", node,
            "ptr", this,
            "uint", index,
            "cdecl")
        return node
    }

    /**
     * Get the node that contains `descendant`.
     *
     * @param {TSNode} descendant the descendant
     * @returns {TSNode} the node containing `descendant`. Note that this can return `descendant` itself.
     */
    GetChildWithDescendant(descendant) {
        if(!(descendant is TSNode))
            throw TypeError("Expected a TSNode but got a(n) " Type(descendant), -1, descendant)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_child_with_descendant",
            "ptr", node,
            "ptr", this,
            "ptr", descendant,
            "cdecl")
        return node
    }

    /**
     * Get the field name for node's child at the given index, where zero represents
     * the first child. Returns "", if no field is found.
     *
     * @param {Integer} childIndex the index of the child
     * @returns {String} the field name of the child at the index, or "" if no field is found
     */
    GetFieldNameForChild(childIndex) {
        this._AssertValidChildIndex(childIndex)

        ; Might return null, in that case use empty string
        strPtr := DllCall("tree-sitter\ts_node_field_name_for_child",
            "ptr", this,
            "uint", childIndex,
            "cdecl ptr"
        )

        return strPtr == 0 ? "" : StrGet(strPtr, , "CP0")
    }

    /**
     * Get the node's child with the given field name.
     *
     * @param {String} name the field name to query
     * @returns {TSNode} the node
     */
    GetChildByFieldName(name) {
        if(!(name is String))
            throw TypeError("Expected a String but got a(n) " Type(name), -1, name)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_child_by_field_name",
            "ptr", node,
            "ptr", this,
            "astr", name,
            "uint", StrLen(name),
            "cdecl"
        )
        return node
    }

    /**
     * Get the node's child with the given numerical field id.
     *
     * You can convert a field name to an id using `TSLanguage.GetFieldId`
     * @param {Integer} fieldId the numerical field id
     * @returns {TSNode} the node
     */
    GetChildByFieldId(fieldId) {
        TSNode._AssertInt(fieldId)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_child_by_field_id",
            "ptr", node,
            "ptr", this,
            "ushort", fieldId,
            "cdecl"
        )
        return node
    }

    /**
     * Get the node's first child that contains or starts after the given byte offset.
     *
     * @param {Integer} byte the byte offset
     * @returns {TSNode} the child node
     */
    GetFirstChildForByte(byte) {
        TSNode._AssertInt(byte)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_first_child_for_byte",
            "ptr", node,
            "ptr", this,
            "uint", byte,
            "cdecl"
        )
        return node
    }

    /**
     * Get the smallest node within this node that spans the given range of bytes
     *
     * @param {Integer} start the starting offset
     * @param {Integer} end the ending offset
     * @returns {TSNode} the node
     */
    GetDescendantForByteRange(start, end) {
        TSNode._AssertInt(start)
        TSNode._AssertInt(end)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_descendant_for_byte_range",
            "ptr", node,
            "ptr", this,
            "uint", start,
            "uint", end,
            "cdecl"
        )
        return node
    }

    /**
     * Get the smallest node within this node that spans the given range of (row, column) positions.
     *
     * TSPoint is an 8-byte POD struct returned/passed in a GPR register on x64.
     * Pack each TSPoint into a single int64 (row in low 32 bits, column in high 32 bits).
     *
     * @param {TSPoint} start the starting position
     * @param {TSPoint} end the ending position
     * @returns {TSNode} the node
     */
    GetDescendantForPointRange(start, end) {
        TSPoint._AssertIs(start)
        TSPoint._AssertIs(end)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_descendant_for_point_range",
            "ptr", node,
            "ptr", this,
            "int64", start.row | (start.column << 32),
            "int64", end.row | (end.column << 32),
            "cdecl"
        )
        return node
    }

    /**
     * Get the smallest named node within this node that spans the given range of bytes
     *
     * @param {Integer} start the starting offset
     * @param {Integer} end the ending offset
     * @returns {TSNode} the node
     */
    GetNamedDescendantForByteRange(start, end) {
        TSNode._AssertInt(start)
        TSNode._AssertInt(end)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_named_descendant_for_byte_range",
            "ptr", node,
            "ptr", this,
            "uint", start,
            "uint", end,
            "cdecl"
        )
        return node
    }

    /**
     * Get the smallest named node within this node that spans the given range of (row, column) positions.
     *
     * @param {TSPoint} start the starting position
     * @param {TSPoint} end the ending position
     * @returns {TSNode} the node
     */
    GetNamedDescendantForPointRange(start, end) {
        TSPoint._AssertIs(start)
        TSPoint._AssertIs(end)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_named_descendant_for_point_range",
            "ptr", node,
            "ptr", this,
            "int64", start.row | (start.column << 32),
            "int64", end.row | (end.column << 32),
            "cdecl"
        )
        return node
    }

    /**
     * Get the node's first *named* child that contains or starts after the given byte offset.
     *
     * @param {Integer} byte the byte offset
     * @returns {TSNode} the child node
     */
    GetFirstNamedChildForByte(byte) {
        if(!IsInteger(byte))
            throw TypeError("Expected an Integer but got a(n) " Type(byte), -1, byte)

        node := TSNode(this.tree)
        DllCall("tree-sitter\ts_node_first_named_child_for_byte",
            "ptr", node,
            "ptr", this,
            "uint", byte,
            "cdecl"
        )
        return node
    }

    /**
     * Check if two nodes are identical.
     *
     * @param {Any} other the other object to check
     * @returns {Boolean} true of `other` is a `TSNode` representing the same node as this one
     */
    Equals(other) {
        if(other is TSNode) {
            return DllCall("tree-sitter\ts_node_eq", "ptr", this, "ptr", other, "cdecl uchar")
        }
        return false
    }

    _AssertValidChildIndex(index) {
        if(!IsInteger(index))
            throw TypeError("Expected an Integer but got a(n) " Type(index), -2, index)

        if(index < 0 || index >= this.ChildCount)
            throw IndexError("Index out of range (0 - " this.ChildCount ")", -2, index)
    }

    _AssertValidNamedChildIndex(index) {
        if(!IsInteger(index))
            throw TypeError("Expected an Integer but got a(n) " Type(index), -2, index)

        if(index < 0 || index >= this.NamedChildCount)
            throw IndexError("Index out of range (0 - " this.NamedChildCount ")", -2, index)
    }

    static _AssertInt(num) {
        if(!IsInteger(num))
            throw TypeError("Expected an Integer but got a(n) " Type(num), -2, num)
    }
}

/**
 * Represents a point as a row-column pair.
 *
 * E.g [2, 14] means the 14th character of the 3rd (0-indexed) row
 */
class TSPoint extends Buffer{

    /**
     * The point's row
     * @type {Integer}
     */
    row {
        get => NumGet(this, 0, "uint")
        set => NumPut("uint", value, this, 0)
    }

    /**
     * The point's column
     * @type {Integer}
     */
    column {
        get => NumGet(this, 4, "uint")
        set => NumPut("uint", value, this, 4)
    }

    /**
     * Creates a new point
     *
     * @param {Integer} ptrOrRow If `column` is unset, a pointer to an external `TSPoint` struct from
     *          which to initialize this one's values, otherwise, the row
     * @param {Integer} column The column
     */
    __New(ptrOrRow, column?) {
        super.__New(8)

        if(IsSet(column)) {
            TSNode._AssertInt(ptrOrRow)
            TSNode._AssertInt(column)

            NumPut("uint", Integer(ptrOrRow), "uint", Integer(column), this)
        }
        else {
            DllCall("ntdll\RtlCopyMemory", "ptr", this, "ptr", ptrOrRow, "uint", 8)
        }
    }

    /**
     * Get a string representation of the point in the format `[row, column]`
     */
    ToString() => Format("[{1}, {2}]", this.row, this.column)

    static _AssertIs(obj) {
        if(!(obj is TSPoint))
            throw TypeError("Expected a TSPoint but got a(n) " Type(obj), -2, obj)
    }
}
