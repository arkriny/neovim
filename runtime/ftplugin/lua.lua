-- use treesitter over syntax

vim.bo.includeexpr = [[v:lua.require'vim._ftplugin.lua'.includeexpr(v:fname)]]
vim.bo.omnifunc = 'v:lua.vim.lua_omnifunc'

vim.b.undo_ftplugin = (vim.b.undo_ftplugin or '')
  .. '\n setl omnifunc< foldexpr< includeexpr<'
