#Requires AutoHotkey v2.0

/**
 * NOTE: this expects to have the tree-sitter runtime and the tree-sitter grammar located in a .\bin directory.
 * See https://github.com/holy-tao/tree-sitter-autohotkey for the grammar
 */
#DllLoad bin\tree-sitter.dll
#DllLoad bin\tree-sitter-autohotkey.dll

#Include TSParser.ahk
#Include TSLanguage.ahk
#Include TSTreeCursor.ahk

lang := TSLanguage(DllCall("tree-sitter-autohotkey\tree_sitter_autohotkey", "cdecl ptr"))
parser := TSParser(lang)

showHidden := false
nodes := Map()
source := ""

window := CreateMainGui()
window["Tree"].OnEvent("ItemSelect", OnItemSelected.Bind(window))
window.OnEvent("Close", (*) => ExitApp(0))
window.Show()

OpenFile()

^o::OpenFile()

/**
 * Builds the main Gui with a menu bar
 */
CreateMainGui() {
    window := Gui("", "AST Viewer")
    window.SetFont("", "Consolas")

    fileMenu := Menu()
    fileMenu.Add("&Open`tCtrl+O", (*) => OpenFile())
    fileMenu.Add()
    fileMenu.Add("E&xit", (*) => ExitApp(0))

    windowMenu := MenuBar()
    windowMenu.Add("&File", fileMenu)
    window.MenuBar := windowMenu

    window.AddTreeView("+Readonly w350 h600 vTree")
    tabs := window.AddTab3("w600 h610 x+10 y0 vTab", ["Code", "S-Expression"])

    tabs.UseTab(1)
    window.AddEdit("Readonly Multi +Vscroll +HScroll w575 h570 vCodeEdit")

    tabs.UseTab(2)
    window.AddEdit("Readonly Multi +Vscroll +HScroll w575 h570 vExprEdit")

    return window
}

/**
 * File > Open handler. Prompts for a file, parses it, and refreshes the tree view.
 */
OpenFile() {
    global source, nodes
    window.Opt("+OwnDialogs")

    filepath := FileSelect("1", A_WorkingDir, "Select a file to view", "AHK Script (*.ahk; *.ah2; *.ahk2)")
    if (filepath == "")
        return

    source := FileRead(filepath, "RAW")
    tree := parser.Parse(source, TSInputEncoding.UTF8)
    cursor := TSTreeCursor(tree.Root)

    window["CodeEdit"].Value := ""
    window["ExprEdit"].Value := ""

    SplitPath(filepath, &name)
    window.Title := "AST Viewer - " . name

    UpdateTree(window, cursor)
}

/**
 * Walks the tree using a cursor and populates the Gui's TreeView and a map of tree IDs to nodes
 * for later inspection
 * 
 * @param {Gui} window the Gui 
 * @param {TSTreeCursor} cursor The tree cursor to use 
 */
UpdateTree(window, cursor) {
    window["Tree"].Opt("-Redraw")
    window["Tree"].Delete()
    global nodes := Map()

    ; Stack of node IDs
    nodeIdStack := [0]

    visitedChildren := false
    loop {
        if (!visitedChildren) {
            node := cursor.Current

            ; Ignore anonymous nodes
            if(node.IsNamed || node.IsMissing) {
                treeName := node.Type
                if(fieldName := cursor.CurrentFieldName) {
                    treeName := fieldName ": " treeName
                }
                if(node.HasError) {
                    treeName := "(!!!) " treeName
                }

                id := window["Tree"].Add(treeName, nodeIdStack[-1])
                nodeIdStack.Push(id)
                nodes[id] := node
            }

            if (cursor.GotoFirstChild()) {
                continue  ; descend
            }
            visitedChildren := true  ; leaf node, treat as already visited
        }

        if (cursor.Current.IsNamed || cursor.Current.IsMissing)
            nodeIdStack.Pop()

        if (cursor.GotoNextSibling()) {
            visitedChildren := false  ; new subtree, reset
        } 
        else if (!cursor.GotoParent()) {
            break  ; GotoParent returns false at the cursor's root node
        }
    }

    window["Tree"].Opt("+Redraw")
}

/**
 * ItemSelect callback. Updates the displays.
 * 
 * @param window 
 * @param treeView 
 * @param item 
 */
OnItemSelected(window, treeView, item) {
    node := nodes[item]

    window["ExprEdit"].value := node.NodeString
    window["CodeEdit"].value := node.Text

}