augroup plugin-easyterm
    autocmd!
    autocmd BufEnter *.py call easyterm#enable()
    autocmd TabLeave,WinLeave,BufLeave * call easyterm#disable()
    autocmd BufDelete * call easyterm#delete_term_info(expand("<abuf>"))
augroup END
