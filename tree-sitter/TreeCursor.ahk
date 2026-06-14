#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import Node {*}

/**
 * A tree-sitter tree cursor.
 *
 * Mirrors the C `TSTreeCursor` value struct
 * (`{ const void *tree; const void *id; uint32_t context[3]; }`). It is passed
 * to the `ts_tree_cursor_*` functions by reference via `TreeCursor.Ptr`.
 *
 * A tree cursor allows you to walk a syntax tree more efficiently than is
 * possible using the `Node` functions. It is a mutable object that is always
 * on a certain syntax node, and can be moved imperatively to different nodes.
 */
export default struct TreeCursor {

    tree    : IntPtr        ; const void *tree
    id      : IntPtr        ; const void *id
    context : UInt32[3]     ; uint32_t context[3]

    /**
     * Get the tree cursor's current node.
     * @type {Node}
     */
    Current {
        get {
            result := Node()
            DllCall("tree-sitter\ts_tree_cursor_current_node",
                Node.Ptr, result,
                TreeCursor.Ptr, this,
                "cdecl")

            return result
        }
    }

    /**
     * Get the field name of the tree cursor's current node. This is an empty
     * string if the current node doesn't have a field.
     *
     * @type {String}
     */
    CurrentFieldName {
        get {
            strPtr := DllCall("tree-sitter\ts_tree_cursor_current_field_name",
                TreeCursor.Ptr, this,
                "cdecl ptr")

            return strPtr == 0 ? "" : StrGet(strPtr, , "CP0")
        }
    }

    /**
     * Get the field id of the tree cursor's current node.
     *
     * This returns zero if the current node doesn't have a field.
     */
    CurrentFieldId => DllCall("tree-sitter\ts_tree_cursor_current_field_id", TreeCursor.Ptr, this, "cdecl ushort")

    /**
     * Get the index of the cursor's current node out of all of the
     * descendants of the original node that the cursor was constructed with.
     */
    CurrentDescendantIndex => DllCall("tree-sitter\ts_tree_cursor_current_descendant_index", TreeCursor.Ptr, this, "cdecl uint")

    /**
     * Get the depth of the cursor's current node relative to the original
     * node that the cursor was constructed with.
     */
    Depth => DllCall("tree-sitter\ts_tree_cursor_current_depth", TreeCursor.Ptr, this, "cdecl uint")

    /**
     * Create a new tree cursor starting from the given node.
     *
     * @param {Node} startNode The node to create the cursor at. Note that the given node
     *          is considered  the root of the cursor, and the cursor cannot walk
     *          outside this node.
     */
    __New(startNode) {
        if(!(startNode is Node))
            throw TypeError("Expected a Node but got a(n) " Type(startNode), -1, startNode)

        ; ts_tree_cursor_new returns a TSTreeCursor by value; `this` is the
        ; (already-allocated) return buffer.
        DllCall("tree-sitter\ts_tree_cursor_new", TreeCursor.Ptr, this, Node.Ptr, startNode, "cdecl")
    }

    /**
     * Re-initializes the tree cursor with the given node as its root.
     *
     * @param {Node} startNode the cursor's new root node.
     */
    Reset(startNode) {
        if(!(startNode is Node))
            throw TypeError("Expected a Node but got a(n) " Type(startNode), -1, startNode)

        DllCall("tree-sitter\ts_tree_cursor_reset",
            TreeCursor.Ptr, this,
            Node.Ptr, startNode,
            "cdecl")
    }

    /**
     * Move the cursor to the parent of its current node.
     *
     * This returns `true` if the cursor successfully moved, and returns `false`
     * if there was no parent node (the cursor was already on the root node).
     * @returns {Boolean}
     */
    GotoParent() => DllCall("tree-sitter\ts_tree_cursor_goto_parent", TreeCursor.Ptr, this, "cdecl uchar")

    /**
     * Move the cursor to the next sibling of its current node.
     *
     * This returns `true` if the cursor successfully moved, and returns `false`
     * if there was no next sibling node.
     * @returns {Boolean}
     */
    GotoNextSibling() => DllCall("tree-sitter\ts_tree_cursor_goto_next_sibling", TreeCursor.Ptr, this, "cdecl uchar")

    /**
     * Move the cursor to the previous sibling of its current node.
     *
     * This returns `true` if the cursor successfully moved, and returns `false` if
     * there was no previous sibling node.
     *
     * Note, that this function may be slower than `GotoNextSibling`
     * due to how node positions are stored. In
     * the worst case, this will need to iterate through all the children up to the
     * previous sibling node to recalculate its position.
     * @returns {Boolean}
     */
    GotoPreviousSibling() => DllCall("tree-sitter\ts_tree_cursor_goto_previous_sibling", TreeCursor.Ptr, this, "cdecl uchar")

    /**
     * Move the cursor to the first child of its current node.
     * @returns {Boolean}
     */
    GotoFirstChild() => DllCall("tree-sitter\ts_tree_cursor_goto_first_child", TreeCursor.Ptr, this, "cdecl uchar")

    /**
     * Move the cursor to the last child of its current node.
     *
     * Note that this function may be slower than `GotoFirstChild`
     * because it needs to iterate through all the children to compute the child's
     * position.
     * @returns {Boolean}
     */
    GotoLastChild() => DllCall("tree-sitter\ts_tree_cursor_goto_last_child", TreeCursor.Ptr, this, "cdecl uchar")

    /**
     * Move the cursor to the node that is the nth descendant of
     * the original node that the cursor was constructed with, where
     * zero represents the original node itself.
     *
     * @param {Integer} n the index of the descendant to move to
     */
    GotoDescendant(n) {
        Node._AssertInt(n)

        DllCall("tree-sitter\ts_tree_cursor_goto_descendant", TreeCursor.Ptr, this, "uint", n, "cdecl")
    }

    /**
     * Move the cursor to the original node that it started on
     */
    GotoRoot() => DllCall("tree-sitter\ts_tree_cursor_goto_descendant", TreeCursor.Ptr, this, "uint", 0, "cdecl")

    /**
     * Move the cursor to the first child of its current node that contains or starts after
     * the given byte offset.
     *
     * @param {Integer} byte the desired byte offset
     * @returns {Integer} the index of the child node if one was found, and returns -1
     * if no such child was found.
     */
    GotoFirstChildForByte(byte) {
        Node._AssertInt(byte)

        DllCall("tree-sitter\ts_tree_cursor_goto_first_child_for_byte",
            TreeCursor.Ptr, this,
            "uint", byte,
            "cdecl int64")
    }

    /**
     * Move the cursor to the first child of its current node that contains or starts after
     * the given point.
     *
     * @param {Point} pt the desired point
     * @returns {Integer} the index of the child node if one was found, and returns -1
     * if no such child was found.
     */
    GotoFirstChildForPoint(pt) {
        Point._AssertIs(pt)

        DllCall("tree-sitter\ts_tree_cursor_goto_first_child_for_point",
            TreeCursor.Ptr, this,
            Point, pt,
            "cdecl int64")
    }

    __Delete() {
        DllCall("tree-sitter\ts_tree_cursor_delete", TreeCursor.Ptr, this, "cdecl")
    }
}
