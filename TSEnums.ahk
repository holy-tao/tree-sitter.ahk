#Requires AutoHotkey v2.0

class _TSEnum {
    static ToString(value) {
        for(key, enumValue in this.OwnProps()){
            if(enumValue == value)
                return key
        }

        throw ValueError(Format("Not a(n) {1} value", this.Prototype.__Class), -1, value)
    }
}

class TSInputEncoding extends _TSEnum {
    static UTF8     => 0
    static UTF16LE  => 1
    static UTF16BE  => 2
    static Custom   => 3
}

class TSSymbolType extends _TSEnum {
    static Regular   => 0
    static Anonymous => 1
    static Supertype => 2
    static Auxiliary => 3
}

class TSQuantifier extends _TSEnum {
    static Zero       => 0
    static ZeroOrOne  => 1
    static ZeroOrMore => 2
    static One        => 3
    static OneOrMore  => 4
}

class TSQueryPredicateStepType extends _TSEnum {
    static Done       => 0
    static Capture    => 1
    static String     => 2
}

class TSQueryError extends _TSEnum {
    static None       => 0
    static Syntax     => 1
    static NodeType   => 2
    static Field      => 3
    static Capture    => 4
    static Structure  => 5
    static Language   => 6
}