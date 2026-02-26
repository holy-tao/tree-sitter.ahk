#Requires AutoHotkey v2.0

#Include TSQuery.ahk
#Include TSNode.ahk
#Include TSTree.ahk

/**
 * A cursor for executing a tree-sitter query.
 * 
 * The cursor stores the state that is needed to iteratively search
 * for matches. To use the query cursor, first call `Exec()` to start
 * running a given query on a given syntax node. Then, there are two
 * options for consuming the results of the query:
 * 1. Repeatedly call `NextMatch()` to iterate over all of the
 *    *matches* in the order that they were found. Each match contains the
 *    index of the pattern that matched, and an array of captures. Because
 *    multiple patterns can match the same set of nodes, one match may contain
 *    captures that appear *before* some of the captures from a previous match.
 * 2. Repeatedly call `NextCapture()` to iterate over all of the
 *    individual *captures* in the order that they appear. This is useful if
 *    don't care about which pattern matched, and just want a single ordered
 *    sequence of captures.
 *
 * If you don't care about consuming all of the results, you can stop calling
 * `NextMatch()` or `NextCapture()` at any point.
 * You can then start executing another query on another node by calling
 * `Exec` again.
 */
class TSQueryCursor {

    /**
     * An optional maximum capacity for storing lists of in-progress captures.
     * 
     * If this capacity is exceeded, then the earliest-starting match will silently 
     * be dropped to make room for further matches. This maximum capacity is optional 
     * — by default, query cursors allow any number of pending matches, dynamically 
     * allocating new space for them as needed as the query is executed.
     * 
     * @type {Integer}
     */
    MatchLimit {
        get => DllCall("tree-sitter\ts_query_cursor_match_limit", "ptr", this, "cdecl uint")
        set => DllCall("tree-sitter\ts_query_cursor_set_match_limit", "ptr", this, "uint32", Integer(value), "cdecl")
    }

    /**
     * Indicates whether or not the cursor has exceeded its match limit
     * @type {Boolean}
     */
    DidExceedMatchLimit => DllCall("tree-sitter\ts_query_cursor_did_exceed_match_limit", "ptr", this, "cdecl ushort")

    /**
     * Creates a new tree-sitter cursor
     * @returns {TSQueryCursor}
     */
    __New() {
        this.ptr := DllCall("tree-sitter\ts_query_cursor_new", "cdecl ptr")
    }

    /**
     * Start running the given query on the given node
     * 
     * @param {TSQuery} query the query to execute
     * @param {TSNode} node the node to execute the query on 
     */
    Exec(query, node) {
        if(!(query is TSQuery))
            throw TypeError("Expected a TSQuery but got a(n) " Type(query), -1, query)

        if(!(node is TSNode))
            throw TypeError("Expected a TSNode but got a(n) " Type(node), -1, node)

        this._query := query
        this._tree := node.tree

        ; TODO support exec_with_options?
        DllCall("tree-sitter\ts_query_cursor_exec",
            "ptr", this,
            "ptr", query,
            "ptr", node,
            "cdecl")
    }

    /**
     * Set the range of bytes in which the query will be executed.
     *
     * The query cursor will return matches that intersect with the given point range.
     * This means that a match may be returned even if some of its captures fall
     * outside the specified range, as long as at least part of the match
     * overlaps with the range.
     *
     * For example, if a query pattern matches a node that spans a larger area
     * than the specified range, but part of that node intersects with the range,
     * the entire match will be returned.
     * 
     * @param {Integer} start the starting byte of the range
     * @param {Integer} end the ending byte of the range
     */
    SetByteRange(start, end) {
        TSNode._AssertInt(start)
        TSNode._AssertInt(end)

        if(start > end)
            throw ValueError("Starting byte must be smaller than ending byte", -1, start " > " end)

        DllCall("tree-sitter\ts_query_cursor_set_byte_range",
            "ptr", this,
            "uint", Integer(start),
            "uint", Integer(end),
            "cdecl ushort")
    }

    /**
     * Set the range of (row, column) positions in which the query will be executed.
     *
     * The query cursor will return matches that intersect with the given point range.
     * This means that a match may be returned even if some of its captures fall
     * outside the specified range, as long as at least part of the match
     * overlaps with the range.
     *
     * For example, if a query pattern matches a node that spans a larger area
     * than the specified range, but part of that node intersects with the range,
     * the entire match will be returned.
     * 
     * @param {TSPoint} start the starting point of the range
     * @param {TSPoint} end the ending point of the range
     */
    SetPointRange(start, end) {
        TSPoint._AssertIs(start)
        TSPoint._AssertIs(end)

        result := DllCall("tree-sitter\ts_query_cursor_set_point_range",
            "ptr", this,
            "ptr", start,
            "ptr", end,
            "cdecl ushort")

        if(!result) {
            throw ValueError("Starting point must be before ending point", -1, 
                String(start) " - " String(end))
        }
    }

    /**
     * Set the byte range within which all matches must be fully contained.
     *
     * Set the range of bytes in which matches will be searched for. In contrast to
     * `SetByteRange()`, this will restrict the query cursor to only return
     * matches where _all_ nodes are _fully_ contained within the given range. Both functions
     * can be used together, e.g. to search for any matches that intersect line 5000, as
     * long as they are fully contained within lines 4500-5500
     * 
     * @param {Integer} start the starting byte of the range
     * @param {Integer} end the ending byte of the range
     */
    SetContainingByteRange(start, end) {
        TSNode._AssertInt(start)
        TSNode._AssertInt(end)

        if(start > end)
            throw ValueError("Starting byte must be smaller than ending byte", -1, start " > " end)

        DllCall("tree-sitter\ts_query_cursor_set_containing_byte_range",
            "ptr", this,
            "uint", Integer(start),
            "uint", Integer(end),
            "cdecl ushort")
    }

    /**
     * Set the point range within which all matches must be fully contained.
     *
     * Set the range of bytes in which matches will be searched for. In contrast to
     * `SetPointRange()`, this will restrict the query cursor to only return
     * matches where _all_ nodes are _fully_ contained within the given range. Both functions
     * can be used together, e.g. to search for any matches that intersect line 5000, as
     * long as they are fully contained within lines 4500-5500
     * 
     * @param {TSPoint} start the starting point of the range
     * @param {TSPoint} end the ending point of the range
     */
    SetContainingPointRange(start, end) {
        TSPoint._AssertIs(start)
        TSPoint._AssertIs(end)

        result := DllCall("tree-sitter\ts_query_cursor_set_containing_point_range",
            "ptr", this,
            "ptr", start,
            "ptr", end,
            "cdecl ushort")

        if(!result) {
            throw ValueError("Starting point must be before ending point", -1,
                String(start) " - " String(end))
        }
    }

    /**
     * Advance to the next match of the currently running query.
     *
     * If there is a match, a `Match` object is returned containing the
     * match's pattern index and an array of captures. If there are no more
     * matches, `0` is returned.
     *
     * @returns {TSQueryCursor.Match | 0} the next match, or `0` if exhausted
     */
    NextMatch() {
        matchBuf := Buffer(16, 0)
        result := DllCall("tree-sitter\ts_query_cursor_next_match",
            "ptr", this,
            "ptr", matchBuf,
            "cdecl uchar")

        if (!result)
            return 0

        return this._ReadMatch(matchBuf)
    }

    /**
     * Advance to the next capture of the currently running query.
     *
     * Unlike `NextMatch()`, which returns entire matches in the order they
     * were found, this method returns individual captures in the order that
     * they appear in the document. This is useful when you don't care about
     * which pattern matched, and just want an ordered sequence of captures.
     *
     * Each result is an object with a `match` (the full `Match` that this
     * capture belongs to) and a `captureIndex` (the index within
     * `match.captures` of the specific capture being yielded).
     *
     * When using this method with queries that have predicates, call
     * `RemoveMatch(result.match.id)` to drop matches whose predicates fail.
     *
     * @returns {Object | 0} an object `{match, captureIndex}`, or `0` if exhausted
     */
    NextCapture() {
        matchBuf := Buffer(16, 0)
        result := DllCall("tree-sitter\ts_query_cursor_next_capture",
            "ptr", this,
            "ptr", matchBuf,
            "uint*", &captureIndex := 0,
            "cdecl uchar")

        if (!result)
            return 0

        return {match: this._ReadMatch(matchBuf), captureIndex: captureIndex}
    }

    /**
     * Remove a match from the cursor's internal state, preventing it from
     * being returned in future calls to `NextCapture()`.
     *
     * This is useful when evaluating predicates: if a match's predicates fail,
     * call this method with the match id to inform the cursor.
     *
     * @param {Integer} matchId the id of the match to remove
     */
    RemoveMatch(matchId) {
        TSNode._AssertInt(matchId)

        DllCall("tree-sitter\ts_query_cursor_remove_match",
            "ptr", this,
            "uint", Integer(matchId),
            "cdecl")
    }

    /**
     * Set the maximum start depth for a query cursor.
     *
     * This prevents cursors from exploring children nodes at a depth greater
     * than the given depth. This is useful when you only want to match patterns
     * at a certain depth in the tree.
     *
     * @param {Integer} depth the maximum start depth (use `0xFFFFFFFF` for no limit)
     */
    SetMaxStartDepth(depth) {
        TSNode._AssertInt(depth)

        DllCall("tree-sitter\ts_query_cursor_set_max_start_depth",
            "ptr", this,
            "uint", Integer(depth),
            "cdecl")
    }

    /**
     * Read a TSQueryMatch from a 16-byte buffer and return a Match object.
     *
     * TSQueryMatch layout (x64, 16 bytes):
     *   offset 0:  uint32_t id
     *   offset 4:  uint16_t pattern_index
     *   offset 6:  uint16_t capture_count
     *   offset 8:  const TSQueryCapture *captures
     *
     * TSQueryCapture layout (x64, 40 bytes with padding):
     *   offset 0:  TSNode node (32 bytes)
     *   offset 32: uint32_t index (4 bytes)
     *   +4 bytes padding for 8-byte alignment
     */
    _ReadMatch(matchBuf) {
        id := NumGet(matchBuf, 0, "uint")
        patternIndex := NumGet(matchBuf, 4, "ushort")
        captureCount := NumGet(matchBuf, 6, "ushort")
        capturesPtr := NumGet(matchBuf, 8, "ptr")

        captures := Array()
        captures.Length := captureCount
        loop captureCount {
            captureBase := capturesPtr + 40 * (A_Index - 1)

            node := TSNode(this._tree)
            DllCall("ntdll\RtlCopyMemory", "ptr", node, "ptr", captureBase, "uint", 32)

            captures[A_Index] := TSQueryCursor.Capture(
                node,
                NumGet(captureBase, 32, "uint")
            )
        }

        return TSQueryCursor.Match(id, patternIndex, captures)
    }

    __Delete() => DllCall("tree-sitter\ts_query_cursor_delete", "ptr", this, "cdecl")

    /**
     * Represents a single match returned by a query cursor.
     *
     * A match contains the id of the match, which pattern in the query matched,
     * and an array of captures (node + capture index pairs).
     */
    class Match {
        /**
         * @param {Integer} id the match id
         * @param {Integer} patternIndex the index of the pattern that produced this match
         * @param {Array<TSQueryCursor.Capture>} captures the captured nodes
         */
        __New(id, patternIndex, captures) {
            this.id := id
            this.patternIndex := patternIndex
            this.captures := captures
        }
    }

    /**
     * Represents a single capture within a query match.
     *
     * Each capture has a `node` (the syntax tree node that was captured) and an
     * `index` (the numeric id of the capture in the query). Use
     * `query.GetCaptureNameForId(capture.index)` to get the capture's `@name`.
     */
    class Capture {
        /**
         * @param {TSNode} node the captured node
         * @param {Integer} index the capture index in the query
         */
        __New(node, index) {
            this.node := node
            this.index := index
        }
    }
}