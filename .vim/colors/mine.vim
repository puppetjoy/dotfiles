"
" Based on base16-vim (https://github.com/chriskempson/base16-vim)
" by Chris Kempson (http://chriskempson.com)
"

" GUI color definitions
let s:gui = ["000000", "282828", "383838", "585858", "b8b8b8", "d8d8d8", "e8e8e8", "f8f8f8", "ab4642", "dc9656", "f7ca88", "a1b56c", "86c1b9", "7cafc2", "ba8baf", "a16946"]

" Terminal color definitions
if &t_Co >= 256
  let s:cterm = [0, 18, 19, 8, 20, 7, 21, 15, 1, 16, 3, 2, 6, 4, 5, 17]
  let s:bold = []
  let s:visualfg = "05"
  let s:visualbg = "02"
elseif &t_Co >= 16
  let s:cterm = [0, 0, 0, 8, 7, 7, 15, 15, 1, 3, 3, 2, 6, 4, 5, 8]
  let s:bold = []
  let s:visualfg = "00"
  let s:visualbg = "05"
else
  let s:cterm = [0, 0, 0, 0, 7, 7, 7, 7, 1, 3, 3, 2, 6, 4, 5, 0]
  let s:bold = ["03", "06", "07", "0F"]
  let s:visualfg = "05"
  let s:visualbg = "00"
endif

" Theme setup
hi clear
syntax reset
let g:colors_name = "mine"

" Highlighting function
fun <sid>hi(group, guifg, guibg, ctermfg, ctermbg, attr, guisp)
  " Check whether our scheme suggests this color should be bold
  let l:cattr = a:attr
  if index(s:bold, a:ctermfg) > -1
    if l:cattr != ""
      let l:cattr .= ","
    endif
    let l:cattr .= "bold"
  endif

  if a:guifg != ""
    exec "hi " . a:group . " guifg=#" . s:gui["0x" . a:guifg]
  endif
  if a:guibg != ""
    exec "hi " . a:group . " guibg=#" . s:gui["0x" . a:guibg]
  endif
  if a:ctermfg != ""
    exec "hi " . a:group . " ctermfg=" . s:cterm["0x" . a:ctermfg]
  endif
  if a:ctermbg != ""
    exec "hi " . a:group . " ctermbg=" . s:cterm["0x" . a:ctermbg]
  endif
  if a:attr != ""
    exec "hi " . a:group . " gui=" . a:attr
  endif
  if l:cattr != ""
    exec "hi " . a:group . " cterm=" . l:cattr
  endif
  if a:guisp != ""
    exec "hi " . a:group . " guisp=#" . s:gui["0x" . a:guisp]
  endif
endfun

" Vim editor colors
call <sid>hi("Bold",          "", "", "", "", "bold", "")
call <sid>hi("Debug",         "08", "", "08", "", "", "")
call <sid>hi("Directory",     "0D", "", "0D", "", "", "")
call <sid>hi("Error",         "00", "08", "00", "08", "", "")
call <sid>hi("ErrorMsg",      "08", "00", "08", "00", "", "")
call <sid>hi("Exception",     "08", "", "08", "", "", "")
call <sid>hi("FoldColumn",    "0C", "01", "0C", "01", "", "")
call <sid>hi("Folded",        "03", "01", "03", "01", "", "")
call <sid>hi("IncSearch",     "01", "09", "01", "09", "none", "")
call <sid>hi("Italic",        "", "", "", "", "none", "")
call <sid>hi("Macro",         "08", "", "08", "", "", "")
call <sid>hi("MatchParen",    "03", "0A", "03", "0A", "", "")
call <sid>hi("ModeMsg",       "0B", "", "0B", "", "", "")
call <sid>hi("MoreMsg",       "0B", "", "0B", "", "", "")
call <sid>hi("Question",      "0D", "", "0D", "", "", "")
call <sid>hi("Search",        "03", "0A", "03", "0A", "", "")
call <sid>hi("SpecialKey",    "03", "", "03", "", "", "")
call <sid>hi("TooLong",       "08", "", "08", "", "", "")
call <sid>hi("Underlined",    "08", "", "08", "", "", "")
call <sid>hi("Visual",        "", "02", s:visualfg, s:visualbg, "", "")
call <sid>hi("VisualNOS",     "08", "", "08", "", "", "")
call <sid>hi("WarningMsg",    "08", "", "08", "", "", "")
call <sid>hi("WildMenu",      "08", "0A", "08", "", "", "")
call <sid>hi("Title",         "0D", "", "0D", "", "none", "")
call <sid>hi("Conceal",       "0D", "00", "0D", "00", "", "")
call <sid>hi("Cursor",        "00", "05", "00", "05", "", "")
call <sid>hi("NonText",       "03", "", "03", "", "", "")
call <sid>hi("Normal",        "05", "00", "05", "00", "", "")
call <sid>hi("LineNr",        "03", "01", "03", "01", "", "")
call <sid>hi("SignColumn",    "03", "01", "03", "01", "", "")
call <sid>hi("StatusLine",    "04", "02", "04", "02", "none", "")
call <sid>hi("StatusLineNC",  "03", "01", "03", "01", "none", "")
call <sid>hi("VertSplit",     "02", "02", "02", "02", "none", "")
call <sid>hi("ColorColumn",   "", "01", "", "01", "none", "")
call <sid>hi("CursorColumn",  "", "01", "", "01", "none", "")
call <sid>hi("CursorLine",    "", "01", "", "01", "none", "")
call <sid>hi("CursorLineNr",  "04", "01", "04", "01", "none", "")
call <sid>hi("PMenu",         "04", "01", "04", "01", "none", "")
call <sid>hi("PMenuSel",      "01", "04", "01", "04", "", "")
call <sid>hi("TabLine",       "03", "01", "03", "01", "none", "")
call <sid>hi("TabLineFill",   "03", "01", "03", "01", "none", "")
call <sid>hi("TabLineSel",    "0B", "01", "0B", "01", "none", "")

" Standard syntax highlighting
call <sid>hi("Boolean",      "09", "", "09", "", "", "")
call <sid>hi("Character",    "08", "", "08", "", "", "")
call <sid>hi("Comment",      "03", "", "03", "", "", "")
call <sid>hi("Conditional",  "0E", "", "0E", "", "", "")
call <sid>hi("Constant",     "09", "", "09", "", "", "")
call <sid>hi("Define",       "0E", "", "0E", "", "none", "")
call <sid>hi("Delimiter",    "0F", "", "0F", "", "", "")
call <sid>hi("Float",        "09", "", "09", "", "", "")
call <sid>hi("Function",     "0D", "", "0D", "", "", "")
call <sid>hi("Identifier",   "08", "", "08", "", "none", "")
call <sid>hi("Include",      "0D", "", "0D", "", "", "")
call <sid>hi("Keyword",      "0E", "", "0E", "", "", "")
call <sid>hi("Label",        "0A", "", "0A", "", "", "")
call <sid>hi("Number",       "09", "", "09", "", "", "")
call <sid>hi("Operator",     "05", "", "05", "", "none", "")
call <sid>hi("PreProc",      "0A", "", "0A", "", "", "")
call <sid>hi("Repeat",       "0A", "", "0A", "", "", "")
call <sid>hi("Special",      "0C", "", "0C", "", "", "")
call <sid>hi("SpecialChar",  "0F", "", "0F", "", "", "")
call <sid>hi("Statement",    "08", "", "08", "", "", "")
call <sid>hi("StorageClass", "0A", "", "0A", "", "", "")
call <sid>hi("String",       "0B", "", "0B", "", "", "")
call <sid>hi("Structure",    "0E", "", "0E", "", "", "")
call <sid>hi("Tag",          "0A", "", "0A", "", "", "")
call <sid>hi("Todo",         "0A", "01", "0A", "01", "", "")
call <sid>hi("Type",         "0A", "", "0A", "", "none", "")
call <sid>hi("Typedef",      "0A", "", "0A", "", "", "")

" C highlighting
call <sid>hi("cOperator",   "0C", "", "0C", "", "", "")
call <sid>hi("cPreCondit",  "0E", "", "0E", "", "", "")

" C# highlighting
call <sid>hi("csClass",                 "0A", "", "0A", "", "", "")
call <sid>hi("csAttribute",             "0A", "", "0A", "", "", "")
call <sid>hi("csModifier",              "0E", "", "0E", "", "", "")
call <sid>hi("csType",                  "08", "", "08", "", "", "")
call <sid>hi("csUnspecifiedStatement",  "0D", "", "0D", "", "", "")
call <sid>hi("csContextualStatement",   "0E", "", "0E", "", "", "")
call <sid>hi("csNewDecleration",        "08", "", "08", "", "", "")

" CSS highlighting
call <sid>hi("cssBraces",      "05", "", "05", "", "", "")
call <sid>hi("cssClassName",   "0E", "", "0E", "", "", "")
call <sid>hi("cssColor",       "0C", "", "0C", "", "", "")

" Diff highlighting
call <sid>hi("DiffAdd",      "0B", "01",  "0B", "01", "", "")
call <sid>hi("DiffChange",   "03", "01",  "03", "01", "", "")
call <sid>hi("DiffDelete",   "08", "01",  "08", "01", "", "")
call <sid>hi("DiffText",     "0D", "01",  "0D", "01", "", "")
call <sid>hi("DiffAdded",    "0B", "00",  "0B", "00", "", "")
call <sid>hi("DiffFile",     "08", "00",  "08", "00", "", "")
call <sid>hi("DiffNewFile",  "0B", "00",  "0B", "00", "", "")
call <sid>hi("DiffLine",     "0D", "00",  "0D", "00", "", "")
call <sid>hi("DiffRemoved",  "08", "00",  "08", "00", "", "")

" Git highlighting
call <sid>hi("gitcommitOverflow",       "08", "", "08", "", "", "")
call <sid>hi("gitcommitSummary",        "0B", "", "0B", "", "", "")
call <sid>hi("gitcommitComment",        "03", "", "03", "", "", "")
call <sid>hi("gitcommitUntracked",      "03", "", "03", "", "", "")
call <sid>hi("gitcommitDiscarded",      "03", "", "03", "", "", "")
call <sid>hi("gitcommitSelected",       "03", "", "03", "", "", "")
call <sid>hi("gitcommitHeader",         "0E", "", "0E", "", "", "")
call <sid>hi("gitcommitSelectedType",   "0D", "", "0D", "", "", "")
call <sid>hi("gitcommitUnmergedType",   "0D", "", "0D", "", "", "")
call <sid>hi("gitcommitDiscardedType",  "0D", "", "0D", "", "", "")
call <sid>hi("gitcommitBranch",         "09", "", "09", "", "bold", "")
call <sid>hi("gitcommitUntrackedFile",  "0A", "", "0A", "", "", "")
call <sid>hi("gitcommitUnmergedFile",   "08", "", "08", "", "bold", "")
call <sid>hi("gitcommitDiscardedFile",  "08", "", "08", "", "bold", "")
call <sid>hi("gitcommitSelectedFile",   "0B", "", "0B", "", "bold", "")

" GitGutter highlighting
call <sid>hi("GitGutterAdd",     "0B", "01", "0B", "01", "", "")
call <sid>hi("GitGutterChange",  "0D", "01", "0D", "01", "", "")
call <sid>hi("GitGutterDelete",  "08", "01", "08", "01", "", "")
call <sid>hi("GitGutterChangeDelete",  "0E", "01", "0E", "01", "", "")

" HTML highlighting
call <sid>hi("htmlBold",    "0A", "", "0A", "", "", "")
call <sid>hi("htmlItalic",  "0E", "", "0E", "", "", "")
call <sid>hi("htmlEndTag",  "05", "", "05", "", "", "")
call <sid>hi("htmlTag",     "05", "", "05", "", "", "")

" JavaScript highlighting
call <sid>hi("javaScript",        "05", "", "05", "", "", "")
call <sid>hi("javaScriptBraces",  "05", "", "05", "", "", "")
call <sid>hi("javaScriptNumber",  "09", "", "09", "", "", "")

" Mail highlighting
call <sid>hi("mailQuoted1",  "0A", "", "0A", "", "", "")
call <sid>hi("mailQuoted2",  "0B", "", "0B", "", "", "")
call <sid>hi("mailQuoted3",  "0E", "", "0E", "", "", "")
call <sid>hi("mailQuoted4",  "0C", "", "0C", "", "", "")
call <sid>hi("mailQuoted5",  "0D", "", "0D", "", "", "")
call <sid>hi("mailQuoted6",  "0A", "", "0A", "", "", "")
call <sid>hi("mailURL",      "0D", "", "0D", "", "", "")
call <sid>hi("mailEmail",    "0D", "", "0D", "", "", "")

" Markdown highlighting
call <sid>hi("markdownCode",              "0B", "", "0B", "", "", "")
call <sid>hi("markdownError",             "05", "00", "05", "00", "", "")
call <sid>hi("markdownCodeBlock",         "0B", "", "0B", "", "", "")
call <sid>hi("markdownHeadingDelimiter",  "0D", "", "0D", "", "", "")

" NERDTree highlighting
call <sid>hi("NERDTreeDirSlash",  "0D", "", "0D", "", "", "")
call <sid>hi("NERDTreeExecFile",  "05", "", "05", "", "", "")

" PHP highlighting
call <sid>hi("phpMemberSelector",  "05", "", "05", "", "", "")
call <sid>hi("phpComparison",      "05", "", "05", "", "", "")
call <sid>hi("phpParent",          "05", "", "05", "", "", "")

" Python highlighting
call <sid>hi("pythonOperator",  "0E", "", "0E", "", "", "")
call <sid>hi("pythonRepeat",    "0E", "", "0E", "", "", "")

" Ruby highlighting
call <sid>hi("rubyAttribute",               "0D", "", "0D", "", "", "")
call <sid>hi("rubyConstant",                "0A", "", "0A", "", "", "")
call <sid>hi("rubyInterpolationDelimiter",  "0F", "", "0F", "", "", "")
call <sid>hi("rubyRegexp",                  "0C", "", "0C", "", "", "")
call <sid>hi("rubySymbol",                  "0B", "", "0B", "", "", "")
call <sid>hi("rubyStringDelimiter",         "0B", "", "0B", "", "", "")

" SASS highlighting
call <sid>hi("sassidChar",     "08", "", "08", "", "", "")
call <sid>hi("sassClassChar",  "09", "", "09", "", "", "")
call <sid>hi("sassInclude",    "0E", "", "0E", "", "", "")
call <sid>hi("sassMixing",     "0E", "", "0E", "", "", "")
call <sid>hi("sassMixinName",  "0D", "", "0D", "", "", "")

" Signify highlighting
call <sid>hi("SignifySignAdd",     "0B", "01", "0B", "01", "", "")
call <sid>hi("SignifySignChange",  "0D", "01", "0D", "01", "", "")
call <sid>hi("SignifySignDelete",  "08", "01", "08", "01", "", "")

" Spelling highlighting
call <sid>hi("SpellBad",     "", "00", "", "00", "undercurl", "08")
call <sid>hi("SpellLocal",   "", "00", "", "00", "undercurl", "0C")
call <sid>hi("SpellCap",     "", "00", "", "00", "undercurl", "0D")
call <sid>hi("SpellRare",    "", "00", "", "00", "undercurl", "0E")

" Remove functions
delf <sid>hi

" Remove color variables
unlet s:gui s:cterm s:bold s:visualfg s:visualbg
