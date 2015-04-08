" File:        todo.txt.vim
" Description: Todo.txt filetype detection
" Author:      Leandro Freitas <freitass@gmail.com>
" License:     Vim license
" Website:     http://github.com/freitass/todo.txt-vim
" Version:     0.4

" Save context {{{1
let s:save_cpo = &cpo
set cpo&vim

" General options {{{1
" Some options lose their values when window changes. They will be set every
" time this script is invocated, which is whenever a file of this type is
" created or edited.
setlocal textwidth=0
setlocal wrapmargin=0

" Functions {{{1
function! s:TodoTxtRemovePriority()
    :s/^(\w)\s\+//ge
endfunction

function! TodoTxtPrependDate()
    exec ':s/\(^(\w)\s\|^\)/\1'.strftime("%Y-%m-%d").' /'
endfunction

function! TodoTxtMarkAsDone()
    call s:TodoTxtRemovePriority()
    call TodoTxtPrependDate()
    normal! Ix 
endfunction

function! TodoTxtMarkAsCancelled()
    call s:TodoTxtRemovePriority()
    call TodoTxtPrependDate()
    normal! Ix cancel 
endfunction

function! TodoTxtMarkAllAsDone()
    :g!/^x /:call TodoTxtMarkAsDone()
endfunction

function! s:AppendToFile(file, lines)
    let l:lines = []

    " Place existing tasks in done.txt at the beggining of the list.
    if filereadable(a:file)
        call extend(l:lines, readfile(a:file))
    endif

    " Append new completed tasks to the list.
    call extend(l:lines, a:lines)

    " Write to file.
    call writefile(l:lines, a:file)
endfunction

function! s:PrependToFile(file, lines)
    let l:lines = []

    " Append new completed tasks to the list.
    call extend(l:lines, a:lines)

    " Place existing tasks in done.txt at the beggining of the list.
    if filereadable(a:file)
        call extend(l:lines, readfile(a:file))
    endif

    " Write to file.
    call writefile(l:lines, a:file)
endfunction

function! TodoTxtGetBaseName()
    let l:name = tolower(expand('%:t:r:f'))
    if stridx(l:name, "-") >= 0
        return substitute(l:name, "-.*$", "", "")
    else
        return l:name
    end
endfunction

function! TodoTxtGetContextName()
    let l:name = tolower(expand('%:t:r:f'))
    if stridx(l:name, "-") >= 0
        return substitute(l:name, "^[^-]*", "", "")
    else
        return ""
    end
endfunction

function! TodoTxtGetSiblingFileName(base_name)
    let l:cur_filename = expand('%:t:r:f')
    let l:cur_context = TodoTxtGetContextName()

    if l:cur_filename =~ "^[A-Z]" " check for uppercase
        let l:first_letter = toupper(a:base_name[0])
    else
        let l:first_letter = a:base_name[0]
    endif

    return l:first_letter.a:base_name[1:].l:cur_context.".txt"
endfunction

function! TodoTxtGetSiblingFilePath(file_name)
    let l:cur_dir = expand('%:p:h')
    return l:cur_dir."/".a:file_name
endfunction

function! s:IsWritableOrCreatable(file_path)
    let l:file_dir = fnamemodify(expand(a:file_path), ":p:h") 
    return filewritable(a:file_path) || filewritable(l:file_dir)
endfunction

function! TodoTxtRemoveCompleted()
    let l:target_file_name = TodoTxtGetSiblingFileName('done')
    let l:target_file = TodoTxtGetSiblingFilePath(l:target_file_name)
    " Check if we can write to target file before proceeding.
    if !s:IsWritableOrCreatable(l:target_file)
        echoerr "Can't write to file '".l:target_file_name."'"
        return
    endif

    let l:completed = []
    :g/^x /call add(l:completed, getline(line(".")))|d
    call s:AppendToFile(l:target_file, l:completed)
endfunction

function! s:MoveToSiblingFile(base_name, l1, l2)
    let l:target_file_name = TodoTxtGetSiblingFileName(a:base_name)
    let l:target_file = TodoTxtGetSiblingFilePath(l:target_file_name)
    " Check if we can write to target file before proceeding.
    if !s:IsWritableOrCreatable(l:target_file)
        echoerr "Can't write to file '".l:target_file_name."'"
        return
    endif

    let l:lines = getline(a:l1, a:l2)

    exec a:l1.",".a:l2."d"

    call s:PrependToFile(l:target_file, l:lines)
endfunction

function! TodoTxtToggleToday(l1, l2) range
    let l:base_name = TodoTxtGetBaseName()
    if l:base_name == 'todo'
        call s:MoveToSiblingFile('today', a:l1, a:l2)
    elseif l:base_name == 'today'
        call s:MoveToSiblingFile('todo', a:l1, a:l2)
    endif
    " else - do nothing
endfunction

" Mappings {{{1
" Sort tasks {{{2
if !hasmapto("<leader>s",'n')
    nnoremap <script> <silent> <buffer> <leader>s :sort<CR>
    nnoremap <script> <silent> <buffer> <leader>ы :sort<CR>
endif

if !hasmapto("<leader>s@",'n')
    nnoremap <script> <silent> <buffer> <leader>s@ :sort /.\{-}\ze@/ <CR>
    nnoremap <script> <silent> <buffer> <leader>ы@ :sort /.\{-}\ze@/ <CR>
endif

if !hasmapto("<leader>s+",'n')
    nnoremap <script> <silent> <buffer> <leader>s+ :sort /.\{-}\ze+/ <CR>
    nnoremap <script> <silent> <buffer> <leader>ы+ :sort /.\{-}\ze+/ <CR>
endif

" Increment and Decrement The Priority
:set nf=octal,hex,alpha

function! s:PrioritizeChange(l, delta, limit, default) " delta must be 1 or -1
    let l:pri = TodoTxtPrioritizeGet(getline(a:l))
    if pri == ""
        call TodoTxtPrioritizeSet(a:default, a:l)
    elseif pri != a:limit
        call TodoTxtPrioritizeSet(nr2char(char2nr(l:pri)+a:delta), a:l)
    endif
endfunction

function! TodoTxtPrioritizeIncrease(lfrom, lto) range
    let l:i = 0
    while l:i == 0 || l:i < v:count
        let l:l = a:lfrom
        while l:l <= a:lto
            call s:PrioritizeChange(l:l, -1, "A", "A")
            let l:l += 1
        endwhile
        let l:i += 1
    endwhile
endfunction

function! TodoTxtPrioritizeDecrease(lfrom, lto) range
    let l:i = 0
    while l:i == 0 || l:i < v:count
        let l:l = a:lfrom
        while l:l <= a:lto
            call s:PrioritizeChange(l:l, 1, "Z", "B")
            let l:l += 1
        endwhile
        let l:i += 1
    endwhile
endfunction

function! TodoTxtPrioritizeGet(line)
    let l:res = matchlist(a:line, '^(\(\w\))\s')
    if empty(l:res)
        return ""
    else
        return toupper(l:res[1])
    endif
endfunction

function! TodoTxtPrioritizeSet(priority, ...)
    if a:0 == 1
        let l:range = "".a:1
    elseif a:0 == 2
        let l:range = a:1.",".a:2
    else
        " no range specified, work on current line
        let l:range = ""
    endif
    exec ':'.l:range.'s/\(^(\w)\s\|^\)/('.a:priority.') /'
endfunction

if !hasmapto("<leader>j",'n')
    nnoremap <script> <silent> <buffer> <leader>j :call TodoTxtPrioritizeDecrease(line("."), line("."))<ESC>
    nnoremap <script> <silent> <buffer> <leader>о :call TodoTxtPrioritizeDecrease(line("."), line("."))<ESC>
endif

if !hasmapto("<leader>j",'v')
    vnoremap <script> <silent> <buffer> <leader>j :call TodoTxtPrioritizeDecrease(line("'<"), line("'>"))<ESC>
    vnoremap <script> <silent> <buffer> <leader>о :call TodoTxtPrioritizeDecrease(line("'<"), line("'>"))<ESC>
endif

if !hasmapto("<leader>k",'n')
    nnoremap <script> <silent> <buffer> <leader>k :call TodoTxtPrioritizeIncrease(line("."), line("."))<ESC>
    nnoremap <script> <silent> <buffer> <leader>л :call TodoTxtPrioritizeIncrease(line("."), line("."))<ESC>
endif

if !hasmapto("<leader>k",'v')
    vnoremap <script> <silent> <buffer> <leader>k :call TodoTxtPrioritizeIncrease(line("'<"), line("'>"))<ESC>
    vnoremap <script> <silent> <buffer> <leader>л :call TodoTxtPrioritizeIncrease(line("'<"), line("'>"))<ESC>
endif

if !hasmapto("<leader>a",'n')
    nnoremap <script> <silent> <buffer> <leader>a :call TodoTxtPrioritizeSet('A')<CR>
    nnoremap <script> <silent> <buffer> <leader>ф :call TodoTxtPrioritizeSet('A')<CR>
endif

if !hasmapto("<leader>a",'v')
    vnoremap <script> <silent> <buffer> <leader>a :call TodoTxtPrioritizeSet('A')<CR>
    vnoremap <script> <silent> <buffer> <leader>ф :call TodoTxtPrioritizeSet('A')<CR>
endif

if !hasmapto("<leader>b",'n')
    nnoremap <script> <silent> <buffer> <leader>b :call TodoTxtPrioritizeSet('B')<CR>
    nnoremap <script> <silent> <buffer> <leader>и :call TodoTxtPrioritizeSet('B')<CR>
endif

if !hasmapto("<leader>b",'v')
    vnoremap <script> <silent> <buffer> <leader>b :call TodoTxtPrioritizeSet('B')<CR>
    vnoremap <script> <silent> <buffer> <leader>и :call TodoTxtPrioritizeSet('B')<CR>
endif

if !hasmapto("<leader>c",'n')
    nnoremap <script> <silent> <buffer> <leader>c :call TodoTxtPrioritizeSet('C')<CR>
    nnoremap <script> <silent> <buffer> <leader>с :call TodoTxtPrioritizeSet('C')<CR>
endif

if !hasmapto("<leader>c",'v')
    vnoremap <script> <silent> <buffer> <leader>c :call TodoTxtPrioritizeSet('C')<CR>
    vnoremap <script> <silent> <buffer> <leader>с :call TodoTxtPrioritizeSet('C')<CR>
endif

" Insert date {{{2
if !hasmapto("date<Tab>",'i')
    inoremap <script> <silent> <buffer> date<Tab> <C-R>=strftime("%Y-%m-%d")<CR>
    inoremap <script> <silent> <buffer> вфеу<Tab> <C-R>=strftime("%Y-%m-%d")<CR>
    inoremap <script> <silent> <buffer> дата<Tab> <C-R>=strftime("%Y-%m-%d")<CR>
endif

if !hasmapto("<leader>d",'n')
    nnoremap <script> <silent> <buffer> <leader>d :call TodoTxtPrependDate()<CR>
    nnoremap <script> <silent> <buffer> <leader>в :call TodoTxtPrependDate()<CR>
endif

if !hasmapto("<leader>d",'v')
    vnoremap <script> <silent> <buffer> <leader>d :call TodoTxtPrependDate()<CR>
    vnoremap <script> <silent> <buffer> <leader>в :call TodoTxtPrependDate()<CR>
endif

" Mark done {{{2
if !hasmapto("<leader>x",'n')
    nnoremap <script> <silent> <buffer> <leader>x :call TodoTxtMarkAsDone()<CR>
    nnoremap <script> <silent> <buffer> <leader>ч :call TodoTxtMarkAsDone()<CR>
endif

if !hasmapto("<leader>x",'v')
    vnoremap <script> <silent> <buffer> <leader>x :call TodoTxtMarkAsDone()<CR>
    vnoremap <script> <silent> <buffer> <leader>ч :call TodoTxtMarkAsDone()<CR>
endif

" Mark cancel {{{2
if !hasmapto("<leader>zz",'n')
    nnoremap <script> <silent> <buffer> <leader>zz :call TodoTxtMarkAsCancelled()<CR>
    nnoremap <script> <silent> <buffer> <leader>яя :call TodoTxtMarkAsCancelled()<CR>
endif

if !hasmapto("<leader>zz",'v')
    vnoremap <script> <silent> <buffer> <leader>zz :call TodoTxtMarkAsCancelled()<CR>
    vnoremap <script> <silent> <buffer> <leader>яя :call TodoTxtMarkAsCancelled()<CR>
endif

" Mark all done {{{2
if !hasmapto("<leader>X",'n')
    nnoremap <script> <silent> <buffer> <leader>X :call TodoTxtMarkAllAsDone()<CR>
    nnoremap <script> <silent> <buffer> <leader>Ч :call TodoTxtMarkAllAsDone()<CR>
endif

" Remove completed {{{2
if !hasmapto("<leader>D",'n')
    nnoremap <script> <silent> <buffer> <leader>D :call TodoTxtRemoveCompleted()<CR>
    nnoremap <script> <silent> <buffer> <leader>В :call TodoTxtRemoveCompleted()<CR>
endif

" Toggle today tasks {{{2
if !hasmapto("<leader>t",'n')
    nnoremap <script> <silent> <buffer> <leader>t :call TodoTxtToggleToday(line("."), line("."))<CR>
    nnoremap <script> <silent> <buffer> <leader>е :call TodoTxtToggleToday(line("."), line("."))<CR>
endif

if !hasmapto("<leader>t",'v')
    vnoremap <script> <silent> <buffer> <leader>t :call TodoTxtToggleToday(line("'<"), line("'>"))<CR>
    vnoremap <script> <silent> <buffer> <leader>е :call TodoTxtToggleToday(line("'<"), line("'>"))<CR>
endif

" Folding {{{1
" Options {{{2

setlocal foldmethod=expr
setlocal foldexpr=TodoFoldLevel(v:lnum)
setlocal foldtext=TodoFoldText()

" TodoFoldLevel(lnum) {{{2
function! TodoFoldLevel(lnum)
    " The match function returns the index of the matching pattern or -1 if
    " the pattern doesn't match. In this case, we always try to match a
    " completed task from the beginning of the line so that the matching
    " function will always return -1 if the pattern doesn't match or 0 if the
    " pattern matches. Incrementing by one the value returned by the matching
    " function we will return 1 for the completed tasks (they will be at the
    " first folding level) while for the other lines 0 will be returned,
    " indicating that they do not fold.
    if TodoTxtGetBaseName() == 'done'
        return 0
    else
        return match(getline(a:lnum),'^[xX]\s.\+$') + 1
    endif
endfunction

" TodoFoldText() {{{2
function! TodoFoldText()
    " The text displayed at the fold is formatted as '+- N Completed tasks'
    " where N is the number of lines folded.
    return '+' . v:folddashes . ' '
                \ . (v:foldend - v:foldstart + 1)
                \ . ' Completed tasks '
endfunction

" Restore context {{{1
let &cpo = s:save_cpo
" Modeline {{{1
" vim: ts=8 sw=4 sts=4 et foldenable foldmethod=marker foldcolumn=1
