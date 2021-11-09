let g:term_id = 0
let g:pre_import = [
            \ 'import numpy as np',
            \ ''
            \ ]
let g:ipython_launch_cmd = [
            \ 'ipython',
            \ '--no-confirm-exit',
            \ '--colors=Linux',
            \ '--no-autoindent',
            \ '--no-banner',
            \ ]


let s:buf_id = 0
let s:is_debug_mode = 0

let s:tab_id_2_tarm_info = {}

function! easyterm#enable() abort
    command! EasyTerm call easyterm#new()
    command! EasyTermRun call easyterm#run_file()
    command! EasyTermDebug call easyterm#debug_mode()
    command! EasyTermCword call easyterm#cword()
    command! -range EasyTermSendLine call easyterm#send_line(<line1>, <line2>)
    command! -range EasyTermSendSelection call easyterm#send_selection()
endfunction


function! easyterm#disable() abort
    try
        delcommand EasyTerm
        delcommand EasyTermRun
        delcommand EasyTermDebug
        delcommand EasyTermCword
        delcommand EasyTermSendLine
        delcommand EasyTermSendSelection
    catch | endtry
endfunction


function! easyterm#get_term_info_with_tab_id()
    return get(s:tab_id_2_tarm_info, tabpagenr(), {})
endfunction


function! easyterm#add_term_info(term_id)
    let s:tab_id_2_tarm_info[tabpagenr()] = {
                \ 'id': a:term_id, 'last_executed_path': expand("%:p")}
endfunction


function! easyterm#update_term_info(term_info)
    let s:tab_id_2_tarm_info[tabpagenr()] = copy(a:term_info)
endfunction


function! easyterm#delete_term_info(buf_id)
    let l:buf_list_in_page = tabpagebuflist()
    for id in l:buf_list_in_page
        if id == a:buf_id && !empty(get(s:tab_id_2_tarm_info, tabpagenr()))
            call remove(s:tab_id_2_tarm_info, tabpagenr())
            return
        endif
    endfor
endfunction


function! easyterm#ipython_reset()
    call easyterm#send_lines(['%reset'])
    sleep 100m
    call easyterm#send_lines(['y'])
endfunction


function! easyterm#new() abort
    let l:buf_id = bufnr()

    let l:term_info = easyterm#get_term_info_with_tab_id()
    if !empty(l:term_info)
        if l:term_info['last_executed_path'] != expand("%:p")
            let l:term_info['last_executed_path'] = expand("%:p")
            call easyterm#update_term_info(l:term_info)
            call easyterm#ipython_reset()
        endif
        return
    endif

    let l:split = 'vsplit'
    if winwidth(win_getid()) < &columns
        let l:split = 'split'
    endif
    let l:term_id = easyterm#create_ipython(l:split)
    call easyterm#add_term_info(l:term_id)
endfunction


function! easyterm#run_file() abort
    call easyterm#new()
    call easyterm#send_lines([printf("%run %s", expand("%:p"))])
endfunction


function! easyterm#debug_until_cmd()
    let l:cmd = [
            \ printf('b %s:%s', expand("%:p"), line('.')), 
            \ 'c',
            \ printf('cl %s:%s', expand("%:p"), line('.')),
            \ "\<c-l>",
            \ 'l',
            \ ]  

    return l:cmd
endfunction


function! easyterm#debug_mode() abort
    if s:is_debug_mode
        call easyterm#disable_debug_mode()
        call easyterm#send_lines(["\<c-d>", "\<c-l>"])
        let s:is_debug_mode = 0
    else
        call easyterm#new()
        let l:debug_launch_cmd = [printf('%run -d %s', expand('%:p'))]
        let l:cmd = easyterm#debug_until_cmd()
        call extend(l:debug_launch_cmd, l:cmd)
        call easyterm#send_lines(l:debug_launch_cmd)
        call easyterm#enable_debug_mode()
        let s:is_debug_mode = 1
    endif
endfunction


function! easyterm#disable_debug_mode()
    execute "nnoremap <silent> <c-l>"." ".g:debug_map_dict['<c-l>']
    execute "nnoremap <silent> <c-n>"." ".g:debug_map_dict['<c-n>']
    execute "nnoremap <silent> <c-b>"." ".g:debug_map_dict['<c-b>']
    unmap c
    unmap s
    unmap <c-u>
    unmap r
    unmap <c-k>

    echomsg 'ipython debug mode ==> off'
endfunction


function! easyterm#enable_debug_mode()
    let g:debug_map_dict = {}
    let g:debug_map_dict['<c-l>'] = mapcheck('<c-l>', 'n')
    let g:debug_map_dict['<c-n>'] = mapcheck('<c-n>', 'n')
    let g:debug_map_dict['<c-b>'] = mapcheck('<c-b>', 'n')
    nnoremap <silent> <c-l> :call ipython#screen_clear()<cr>
    nnoremap <silent> <c-n> :call easyterm#send_lines(["n"])<cr>
    nnoremap <silent> <c-b> :call easyterm#send_lines([
                                    \ printf('b %s:%s', expand("%:p"), line('.'))])<cr>
    nnoremap <silent> c :call easyterm#send_lines(["c"])<cr>
    nnoremap <silent> s :call easyterm#send_lines(["s"])<cr>
    nnoremap <silent> <c-u> :call easyterm#send_lines([easyterm#debug_until_cmd()])<cr>
    nnoremap <silent> r :call easyterm#send_lines(["return"])<cr>
    nnoremap <silent> <c-k> :call easyterm#send_lines(['p '.expand("<cword>")])<cr>

    echomsg 'ipython debug mode ==> on'
endfunction


function! easyterm#generate_id() abort
    return printf("%s:%s:%s")
endfunction

function! easyterm#cword() abort
    call easyterm#new()
    call easyterm#send_lines([expand("<cword>")])
endfunction


function! easyterm#send_line(...) abort
    let l:lines = getline(a:1, a:2)
    call easyterm#new()
    call easyterm#send_lines(l:lines)
endfunction


function! easyterm#send_lines(lines) abort
    call add(a:lines, '')
    let l:term_info = easyterm#get_term_info_with_tab_id()
    if empty(l:term_info)
        return
    endif
    call chansend(l:term_info['id'], a:lines)
endfunction


function! easyterm#send_selection() abort
    call easyterm#new()
    let [l:lnum1, l:col1] = getpos("'<")[1:2]
    let [l:lnum2, l:col2] = getpos("'>")[1:2]
    if &selection ==# 'exclusive'
    let l:col2 -= 1
    endif
    let l:lines = getline(l:lnum1, l:lnum2)
    let l:lines[-1] = l:lines[-1][:l:col2 - 1]
    let l:lines[0] = l:lines[0][l:col1 - 1:]
    call easyterm#send_lines(l:lines)
endfunction


function! easyterm#load_module() abort
    let l:buffer = getline(0, '$')

    let l:module_lines = []
    for line in l:buffer
        let l:matched_str = matchstr(line, '^ *import .*$')
        if l:matched_str != ''
            call add(l:module_lines, l:matched_str)
        endif
    endfor

    return add(l:module_lines, '')
endfunction


function! easyterm#create_ipython(split) abort
    let l:imports = easyterm#load_module()

    execute a:split
    enew
    let l:term_id = termopen(&shell)
    " let s:buf_id = bufnr()

    setlocal nonumber norelativenumber signcolumn=auto bufhidden=wipe

    let l:cmd = ["conda activate face", '']
    let l:cmd = extend(l:cmd, [join(g:ipython_launch_cmd, ' ')], 1)
    call chansend(l:term_id, l:cmd)

    call chansend(l:term_id, g:pre_import)
    call chansend(l:term_id, l:imports)
    call chansend(l:term_id, "\<c-l>")
    wincmd p

    return l:term_id
endfunction
