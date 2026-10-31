-- Neovim filetype plugin file
-- Language:	Treesitter query

if vim.b.did_ftplugin == 1 then
  return
end

-- Do not set vim.b.did_ftplugin = 1 to allow loading of ftplugin/lisp.vim

vim.opt_local.iskeyword:append('.')

-- it's a lisp!
vim.cmd([[runtime! ftplugin/lisp.vim]])

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '') .. '\n setl iskeyword<'
