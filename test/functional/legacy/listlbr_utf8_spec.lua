-- Test for linebreak and list option in utf-8 mode

local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local source = n.source
local feed = n.feed
local exec = n.exec
local clear, expect = n.clear, n.expect

describe('linebreak', function()
  before_each(clear)

  -- oldtest: Test_visual_ends_before_showbreak()
  it("Visual area is correct when it ends before multibyte 'showbreak'", function()
    local screen = Screen.new(60, 8)
    exec([[
      let &wrap = v:true
      let &linebreak = v:true
      let &showbreak = '↪ '
      eval ['xxxxx ' .. 'y'->repeat(&columns - 6) .. ' zzzz']->setline(1)
      normal! wvel
    ]])
    screen:expect([[
      xxxxx                                                       |
      {1:↪ }{17:yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy}^ {17:   }|
      {1:↪ }zzzz                                                      |
      {1:~                                                           }|*4
      {5:-- VISUAL --}                                                |
    ]])
  end)
end)
