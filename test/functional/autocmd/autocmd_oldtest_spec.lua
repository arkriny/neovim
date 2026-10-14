local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local eq = t.eq
local api = n.api
local fn = n.fn
local exec = n.exec
local feed = n.feed

describe('oldtests', function()
  before_each(clear)

  local exec_lines = function(str)
    return fn.split(fn.execute(str), '\n')
  end

  local add_an_autocmd = function()
    exec [[
      augroup vimBarTest
        au BufReadCmd * echo 'hello'
      augroup END
    ]]

    eq(3, #exec_lines('au vimBarTest'))
    eq(1, #api.nvim_get_autocmds({ group = 'vimBarTest' }))
  end

  it('should recognize a bar before the {event}', function()
    -- Good spacing
    add_an_autocmd()
    exec [[ augroup vimBarTest | au! | augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))
    eq({}, api.nvim_get_autocmds({ group = 'vimBarTest' }))

    -- Sad spacing
    add_an_autocmd()
    exec [[ augroup vimBarTest| au!| augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))

    -- test that a bar is recognized after the {event}
    add_an_autocmd()
    exec [[ augroup vimBarTest| au!BufReadCmd| augroup END ]]
    eq(1, #exec_lines('au vimBarTest'))

    add_an_autocmd()
    exec [[ au! vimBarTest|echo 'hello' ]]
    eq(1, #exec_lines('au vimBarTest'))
  end)
end)
