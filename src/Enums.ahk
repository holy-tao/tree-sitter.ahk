#Requires AutoHotkey v2.1-alpha.30

class _Enum {
    static ToString(value) {
        for(key, enumValue in this.OwnProps()){
            if(enumValue == value)
                return key
        }

        throw ValueError(Format("Not a(n) {1} value", this.Prototype.__Class), -1, value)
    }
}

export class InputEncoding extends _Enum {
    static UTF8     => 0
    static UTF16LE  => 1
    static UTF16BE  => 2
    static Custom   => 3
}

export class SymbolType extends _Enum {
    static Regular   => 0
    static Anonymous => 1
    static Supertype => 2
    static Auxiliary => 3
}

export class Quantifier extends _Enum {
    static Zero       => 0
    static ZeroOrOne  => 1
    static ZeroOrMore => 2
    static One        => 3
    static OneOrMore  => 4
}

export class QueryPredicateStepType extends _Enum {
    static Done       => 0
    static Capture    => 1
    static String     => 2
}

export class QueryError extends _Enum {
    static None       => 0
    static Syntax     => 1
    static NodeType   => 2
    static Field      => 3
    static Capture    => 4
    static Structure  => 5
    static Language   => 6
}