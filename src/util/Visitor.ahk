#Requires AutoHotkey v2.1-alpha.30 64-bit

#Import "../TreeCursor.ahk" as TreeCursor
#Import "../Tree.ahk" as Tree

/**
 * A helper that walks a tree rooted at some node and calls Enter and Exit
 * callbacks.
 */
export default class Visitor {

    /**
     * Map of node types to callbacks to invoke when entering a node
     * @type {Map<String, Array<Func(Visitor, Node) => Any>}
     */
    _enterCallbacks := Map()

    /**
     * Map of node types to callbacks to invoke when exiting a node
     * @type {Map<String, Array<Func(Visitor, Node) => Any>}
     */
    _exitCallbacks := Map()

    /**
     * @param {Node} startNode the node to walk from
     */
    __New(startNode) {
        this._cursor := TreeCursor(startNode)

        ; A Node struct can't reference the Tree wrapper, so recover the
        ; language (needed to validate node types) from the registry.
        info := Tree.InfoOf(startNode.tree)
        this._language := info ? info.language : 0
    }

    /**
     * Register a visitor callback to be called when entering a node
     *
     * @param {String} nodeType the node type to listen for. Use `*` for everything
     * @param {Func(Visitor, Node) => Any} callback the callback
     * @param {Integer} addRemove like with native AHK callbacks, specify 1 to append the callback
     *          to the visitor's list for this node, 0 to remove it, or -1 to prepend it
     */
    OnEnter(nodeType, callback, addRemove := 1) =>
        this._AddCallback(this._enterCallbacks, nodeType, callback, addRemove)

    /**
     * Register a visitor callback to be called when exiting a node
     *
     * @param {String} nodeType the node type to listen for. Use `*` for everything
     * @param {Func(Visitor, Node) => Any} callback the callback
     * @param {Integer} addRemove like with native AHK callbacks, specify 1 to append the callback
     *          to the visitor's list for this node, 0 to remove it, or -1 to prepend it
     */
    OnExit(nodeType, callback, addRemove := 1) =>
        this._AddCallback(this._exitCallbacks, nodeType, callback, addRemove)

    /**
     * Walks the tree and invokes callbacks
     */
    Visit() {
        cursor := this._cursor
        visitedChildren := false
        loop {
            if (!visitedChildren) {
                node := cursor.Current
                this._InvokeCallbacks(this._enterCallbacks, node)

                if (cursor.GotoFirstChild()) {
                    continue
                }
                visitedChildren := true  ; leaf — fall through to Exit immediately
            }

            this._InvokeCallbacks(this._exitCallbacks, cursor.Current)

            if (cursor.GotoNextSibling()) {
                visitedChildren := false
            } else if (!cursor.GotoParent()) {
                break
            }
        }
    }

    /**
     * @private invokes callbacks
     * @param {Map<String, Array<Func(Visitor, Node) => Any>} callbackMap callbacks to invoke
     * @param {Node} node node to invoke callbacks with
     */
    _InvokeCallbacks(callbackMap, node) {
        if(callbackMap.Has(node.Type)) {
            for(callback in callbackMap[node.Type]) {
                callback.Call(this, node)
            }
        }

        ; Special-case: * listens for everything
        if(callbackMap.Has("*")) {
            for(callback in callbackMap["*"]) {
                callback.Call(this, node)
            }
        }
    }

    /**
     * @private Actual callback addition logic. Checks types and values
     * @param callbackMap
     * @param nodeType
     * @param callback
     * @param {Integer} addRemove Whether to append, prepend, or remove the callback
     */
    _AddCallback(callbackMap, nodeType, callback, addRemove) {
        if(!(nodeType is String))
            throw TypeError("Expected a String but got a(n) " Type(nodeType), , nodeType)

        if(!HasMethod(callback, , 2))
            throw TypeError("Visitor must be callable with two arguments", , callback)

        ; Validate the node type against the grammar when we know the language.
        if(nodeType != "*" && this._language && !this._language.GetSymbolId(nodeType)) {
            lang := this._language
            throw ValueError(StrTitle(lang.Name) " v" lang.LanguageVersion " has no such symbol", , '"' nodeType '"')
        }

        if(!callbackMap.Has(nodeType))
            callbackMap[nodeType] := []

        switch(addRemove) {
            case 1 :
                callbackMap[nodeType].Push(callback)
            case -1:
                callbackMap[nodeType].InsertAt(1, callback)
            case 0:
                registered := callbackMap[nodeType]
                for(rc in registered) {
                    if(rc = callback) {
                        registered.RemoveAt(A_Index)
                        return
                    }
                }

                throw ValueError("Cannot remove callback not registered to '" nodeType "' visitor", , callback)
            default:
                throw ValueError("Invalid add / remove value: specifiy 1, 0, or -1", , addRemove)
        }
    }
}
