#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import Tree

/**
 * A tree-sitter tree node.
 *
 * Node is a 32-byte value type in the C API
 * (`{ uint32_t context[4]; const void *id; const TSTree *tree; }`), so it is a
 * pure struct. Functions that receive a Node by value take it via `Node.Ptr`
 * (its data address); functions that return a Node by value are given a fresh
 * `Node()` as the hidden return buffer (also `Node.Ptr`).
 *
 * A struct can't hold a reference to the AHK `Tree` wrapper, so `Text` resolves
 * the source buffer from `Tree.InfoOf(this.tree)`, keyed on the raw `TSTree*`
 * stored in the `tree` field (which tree-sitter fills in for every node).
 */
export default struct Node {

    context: UInt32[4]      ; uint32_t context[4]
    id: IntPtr              ; const void *id
    tree: IntPtr            ; const TSTree *tree

    /**
     * Get the node's type as a null-terminated string.
     * @type {String}
     */
    Type => DllCall("tree-sitter\ts_node_type", Node.Ptr, this, "cdecl astr")

    /**
     * Get the node's type as a numerical id.
     * @type {Integer}
     */
    Symbol => DllCall("tree-sitter\ts_node_symbol", Node.Ptr, this, "cdecl ushort")

    /**
     * Get the node's type as it appears in the grammar ignoring aliases as a
     * null-terminated string.
     * @type {String}
     */
    GrammarType => DllCall("tree-sitter\ts_node_grammar_type", Node.Ptr, this, "cdecl astr")

    /**
     * Get the node's type as a numerical id as it appears in the grammar ignoring
     * aliases. This should be used in `Language.GetNextState` instead of `Symbol`
     * @type {Integer}
     */
    GrammarSymbol => DllCall("tree-sitter\ts_node_grammar_symbol", Node.Ptr, this, "cdecl ushort")

    /**
     * Get the node's start byte.
     * @type {Integer}
     */
    StartByte => DllCall("tree-sitter\ts_node_start_byte", Node.Ptr, this, "cdecl uint")

    /**
     * Get the node's end byte.
     * @type {Integer}
     */
    EndByte => DllCall("tree-sitter\ts_node_end_byte", Node.Ptr, this, "cdecl uint")

    /**
     * Get the node's start position in terms of rows and columns.
     * @type {Point}
     */
    StartPoint {
        get => DllCall("tree-sitter\ts_node_start_point", Node.Ptr, this, Point)
    }

    /**
     * Get the node's end position in terms of rows and columns.
     * @type {Point}
     */
    EndPoint {
        get => DllCall("tree-sitter\ts_node_end_point", Node.Ptr, this, Point)
    }

    /**
     * Get an S-expression representing the node as a string.
     * @type {String}
     */
    NodeString {
        get {
            ; This string is malloc'd by tree-sitter and we must free it
            strPtr := DllCall("tree-sitter\ts_node_string", Node.Ptr, this, "cdecl ptr")
            str := StrGet(strPtr, , "CP0")
            DllCall("ucrtbase\free", "ptr", strPtr)

            return str
        }
    }

    /**
     * Get the node's text from the source buffer stored on the tree.
     *
     * Requires that the tree was created via `Parser.Parse()`, which
     * automatically stores the source buffer.
     * @type {String}
     */
    Text {
        get {
            info := Tree.InfoOf(this.tree)
            if !info
                throw Error("No tree info for this node - keep the owning Tree alive while using its nodes (it may have been freed)", -1)
            if !info.source
                throw Error("Source buffer not available on tree - parse with a source buffer to use Node.Text", -1)
            return StrGet(info.source.Ptr + this.StartByte,
                this.EndByte - this.StartByte, info.encoding)
        }
    }

    /**
     * Check if the node is null. Functions like `GetChild` and
     * `NextSibling` will return a null node to indicate that no such node
     * was found.
     * @type {Boolean}
     */
    IsNull => DllCall("tree-sitter\ts_node_is_null", Node.Ptr, this, "cdecl uchar")

    /**
     * Check if the node is *named*. Named nodes correspond to named rules in the
     * grammar, whereas *anonymous* nodes correspond to string literals in the
     * grammar.
     * @type {Boolean}
     */
    IsNamed => DllCall("tree-sitter\ts_node_is_named", Node.Ptr, this, "cdecl uchar")

    /**
     * Check if the node is *missing*. Missing nodes are inserted by the parser in
     * order to recover from certain kinds of syntax errors.
     * @type {Boolean}
     */
    IsMissing => DllCall("tree-sitter\ts_node_is_missing", Node.Ptr, this, "cdecl uchar")

    /**
     * Check if the node is *extra*. Extra nodes represent things like comments,
     * which are not required the grammar, but can appear anywhere.
     * @type {Boolean}
     */
    IsExtra => DllCall("tree-sitter\ts_node_is_extra", Node.Ptr, this, "cdecl uchar")

    /**
     * Check if the syntax node has been edited.
     * @type {Boolean}
     */
    HasChanges => DllCall("tree-sitter\ts_node_has_changes", Node.Ptr, this, "cdecl uchar")

    /**
     * Check if the node is a syntax error or contains any syntax errors.
     * @type {Boolean}
     */
    HasError => DllCall("tree-sitter\ts_node_has_error", Node.Ptr, this, "cdecl uchar")

    /**
     * Check if the node is a syntax error.
     * @type {Boolean}
    */
    IsError => DllCall("tree-sitter\ts_node_is_error", Node.Ptr, this, "cdecl uchar")

    /**
     * Get this node's parse state.
     * @type {Integer}
    */
    ParseState => DllCall("tree-sitter\ts_node_parse_state", Node.Ptr, this, "cdecl ushort")

    /**
     * Get the parse state after this node.
     * @type {Integer}
    */
    NextParseState => DllCall("tree-sitter\ts_node_next_parse_state", Node.Ptr, this, "cdecl ushort")

    /**
     * Get the node's immediate parent.
     *
     * Prefer `GetChildWithDescendant` for iterating over the node's ancestors.
     * @type {Node}
     */
    Parent {
        get {
            result := Node()
            DllCall("tree-sitter\ts_node_parent", Node.Ptr, result, Node.Ptr, this, "cdecl")
            return result
        }
    }

    /**
     * Get the node's next sibling
     * @type {Node}
     */
    NextSibling {
        get {
            result := Node()
            DllCall("tree-sitter\ts_node_next_sibling", Node.Ptr, result, Node.Ptr, this, "cdecl")
            return result
        }
    }

    /**
     * Get the node's previous sibling
     * @type {Node}
     */
    PreviousSibling {
        get {
            result := Node()
            DllCall("tree-sitter\ts_node_prev_sibling", Node.Ptr, result, Node.Ptr, this, "cdecl")
            return result
        }
    }

    /**
     * Get the node's next *named* sibling
     * @type {Node}
     */
    NextNamedSibling {
        get {
            result := Node()
            DllCall("tree-sitter\ts_node_next_named_sibling", Node.Ptr, result, Node.Ptr, this, "cdecl")
            return result
        }
    }

    /**
     * Get the node's previous *named* sibling
     * @type {Node}
     */
    PreviousNamedSibling {
        get {
            result := Node()
            DllCall("tree-sitter\ts_node_prev_named_sibling", Node.Ptr, result, Node.Ptr, this, "cdecl")
            return result
        }
    }

    /**
     * Get the node's number of children.
     * @type {Integer}
     */
    ChildCount => DllCall("tree-sitter\ts_node_child_count", Node.Ptr, this, UInt32)

    /**
     * Get the node's number of descendants, including one for the node itself.
     * @type {Integer}
     */
    DescendantCount => DllCall("tree-sitter\ts_node_descendant_count", Node.Ptr, this, UInt32)

    /**
     * Get the node's number of *named* children.
     *
     * See also `IsNamed`
     */
    NamedChildCount => DllCall("tree-sitter\ts_node_named_child_count", Node.Ptr, this, UInt32)

    /**
     * Get the node's child at the given index, where zero represents the first
     * child.
     *
     * @param {Integer} index the index of the child to retrieve
     * @returns {Node} the node at `index`
     */
    GetChild(index) {
        this._AssertValidChildIndex(index)

        result := Node()
        DllCall("tree-sitter\ts_node_child",
            Node.Ptr, result,
            Node.Ptr, this,
            UInt32, index,
            "cdecl")
        return result
    }

    /**
     * Get the node's *named* child at the given index.
     *
     * See also [`ts_node_is_named`].
     *
     * @param {Integer} index the index of the child to retrieve
     * @returns {Node} the node at `index`
     */
    GetNamedChild(index) {
        this._AssertValidNamedChildIndex(index)

        result := Node()
        DllCall("tree-sitter\ts_node_named_child",
            Node.Ptr, result,
            Node.Ptr, this,
            UInt32, index,
            "cdecl")
        return result
    }

    /**
     * Get the node that contains `descendant`.
     *
     * @param {Node} descendant the descendant
     * @returns {Node} the node containing `descendant`. Note that this can return `descendant` itself.
     */
    GetChildWithDescendant(descendant) {
        if(!(descendant is Node))
            throw TypeError("Expected a Node but got a(n) " Type(descendant), -1, descendant)

        result := Node()
        DllCall("tree-sitter\ts_node_child_with_descendant",
            Node.Ptr, result,
            Node.Ptr, this,
            Node.Ptr, descendant,
            "cdecl")
        return result
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
            Node.Ptr, this,
            "uint", childIndex,
            "cdecl ptr"
        )

        return strPtr == 0 ? "" : StrGet(strPtr, , "CP0")
    }

    /**
     * Get the node's child with the given field name.
     *
     * @param {String} name the field name to query
     * @returns {Node} the node
     */
    GetChildByFieldName(name) {
        if(!(name is String))
            throw TypeError("Expected a String but got a(n) " Type(name), -1, name)

        result := Node()
        DllCall("tree-sitter\ts_node_child_by_field_name",
            Node.Ptr, result,
            Node.Ptr, this,
            "astr", name,
            "uint", StrLen(name),
            "cdecl"
        )
        return result
    }

    /**
     * Get all children of the node with the given field name.
     *
     * @param {String} name the field name to query
     * @returns {Array<Node>} the found nodes, if any
     */
    GetChildrenByFieldName(name) {
        found := []

        ; NOTE - use child count since fields can refer to unnamed children
        loop (this.ChildCount) {
            if (this.GetFieldNameForChild(A_Index - 1))
                found.Push(this.GetChild(A_Index - 1))
        }

        return found
    }

    /**
     * Get the node's child with the given numerical field id.
     *
     * You can convert a field name to an id using `Language.GetFieldId`
     * @param {Integer} fieldId the numerical field id
     * @returns {Node} the node
     */
    GetChildByFieldId(fieldId) {
        Node._AssertInt(fieldId)

        result := Node()
        DllCall("tree-sitter\ts_node_child_by_field_id",
            Node.Ptr, result,
            Node.Ptr, this,
            "ushort", fieldId,
            "cdecl"
        )
        return result
    }

    /**
     * Get the node's first child that contains or starts after the given byte offset.
     *
     * @param {Integer} byte the byte offset
     * @returns {Node} the child node
     */
    GetFirstChildForByte(byte) {
        Node._AssertInt(byte)

        result := Node()
        DllCall("tree-sitter\ts_node_first_child_for_byte",
            Node.Ptr, result,
            Node.Ptr, this,
            "uint", byte,
            "cdecl"
        )
        return result
    }

    /**
     * Get the smallest node within this node that spans the given range of bytes
     *
     * @param {Integer} start the starting offset
     * @param {Integer} end the ending offset
     * @returns {Node} the node
     */
    GetDescendantForByteRange(start, end) {
        Node._AssertInt(start)
        Node._AssertInt(end)

        result := Node()
        DllCall("tree-sitter\ts_node_descendant_for_byte_range",
            Node.Ptr, result,
            Node.Ptr, this,
            "uint", start,
            "uint", end,
            "cdecl"
        )
        return result
    }

    /**
     * Get the smallest node within this node that spans the given range of (row, column) positions.
     *
     * @param {Point} start the starting position
     * @param {Point} end the ending position
     * @returns {Node} the node
     */
    GetDescendantForPointRange(start, end) {
        Point._AssertIs(start)
        Point._AssertIs(end)

        result := Node()
        DllCall("tree-sitter\ts_node_descendant_for_point_range",
            Node.Ptr, result,
            Node.Ptr, this,
            Point, start,
            Point, end,
            "cdecl"
        )
        return result
    }

    /**
     * Get the smallest named node within this node that spans the given range of bytes
     *
     * @param {Integer} start the starting offset
     * @param {Integer} end the ending offset
     * @returns {Node} the node
     */
    GetNamedDescendantForByteRange(start, end) {
        Node._AssertInt(start)
        Node._AssertInt(end)

        result := Node()
        DllCall("tree-sitter\ts_node_named_descendant_for_byte_range",
            Node.Ptr, result,
            Node.Ptr, this,
            "uint", start,
            "uint", end,
            "cdecl"
        )
        return result
    }

    /**
     * Get the smallest named node within this node that spans the given range of (row, column) positions.
     *
     * @param {Point} start the starting position
     * @param {Point} end the ending position
     * @returns {Node} the node
     */
    GetNamedDescendantForPointRange(start, end) {
        Point._AssertIs(start)
        Point._AssertIs(end)

        result := Node()
        DllCall("tree-sitter\ts_node_named_descendant_for_point_range",
            Node.Ptr, result,
            Node.Ptr, this,
            Point, start,
            Point, end,
            "cdecl"
        )
        return result
    }

    /**
     * Get the node's first *named* child that contains or starts after the given byte offset.
     *
     * @param {Integer} byte the byte offset
     * @returns {Node} the child node
     */
    GetFirstNamedChildForByte(byte) {
        if(!IsInteger(byte))
            throw TypeError("Expected an Integer but got a(n) " Type(byte), -1, byte)

        result := Node()
        DllCall("tree-sitter\ts_node_first_named_child_for_byte",
            Node.Ptr, result,
            Node.Ptr, this,
            "uint", byte,
            "cdecl"
        )
        return result
    }

    /**
     * Check if two nodes are identical.
     *
     * @param {Any} other the other object to check
     * @returns {Boolean} true of `other` is a `Node` representing the same node as this one
     */
    Equals(other) {
        if(other is Node) {
            return DllCall("tree-sitter\ts_node_eq", Node.Ptr, this, Node.Ptr, other, "cdecl uchar")
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
export struct Point {

    row:       UInt32
    column:    UInt32

    /**
     * Creates a new point
     *
     * @param {Integer} ptrOrRow If `column` is unset, a pointer to an external `TSPoint` struct from
     *          which to initialize this one's values, otherwise, the row
     * @param {Integer} column The column
     */
    __New(ptrOrRow := 0, column?) {
        if(IsSet(column)) {
            this.row := ptrOrRow
            this.column := column
        }
        else if (ptrOrRow) {
            DllCall("ntdll\RtlCopyMemory", Point.Ptr, this, "ptr", ptrOrRow, "uint", 8)
        }
    }

    /**
     * Get a string representation of the point in the format `[row, column]`
     */
    ToString() => Format("[{1}, {2}]", this.row, this.column)

    static _AssertIs(obj) {
        if(!(obj is Point))
            throw TypeError("Expected a Point but got a(n) " Type(obj), -2, obj)
    }
}
