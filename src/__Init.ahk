#Requires AutoHotkey v2.1-alpha.30 64-bit

/************************************************************************
 * @description Barrel/entry module for the tree-sitter bindings.
 *
 * Each sibling file is its own module with a default export (e.g.
 * `export default struct Node`). This file re-exports them all via
 * `#Import export`, so a consumer can pull in the whole namespace:
 *
 *     #Import "tree-sitter" as TreeSitter
 *     lang := TreeSitter.Language(ptr)
 *
 * ...or grab pieces individually, since the names are re-exported:
 *
 *     #Import "tree-sitter" {Node, Parser}
 ***********************************************************************/

; Core types (one default export per file)
#Import export Language
#Import export Node {*}      ; Node (default) + Point
#Import export Tree
#Import export Parser
#Import export Query
#Import export QueryCursor
#Import export TreeCursor

; Enums (multiple exports, no default) — flatten via wildcard
#Import export Enums {*}

; Utilities
#Import export util
