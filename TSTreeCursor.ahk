#Requires AutoHotkey v2.0.0 64-bit

#Include TSNode.ahk

/**
 * A tree-sitter tree cursor.
 * 
 * A tree cursor allows you to walk a syntax tree more efficiently than is
 * possible using the `TSNode` functions. It is a mutable object that is always
 * on a certain syntax node, and can be moved imperatively to different nodes.
 */
class TSTreeCursor extends Buffer {

    /**
     * Get the tree cursor's current node.
     * @type {TSNode}
     */
    Current {
        get {
            node := TSNode(this.tree)
            DllCall("tree-sitter\ts_tree_cursor_current_node",
                "ptr", node,
                "ptr", this,
                "cdecl")

            return node
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
                "ptr", this,
                "cdecl ptr")

            return strPtr == 0 ? "" : StrGet(strPtr, , "CP0")
        }
    }

    /**
     * Get the field id of the tree cursor's current node.
     *
     * This returns zero if the current node doesn't have a field.
     */
    CurrentFieldId => DllCall("tree-sitter\ts_tree_cursor_current_field_id", "ptr", this, "cdecl ushort")

    /**
     * Get the index of the cursor's current node out of all of the
     * descendants of the original node that the cursor was constructed with.
     */
    CurrentDescendantIndex => DllCall("tree-sitter\ts_tree_cursor_current_descendant_index", "ptr", this, "cdecl uint")

    /**
     * Get the depth of the cursor's current node relative to the original
     * node that the cursor was constructed with.
     */
    Depth => DllCall("tree-sitter\ts_tree_cursor_current_depth", "ptr", this, "cdecl uint")

    /**
     * Create a new tree cursor starting from the given node.
     * 
     * @param {TSNode} node The node to create the cursor at. Note that the given node 
     *          is considered  the root of the cursor, and the cursor cannot walk  
     *          outside this node.
     */
    __New(node) {
        if(!(node is TSNode))
            throw TypeError("Expected a TSNode but got a(n) " Type(node), -1, node)

        super.__New(32, 0)
        DllCall("tree-sitter\ts_tree_cursor_new", "ptr", this, "ptr", node, "cdecl")
        this.tree := node.tree
    }

    /**
     * Re-initializes the tree cursor with the given node as its root.
     * 
     * @param {TSNode} node the cursor's new root node.  
     */
    Reset(node) {
        if(!(node is TSNode))
            throw TypeError("Expected a TSNode but got a(n) " Type(node), -1, node)

        DllCall("tree-sitter\ts_tree_cursor_reset",
            "ptr", this,
            "ptr", node,
            "cdecl")
    }

    /**
     * Move the cursor to the parent of its current node.
     *
     * This returns `true` if the cursor successfully moved, and returns `false`
     * if there was no parent node (the cursor was already on the root node).
     * @returns {Boolean}
     */
    GotoParent() => DllCall("tree-sitter\ts_tree_cursor_goto_parent", "ptr", this, "cdecl uchar")

    /**
     * Move the cursor to the next sibling of its current node.
     *
     * This returns `true` if the cursor successfully moved, and returns `false`
     * if there was no next sibling node.
     * @returns {Boolean}
     */
    GotoNextSibling() => DllCall("tree-sitter\ts_tree_cursor_goto_next_sibling", "ptr", this, "cdecl uchar")

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
    GotoPreviousSibling() => DllCall("tree-sitter\ts_tree_cursor_goto_previous_sibling", "ptr", this, "cdecl uchar")

    /**
     * Move the cursor to the first child of its current node.
     * @returns {Boolean}
     */
    GotoFirstChild() => DllCall("tree-sitter\ts_tree_cursor_goto_first_child", "ptr", this, "cdecl uchar")
    
    /**
     * Move the cursor to the last child of its current node.
     * 
     * Note that this function may be slower than `GotoFirstChild`
     * because it needs to iterate through all the children to compute the child's
     * position.
     * @returns {Boolean}
     */
    GotoLastChild() => DllCall("tree-sitter\ts_tree_cursor_goto_last_child", "ptr", this, "cdecl uchar")

    /**
     * Move the cursor to the node that is the nth descendant of
     * the original node that the cursor was constructed with, where
     * zero represents the original node itself.
     * 
     * @param {Integer} n the index of the descendant to move to
     */
    GotoDescendant(n) {
        TSNode._AssertInt(n)

        DllCall("tree-sitter\ts_tree_cursor_goto_descendant", "ptr", this, "uint", n, "cdecl")
    }

    /**
     * Move the cursor to the original node that it started on
     */
    GotoRoot() => DllCall("tree-sitter\ts_tree_cursor_goto_descendant", "ptr", this, "uint", 0, "cdecl")

    /**
     * Move the cursor to the first child of its current node that contains or starts after
     * the given byte offset.
     *
     * @param {Integer} byte the desired byte offset
     * @returns {Integer} the index of the child node if one was found, and returns -1
     * if no such child was found.
     */
    GotoFirstChildForByte(byte) {
        TSNode._AssertInt(byte)

        DllCall("tree-sitter\ts_tree_cursor_goto_first_child_for_byte",
            "ptr", this,
            "uint", byte,
            "cdecl int64")
    }

    /**
     * Move the cursor to the first child of its current node that contains or starts after
     * the given point.
     *
     * @param {TSPoint} point the desired point
     * @returns {Integer} the index of the child node if one was found, and returns -1
     * if no such child was found.
     */
    GotoFirstChildForPoint(point) {
        TSPoint._AssertIs(point)

        DllCall("tree-sitter\ts_tree_cursor_goto_first_child_for_point",
            "ptr", this,
            "ptr", point,
            "cdecl int64")
    }

    __Delete() {
        DllCall("tree-sitter\ts_tree_cursor_delete", "ptr", this, "cdecl")
    }
}