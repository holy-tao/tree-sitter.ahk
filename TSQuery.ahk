#Requires AutoHotkey v2.0 64-bit

#Include TSLanguage.ahk
#Include TSEnums.ahk
#Include TSNode.ahk

/**
 * A set of patterns that match nodes in a syntax tree.
 * 
 * @see https://tree-sitter.github.io/tree-sitter/using-parsers/queries/index.html
 */
class TSQuery {

    /**
     * Get the number of patterns in the query.
     */
    PatternCount => DllCall("tree-sitter\ts_query_pattern_count", "ptr", this, "cdecl uint")

    /**
     * Get the number of captures in the query.
     */
    CaptureCount => DllCall("tree-sitter\ts_query_capture_count", "ptr", this, "cdecl uint")

    /**
     * Get the number of string literals in the query.
     */
    StringCount => DllCall("tree-sitter\ts_query_string_count", "ptr", this, "cdecl uint")

    /**
     * Create a new query from a string containing one or more S-expression
     * patterns. The query is associated with a particular language, and can
     * only be run on syntax nodes parsed with that language.
     * 
     * @param {TSLanguage} language the language
     * @param {String} expression the s-expression(s) of the query
     */
    __New(language, expression) {
        if(!(language is TSLanguage))
            throw TypeError("Expected a TSLanguage but got a(n) " Type(language), -1, language)

        if(!(expression is String))
            throw TypeError("Expected a String but got a(n) " Type(expression), -1, expression)

        this.ptr := DllCall("tree-sitter\ts_query_new", 
            "ptr", language,
            "astr", expression,
            "uint", StrLen(expression),
            "uint*", &errOffset := 0,
            "uint*", &errType := 0,
            "cdecl ptr")

        if(this.ptr == 0) {
            msg := Format("Query {1} error at offset {2}",
                StrLower(TSQueryError.ToString(errType)), errOffset)
            throw ValueError(msg, -1, expression)
        }

        this._predicateCache := Map()
        this._settingsCache := Map()
    }

    /**
     * Get the byte offset where the given pattern starts in the query's source.
     *
     * This can be useful when combining queries by concatenating their source
     * code strings.
     * 
     * @param {Integer} patternIndex the index of the pattern to query for
     * @returns {Integer} the byte offset where the pattern starts in the query's source
     */
    GetPatternStart(patternIndex := 0) {
        TSNode._AssertInt(patternIndex)

        return DllCall("tree-sitter\ts_query_start_byte_for_pattern",
            "ptr", this,
            "uint", patternIndex,
            "cdecl uint")
    }

    /**
     * Get the byte offset where the given pattern ends in the query's source.
     *
     * This can be useful when combining queries by concatenating their source
     * code strings.
     * 
     * @param {Integer} patternIndex the index of the pattern to query for
     * @returns {Integer} the byte offset where the pattern starts in the query's source
     */
    GetPatternEnd(patternIndex := 0) {
        TSNode._AssertInt(patternIndex)

        return DllCall("tree-sitter\ts_query_end_byte_for_pattern",
            "ptr", this,
            "uint", patternIndex,
            "cdecl uint")
    }

    /**
     * Get all of the predicates for the given pattern in the query.
     *
     * The predicates are represented as a single array of steps. There are three
     * types of steps in this array, which correspond to the three legal values for
     * the `type` field:
     * - `TSQueryPredicateStepTypeCapture` - Steps with this type represent names
     *    of captures. Their `value_id` can be used with the
     *    `GetCaptureNameForId` function to obtain the name of the capture.
     * - `TSQueryPredicateStepTypeString` - Steps with this type represent literal
     *    strings. Their `value_id` can be used with the
     *    `GetStringValueForId` function to obtain their string value.
     * - `TSQueryPredicateStepTypeDone` - Steps with this type are *sentinels*
     *    that represent the end of an individual predicate. If a pattern has two
     *    predicates, then there will be two steps with this `type` in the array.
     * 
     * For a higher-level parsed representation, use `GetPredicates()` instead.
     *
     * @see https://tree-sitter.github.io/tree-sitter/using-parsers/queries/3-predicates-and-directives.html
     * @param {Integer} patternIndex the index of the pattern to query for
     * @returns {Array<TSQuery.PredicateStep>} the raw predicate steps for the given pattern
     */
    GetPatternPredicates(patternIndex := 0) {
        TSNode._AssertInt(patternIndex)

        arrPtr := DllCall("tree-sitter\ts_query_predicates_for_pattern",
            "ptr", this,
            "uint", patternIndex,
            "uint*", &arrLen := 0,
            "cdecl ptr")

        ; Like TSPoint, TSQueryPredicateStep is an 8-byte struct that should get passed via rax on x64
        predicates := Array(), predicates.Length := arrLen
        loop(arrLen) {
            v := NumGet(arrPtr, 8 * (A_Index - 1), "uint64")
            predicates[A_Index] := TSQuery.PredicateStep(v & 0xFFFFFFFF, (v >> 32) & 0xFFFFFFFF)
        }

        return predicates
    }

    /**
     * Get the parsed predicates for the given pattern.
     *
     * Returns an array of predicate objects, each with a `name` (the predicate
     * name without the `#` prefix, e.g. `"eq?"`) and an `args` array. Each arg
     * is an object with `type` (`"capture"` or `"string"`) and `value`.
     *
     * Results are cached per pattern index.
     *
     * @param {Integer} patternIndex the index of the pattern
     * @returns {Array<{name: String, args: Array<{type: String, value: String}>}>}
     */
    GetPredicates(patternIndex := 0) {
        TSNode._AssertInt(patternIndex)

        if (this._predicateCache.Has(patternIndex))
            return this._predicateCache[patternIndex]

        steps := this.GetPatternPredicates(patternIndex)
        predicates := Array()
        current := Array()

        for (step in steps) {
            if (step.type == TSQueryPredicateStepType.Done) {
                if (current.Length > 0) {
                    ; First step must be the predicate name (a string)
                    nameStep := current[1]
                    if (nameStep.type !== TSQueryPredicateStepType.String)
                        throw Error("Predicate must start with a string name", -1)

                    args := Array()
                    loop (current.Length - 1) {
                        s := current[A_Index + 1]
                        args.Push(s.type == TSQueryPredicateStepType.Capture ? 
                            {type: "capture", value: this.GetCaptureNameForId(s.id)} :
                            {type: "string", value: this.GetStringValueForId(s.id)}
                        )
                    }

                    predicates.Push({name: this.GetStringValueForId(nameStep.id), args: args})
                }
                current := Array()
            } 
            else {
                current.Push(step)
            }
        }

        this._predicateCache[patternIndex] := predicates
        return predicates
    }

    /**
     * Get the `#set!` directive settings for the given pattern.
     *
     * Returns a Map of key/value pairs from all `#set!` directives on the
     * pattern. A `#set!` with only a key and no value sets the value to `true`.
     *
     * Results are cached per pattern index.
     *
     * @param {Integer} patternIndex the index of the pattern
     * @returns {Map<String, String>}
     */
    GetPatternSettings(patternIndex := 0) {
        TSNode._AssertInt(patternIndex)

        if this._settingsCache.Has(patternIndex)
            return this._settingsCache[patternIndex]

        settings := Map()
        for (pred in this.GetPredicates(patternIndex)) {
            if (pred.name == "set!") {
                if (pred.args.Length >= 2) {
                    settings[pred.args[1].value] := pred.args[2].value
                }
                else if (pred.args.Length == 1) {
                    settings[pred.args[1].value] := true
                }
            }
        }

        this._settingsCache[patternIndex] := settings
        return settings
    }

    /**
     * Check if the given pattern in the query has a single root node
     * 
     * @param {Integer} patternIndex the index of the pattern to query for
     * @returns {Boolean} true if the pattern is rooted, false otherwise
     */
    IsPatternRooted(patternIndex := 0) {
        TSNode._AssertInt(patternIndex)

        return DllCall("tree-sitter\ts_query_is_pattern_rooted", 
            "ptr", this, 
            "uint", patternIndex,
            "cdecl uchar")
    }

    /**
     * Check if the given pattern in the query is 'non local'.
     *
     * A non-local pattern has multiple root nodes and can match within a
     * repeating sequence of nodes, as specified by the grammar. Non-local
     * patterns disable certain optimizations that would otherwise be possible
     * when executing a query on a specific range of a syntax tree.
     * 
     * @param {Integer} patternIndex the index of the pattern to query for
     * @returns {Boolean} true if the pattern is non-local, false otherwise
     */
    IsPatternNonLocal(patternIndex := 0) {
        TSNode._AssertInt(patternIndex)

        return DllCall("tree-sitter\ts_query_is_pattern_non_local", 
            "ptr", this, 
            "uint", patternIndex,
            "cdecl uchar")
    }

    /**
     * Check if a given pattern is guaranteed to match once a given step is reached.
     * The step is specified by its byte offset in the query's source code.
     * 
     * @param {Integer} byteOffset the byte offset into the query's source string at
     *          which the step in the pattern you want to check begins
     * @returns {Boolean} true of the pattern is guaranteed at a step, false otherwise
     */
    IsPatternGuaranteedAtStep(byteOffset) {
        TSNode._AssertInt(byteOffset)

        return DllCall("tree-sitter\ts_query_is_pattern_guaranteed_at_step", 
            "ptr", this, 
            "uint", byteOffset,
            "cdecl uchar")
    }

    /**
     * Get the name of one of the query's captures. Each capture is associated
     * with a numeric id based on the order that it appeared in the query's source.
     *
     * @param {Integer} index the index of the capture
     * @returns {String} the name of the capture
     */
    GetCaptureNameForId(index) {
        TSNode._AssertInt(index)

        ptr := DllCall("tree-sitter\ts_query_capture_name_for_id",
            "ptr", this,
            "uint", index,
            "uint*", &length := 0,
            "cdecl ptr")

        return StrGet(ptr, length, "CP0")
    }

    /**
     * Get the quantifier of the query's captures. Each capture is associated
     * with a numeric id based on the order that it appeared in the query's source.
     *
     * @param {Integer} patternIndex the index of the pattern
     * @param {Integer} captureIndex the index of the capture
     * @returns {Integer} the quantifier value
     */
    GetCaptureQuantifierForId(patternIndex, captureIndex) {
        TSNode._AssertInt(patternIndex)
        TSNode._AssertInt(captureIndex)

        return DllCall("tree-sitter\ts_query_capture_quantifier_for_id",
            "ptr", this,
            "uint", patternIndex,
            "uint", captureIndex,
            "cdecl uint")
    }

    /**
     * Get the string value of one of the query's string literals. Each string
     * is associated with a numeric id based on the order that it appeared in
     * the query's source.
     *
     * @param {Integer} index the index of the string literal
     * @returns {String} the string value
     */
    GetStringValueForId(index) {
        TSNode._AssertInt(index)

        ptr := DllCall("tree-sitter\ts_query_string_value_for_id",
            "ptr", this,
            "uint", index,
            "uint*", &length := 0,
            "cdecl ptr")

        return StrGet(ptr, length, "CP0")
    }

    /**
     * Disable a certain capture within a query.
     *
     * This prevents the capture from being returned in matches, and also avoids
     * any resource usage associated with recording the capture. Currently, there
     * is no way to undo this.
     *
     * @param {String} name the name of the capture to disable
     */
    DisableCapture(name) {
        DllCall("tree-sitter\ts_query_disable_capture",
            "ptr", this,
            "astr", name,
            "uint", StrLen(name),
            "cdecl")
    }

    /**
     * Disable a certain pattern within a query.
     *
     * This prevents the pattern from matching and removes most of the overhead
     * associated with the pattern. Currently, there is no way to undo this.
     *
     * @param {Integer} patternIndex the index of the pattern to disable
     */
    DisablePattern(patternIndex) {
        TSNode._AssertInt(patternIndex)

        DllCall("tree-sitter\ts_query_disable_pattern",
            "ptr", this,
            "uint", patternIndex,
            "cdecl")
    }

    __Delete() => DllCall("tree-sitter\ts_query_delete", "ptr", this, "cdecl")

    /**
     * A raw predicate step from the C API. For parsed predicates, use `GetPredicates()`.
     * @see https://tree-sitter.github.io/tree-sitter/using-parsers/queries/3-predicates-and-directives.html
     */
    class PredicateStep {
        __New(type, id) {
            this.type := type
            this.id := id
        }
    }
}