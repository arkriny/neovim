local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local tt = require('test.functional.testterm')
local Screen = require('test.functional.ui.screen')

local assert_alive = n.assert_alive
local clear = n.clear
local command = n.command
local feed = n.feed
local eq = t.eq
local fn = n.fn
local api = n.api
local exec = n.exec
local exec_lua = n.exec_lua
local eval = n.eval
local sleep = vim.uv.sleep
local pcall_err = t.pcall_err
local testprg = n.testprg
local expect_exitcode = tt.expect_exitcode

describe('global statusline', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 16)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Magenta1, bold = true },
    }
    command('set laststatus=3')
    command('set ruler')
  end)

  it('works', function()
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    feed('i<CR><CR>')
    screen:expect([[
                                                                  |*2
      ^                                                            |
      {1:~                                                           }|*11
      {3:[No Name] [+]                             3,1            All}|
      {5:-- INSERT --}                                                |
    ]])
  end)

  it('works with splits', function()
    command('vsplit | split | vsplit | vsplit | wincmd l | split | 2wincmd l | split')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('works when switching between values of laststatus', function()
    command('set laststatus=1')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*14
                                                0,0-1         All |
    ]])

    command('set laststatus=3')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    command('vsplit | split | vsplit | vsplit | wincmd l | split | 2wincmd l | split')
    command('set laststatus=2')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }│{2:<-1          All}│{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{3:< 0,0-1          All}|
      {1:~                   }│{1:~               }│{1:~}│                    |
      {2:< 0,0-1          All <-1          All <}│{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {2:[No Name]            0,0-1          All < 0,0-1          All}|
                                                                  |
    ]])

    command('set laststatus=3')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    command('set laststatus=0')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }│{2:<-1          All}│{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{3:< 0,0-1          All}|
      {1:~                   }│{1:~               }│{1:~}│                    |
      {2:< 0,0-1          All <-1          All <}│{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*4
                                                0,0-1         All |
    ]])

    command('set laststatus=3')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('win_move_statusline() can reduce cmdheight to 1', function()
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, -1)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, -1)
    eq(3, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, 1)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, 1)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
  end)

  it('mouse dragging can reduce cmdheight to 1', function()
    command('set mouse=a')
    api.nvim_input_mouse('left', 'press', '', 0, 14, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 13, 10)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 12, 10)
    eq(3, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 13, 10)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 14, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 15, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 14, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
  end)

  it('cmdline row is correct after setting cmdheight #20514', function()
    command('botright split test/functional/fixtures/bigfile.txt')
    api.nvim_set_option_value('cmdheight', 1, {})
    feed('L')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0000;<control>;Cc;0;BN;;;;;N;NULL;;;;                       |
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;           |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      ^0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      {3:test/functional/fixtures/bigfile.txt      7,1            Top}|
                                                                  |
    ]])
    feed('j')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;           |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {3:test/functional/fixtures/bigfile.txt      8,1             0%}|
                                                                  |
    ]])
    api.nvim_set_option_value('showtabline', 2, {})
    screen:expect([[
      {5: }{100:2}{5: t/f/f/bigfile.txt }{2:                                       }|
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {3:test/functional/fixtures/bigfile.txt      8,1             0%}|
                                                                  |
    ]])
    api.nvim_set_option_value('cmdheight', 0, {})
    screen:expect([[
      {5: }{100:2}{5: t/f/f/bigfile.txt }{2:                                       }|
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;           |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {3:test/functional/fixtures/bigfile.txt      8,1             0%}|
    ]])
    api.nvim_set_option_value('cmdheight', 1, {})
    screen:expect([[
      {5: }{100:2}{5: t/f/f/bigfile.txt }{2:                                       }|
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {3:test/functional/fixtures/bigfile.txt      8,1             0%}|
                                                                  |
    ]])
  end)

  it('vertical separator connector is not lost when switching window', function()
    screen:add_extra_attr_ids {
      [101] = { background = tonumber('0x282828') },
      [102] = { bold = true, background = tonumber('0x282828'), foreground = Screen.colors.Blue1 },
    }
    command('hi NormalNC guibg=#282828')
    command('vsplit | wincmd l | split')
    -- Cursor is in top-right. Move to bottom-right.
    feed('<C-w>j')
    -- Verify the ├ connector is present.
    screen:expect([[
      {101:                              }│{101:                             }|
      {102:~                             }│{102:~                            }|*6
      {102:~                             }├─────────────────────────────|
      {102:~                             }│^                             |
      {102:~                             }│{1:~                            }|*5
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
    -- Navigate from bottom-right to left.
    feed('<C-w>h')
    -- The ├ connector must still be present.
    screen:expect([[
      ^                              │{101:                             }|
      {1:~                             }│{102:~                            }|*6
      {1:~                             }├─────────────────────────────|
      {1:~                             }│{101:                             }|
      {1:~                             }│{102:~                            }|*5
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('horizontal separator connector is not lost when switching window', function()
    screen:add_extra_attr_ids {
      [101] = { background = tonumber('0x282828') },
      [102] = { bold = true, background = tonumber('0x282828'), foreground = Screen.colors.Blue1 },
    }
    command('hi NormalNC guibg=#282828')
    command('split | wincmd j | vsplit')
    -- Cursor is in bottom-left. Move to bottom-right.
    feed('<C-w>l')
    -- Verify the ┬ connector is present.
    screen:expect([[
      {101:                                                            }|
      {102:~                                                           }|*6
      ──────────────────────────────┬─────────────────────────────|
      {101:                              }│^                             |
      {102:~                             }│{1:~                            }|*5
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
    -- Navigate from bottom-right to top.
    feed('<C-w>k')
    -- The ┬ connector must still be present.
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*6
      ──────────────────────────────┬─────────────────────────────|
      {101:                              }│{101:                             }|
      {102:~                             }│{102:~                            }|*5
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('horizontal separators unchanged when failing to split-move window', function()
    exec([[
      botright split
      let &winwidth = &columns
      let &winminwidth = &columns
    ]])
    eq('Vim(wincmd):E36: Not enough room', pcall_err(command, 'wincmd L'))
    command('mode')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      ^                                                            |
      {1:~                                                           }|*6
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    -- Shouldn't gain a hsep if the global statusline is turned off.
    command('set laststatus=2')
    eq('Vim(wincmd):E36: Not enough room', pcall_err(command, 'wincmd L'))
    command('mode')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      {2:[No Name]                                 0,0-1          All}|
      ^                                                            |
      {1:~                                                           }|*6
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)
end)

describe('statusline', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(40, 8)
    screen:add_extra_attr_ids {
      [100] = { bold = true, reverse = true, foreground = Screen.colors.Blue },
      [101] = { reverse = true, bold = true, foreground = Screen.colors.SlateBlue },
    }
  end)

  it('does not crash if it has Arabic characters #19447', function()
    api.nvim_set_option_value('statusline', 'غً', {})
    api.nvim_set_option_value('laststatus', 2, {})
    command('redraw!')
    assert_alive()
  end)

  it('is redrawn with :resize from <Cmd> mapping #19629', function()
    exec([[
      set laststatus=2
      nnoremap <Up> <cmd>resize -1<CR>
      nnoremap <Down> <cmd>resize +1<CR>
    ]])
    feed('<Up>')
    screen:expect([[
      ^                                        |
      {1:~                                       }|*4
      {3:[No Name]                               }|
                                              |*2
    ]])
    feed('<Down>')
    screen:expect([[
      ^                                        |
      {1:~                                       }|*5
      {3:[No Name]                               }|
                                              |
    ]])
  end)

  it('does not contain showmcd with showcmdloc=statusline when too narrow', function()
    command('set showcmd')
    command('set showcmdloc=statusline')
    command('1vsplit')
    screen:expect([[
      ^ │                                      |
      {1:~}│{1:~                                     }|*5
      {3:< }{2:[No Name]                             }|
                                              |
    ]])
    feed('1234')
    screen:expect_unchanged()
  end)

  it('does not redraw unnecessarily after K_EVENT', function()
    -- does not redraw on vim.schedule (#17937)
    command([[
      set laststatus=2
      let g:counter = 0
      func Status()
        let g:counter += 1
        lua vim.schedule(function() end)
        return g:counter
      endfunc
      set statusline=%!Status()
    ]])
    sleep(50)
    eq(1, eval('g:counter < 50'), 'g:counter=' .. eval('g:counter'))
    -- also in insert mode
    feed('i')
    sleep(50)
    eq(1, eval('g:counter < 50'), 'g:counter=' .. eval('g:counter'))
    -- does not redraw on timer call (#14303)
    command([[
      let g:counter = 0
      func Timer(timer)
      endfunc
      call timer_start(1, 'Timer', {'repeat': 100})
    ]])
    sleep(50)
    eq(1, eval('g:counter < 50'), 'g:counter=' .. eval('g:counter'))
  end)

  it('is redrawn on various state changes', function()
    -- recording state change #22683
    command('set ls=2 stl=%{repeat(reg_recording(),5)}')
    local s1 = [[
      ^                                        |
      {1:~                                       }|*5
      {3:                                        }|
                                              |
    ]]
    screen:expect(s1)
    feed('qQ')
    screen:expect([[
      ^                                        |
      {1:~                                       }|*5
      {3:QQQQQ                                   }|
      {5:recording @Q}                            |
    ]])
    feed('q')
    screen:expect(s1)

    -- Visual mode change #23932
    command('set ls=2 stl=%{mode(1)}')
    local s2 = [[
      ^                                        |
      {1:~                                       }|*5
      {3:n                                       }|
                                              |
    ]]
    screen:expect(s2)
    feed('v')
    screen:expect([[
      ^                                        |
      {1:~                                       }|*5
      {3:v                                       }|
      {5:-- VISUAL --}                            |
    ]])
    feed('V')
    screen:expect([[
      ^                                        |
      {1:~                                       }|*5
      {3:V                                       }|
      {5:-- VISUAL LINE --}                       |
    ]])
    feed('<C-V>')
    screen:expect([[
      ^                                        |
      {1:~                                       }|*5
      {3:^V                                      }|
      {5:-- VISUAL BLOCK --}                      |
    ]])
    feed('<Esc>')
    screen:expect(s2)

    -- Visual selection other end change #36280
    exec([[
      function! DebugVisualSelection()
        return printf("v %s %s", col("v"), col("."))
      endfunction
      set statusline=%!DebugVisualSelection()
    ]])
    feed('iabc<Esc>v')
    screen:expect([[
      ab^c                                     |
      {1:~                                       }|*5
      {3:v 3 3                                   }|
      {5:-- VISUAL --}                            |
    ]])
    feed('iw')
    screen:expect([[
      {17:ab}^c                                     |
      {1:~                                       }|*5
      {3:v 1 3                                   }|
      {5:-- VISUAL --}                            |
    ]])
  end)

  it('ruler is redrawn in cmdline with redrawstatus #22804', function()
    command([[
      let g:n = 'initial value'
      set ls=1 ru ruf=%{g:n}
      redraw
      let g:n = 'other value'
      redrawstatus
    ]])
    screen:expect([[
      ^                                        |
      {1:~                                       }|*6
                            other value       |
    ]])
  end)

  it('hidden moves ruler to cmdline', function()
    -- Use long ruler to check 'ruler' with 'rulerformat' set has correct width.
    command [[
      set ruler rulerformat=%{winnr()}longlonglong ls=0 winwidth=10
      split
      wincmd b
      vsplit
      wincmd t
      wincmd |
      mode
    ]]
    -- Window 1 is current. It has a statusline, so cmdline should show the
    -- last window's ruler, which has no statusline.
    command '1wincmd w'
    screen:expect([[
      ^                                        |
      {1:~                                       }|*2
      {3:[No Name]                  1longlonglong}|
                          │                   |
      {1:~                   }│{1:~                  }|*2
                            3longlonglong     |
    ]])
    -- Window 2 is current. It has no statusline, so cmdline should show its
    -- ruler instead.
    command '2wincmd w'
    screen:expect([[
                                              |
      {1:~                                       }|*2
      {2:[No Name]                  1longlonglong}|
      ^                    │                   |
      {1:~                   }│{1:~                  }|*2
                            2longlonglong     |
    ]])
    -- Window 3 is current. Cmdline should again show its ruler.
    command '3wincmd w'
    screen:expect([[
                                              |
      {1:~                                       }|*2
      {2:[No Name]                  1longlonglong}|
                          │^                   |
      {1:~                   }│{1:~                  }|*2
                            3longlonglong     |
    ]])
  end)

  it('uses "stl" and "stlnc" fillchars even if they are the same #19803', function()
    command('hi clear StatusLine')
    command('hi clear StatusLineNC')
    command('vsplit')
    screen:expect([[
      ^                    │                   |
      {1:~                   }│{1:~                  }|*5
      [No Name]            [No Name]          |
                                              |
    ]])
  end)

  it('showcmdloc=statusline works with vertical splits', function()
    command('rightbelow vsplit')
    command('set showcmd showcmdloc=statusline')
    feed('1234')
    screen:expect([[
                         │^                    |
      {1:~                  }│{1:~                   }|*5
      {2:[No Name]           }{3:<o Name] 1234       }|
                                              |
    ]])
    feed('<Esc>')
    command('set laststatus=3')
    feed('1234')
    screen:expect([[
                         │^                    |
      {1:~                  }│{1:~                   }|*5
      {3:[No Name]                    1234       }|
                                              |
    ]])
  end)

  it('keymap is shown with vertical splits #27269', function()
    command('setlocal keymap=dvorak')
    command('rightbelow vsplit')
    screen:expect([[
                         │^                    |
      {1:~                  }│{1:~                   }|*5
      {2:[No Name]  <en-dv>  }{3:[No Name]   <en-dv> }|
                                              |
    ]])

    command('set laststatus=3')
    screen:expect([[
                         │^                    |
      {1:~                  }│{1:~                   }|*5
      {3:[No Name]                       <en-dv> }|
                                              |
    ]])
  end)

  it("nested call from nvim_eval_statusline() doesn't overwrite items #32259", function()
    exec_lua('vim.o.laststatus = 2')
    exec_lua([[vim.o.statusline = '%#Special#B:%{nvim_eval_statusline("%f", []).str}']])
    screen:expect([[
      ^                                        |
      {1:~                                       }|*5
      {101:B:[No Name]                             }|
                                              |
    ]])
  end)

  it('truncation inside nested nvim_eval_statusline does not crash #36616', function()
    exec_lua(function()
      function _G.statusline_truncating()
        local win = vim.api.nvim_get_current_win()
        local res = vim.api.nvim_eval_statusline('%f', { winid = win, maxwidth = 5 })
        return res.str
      end
      vim.o.laststatus = 2
      vim.o.statusline = '%#Special#B:%{%v:lua.statusline_truncating()%}'
    end)
    local truncated = exec_lua(function()
      return vim.api.nvim_eval_statusline('%f', { maxwidth = 5 }).str
    end)
    local rendered = exec_lua(function()
      return vim.api.nvim_eval_statusline(
        vim.o.statusline,
        { winid = vim.api.nvim_get_current_win() }
      ).str
    end)
    eq('B:' .. truncated, rendered)
  end)
end)

describe('default statusline', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 16)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Magenta1, bold = true },
      [131] = { foreground = Screen.colors.NvimDarkGreen },
    }
    command('set laststatus=2')
    command('set ruler')
  end)

  it('setting statusline to empty string sets default statusline', function()
    exec_lua("vim.o.statusline = 'asdf'")
    eq('asdf', eval('&statusline'))
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:asdf                                                        }|
                                                                  |
    ]])

    local default_statusline = table.concat({
      '%<',
      '%f %h%w%m%r ',
      "%{% v:lua.require('vim._core.util').term_exitcode() %}",
      '%=',
      "%{% luaeval('(package.loaded[''vim.ui''] and vim.api.nvim_get_current_win() == tonumber(vim.g.actual_curwin or -1) and vim.ui.progress_status()) or '''' ')%}",
      "%{% &showcmdloc == 'statusline' ? '%-10.S ' : '' %}",
      "%{% exists('b:keymap_name') ? '<'..b:keymap_name..'> ' : '' %}",
      "%{% &busy > 0 ? '◐ ' : '' %}",
      "%{% luaeval('(package.loaded[''vim.diagnostic''] and next(vim.diagnostic.count()) and vim.diagnostic.status() .. '' '') or '''' ') %}",
      "%{% &ruler ? ( &rulerformat == '' ? '%-14.(%l,%c%V%) %P' : &rulerformat ) : '' %}",
    })

    exec_lua("vim.o.statusline = ''")
    eq(default_statusline, eval('&statusline'))
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    -- Reset to default (via the correct scope) if there's an error.
    command('setglobal statusline=%{a%}')
    eq(default_statusline, eval('&statusline'))
    eq(default_statusline, eval('&g:statusline'))
    eq('', eval('&l:statusline'))
    command('redrawstatus') -- like Vim, statusline isn't immediately redrawn after an error
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                                 0,0-1          All}|
      {9:E121: Undefined variable: a}                                 |
    ]])
    command('setlocal statusline=%{b%}')
    eq(default_statusline, eval('&statusline'))
    eq(default_statusline, eval('&g:statusline'))
    eq('', eval('&l:statusline'))
    command('redrawstatus') -- like Vim, statusline isn't immediately redrawn after an error
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                                 0,0-1          All}|
      {9:E121: Undefined variable: b}                                 |
    ]])
  end)

  it('shows busy status when buffer is set to be busy', function()
    exec_lua("vim.o.statusline = ''")

    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
    exec_lua('vim.o.busy = 1')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                               ◐ 0,0-1          All}|
                                                                  |
    ]])

    exec_lua('vim.o.busy = 0')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('shows exit code when terminal exits #14986', function()
    exec_lua("vim.o.statusline = ''")
    api.nvim_set_option_value('shell', testprg('shell-test'), {})
    api.nvim_set_option_value('shellcmdflag', 'EXIT', {})
    api.nvim_set_option_value('shellxquote', '', {}) -- win: avoid extra quotes
    command('terminal 9')
    screen:expect({ any = '%[Exit: 9%]' })
    expect_exitcode(9)
  end)

  it('shows and updates progress status', function()
    exec_lua("vim.o.statusline = ''")
    local function get_progress()
      return exec_lua(function()
        local stl_str = vim.ui.progress_status()
        return vim.api.nvim_eval_statusline(stl_str, {}).str
      end)
    end

    eq('', get_progress())
    ---@type integer|string
    local id1 = api.nvim_echo(
      { { 'searching...' } },
      true,
      { kind = 'progress', source = 'tests', title = 'test', status = 'running', percent = 10 }
    )
    eq('10%(1) ', get_progress())

    api.nvim_echo({ { 'searching' } }, true, {
      id = id1,
      kind = 'progress',
      source = 'tests',
      percent = 50,
      status = 'running',
      title = 'terminal(ripgrep)',
    })
    eq('50%(1) ', get_progress())

    api.nvim_echo({ { 'searching...' } }, true, {
      kind = 'progress',
      source = 'tests',
      title = 'second-item',
      status = 'running',
      percent = 20,
    })
    eq('35%(2) ', get_progress())

    api.nvim_echo({ { 'searching' } }, true, {
      id = id1,
      kind = 'progress',
      source = 'tests',
      percent = 100,
      status = 'success',
      title = 'terminal(ripgrep)',
    })
    eq('20%(1) ', get_progress())

    exec('redrawstatus')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {3:[No Name]                          20%(1) 0,0-1          All}|
      {131:terminal(ripgrep)}: {19:100% }searching                           |
    ]])

    -- Progress_status only shown on active window
    exec('split')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*6
      {3:[No Name]                          20%(1) 0,0-1          All}|
                                                                  |
      {1:~                                                           }|*5
      {2:[No Name]                                 0,0-1          All}|
      {131:terminal(ripgrep)}: {19:100% }searching                           |
    ]])

    exec('wincmd w')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*6
      {2:[No Name]                                 0,0-1          All}|
      ^                                                            |
      {1:~                                                           }|*5
      {3:[No Name]                          20%(1) 0,0-1          All}|
      {131:terminal(ripgrep)}: {19:100% }searching                           |
    ]])
  end)
end)

describe("'statusline' in floatwin", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(30, 20)
    screen:add_extra_attr_ids({
      [101] = { foreground = Screen.colors.Magenta1, bold = true },
      [102] = {
        foreground = Screen.colors.Magenta1,
        underline = true,
        background = Screen.colors.LightGray,
        bold = true,
      },
    })
  end)

  it('controlled by ":setlocal statusline" and "style" and "laststatus"', function()
    local buf = api.nvim_create_buf(false, false)
    api.nvim_buf_set_lines(buf, 0, -1, false, { '1', '2', '3', '4' })
    local cfg = {
      relative = 'editor',
      row = 1,
      col = 1,
      height = 4,
      width = 10,
      border = 'single',
    }
    local win = api.nvim_open_win(buf, true, cfg)
    local set_stl = [[setlocal stl=%f\ %m]]
    command('set laststatus=2')
    command(set_stl)
    local has_stl = [[
                                    |
      {1:~}┌──────────┐{1:                 }|
      {1:~}│{4:^1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}│{3:<Name] [+]}│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*10
      {2:[No Name]                     }|
                                    |
    ]]
    screen:expect(has_stl)

    -- setting the style will clear the statusline expression for floating windows
    api.nvim_win_set_config(win, { style = 'minimal' })
    local without_stl = [[
                                    |
      {1:~}┌──────────┐{1:                 }|
      {1:~}│{4:^1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*11
      {2:[No Name]                     }|
                                    |
    ]]
    screen:expect(without_stl)

    -- no statusline is displayed because the statusline option was cleared
    api.nvim_win_set_config(win, cfg)
    screen:expect_unchanged()

    -- displayed after the option is reset
    command(set_stl)
    screen:expect(has_stl)

    -- Show in a new window in a new tab, then return to the previous tab;
    -- remove the statusline of the new window, When re-entering this new tab,
    -- the statusline of the new window is cleared
    command('tabnew')
    local win2 = api.nvim_open_win(buf, false, cfg)
    command(set_stl)
    screen:expect([[
      {24: }{102:2}{24:+ [No Name] }{5: }{101:2}{5:+ [No Name] }{2: }{24:X}|
      ^ ┌──────────┐                 |
      {1:~}│{4:1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*11
      {3:[No Name]                     }|
                                    |
    ]])
    command('tabfirst')
    api.nvim_win_set_config(win2, { style = 'minimal' })
    screen:expect([[
      {5: }{101:2}{5:+ [No Name] }{24: }{102:2}{24:+ [No Name] }{2: }{24:X}|
       ┌──────────┐                 |
      {1:~}│{4:^1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}│{3:<Name] [+]}│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*10
      {2:[No Name]                     }|
                                    |
    ]])
    command('tabnext')
    screen:expect([[
      {24: }{102:2}{24:+ [No Name] }{5: }{101:2}{5:+ [No Name] }{2: }{24:X}|
      ^ ┌──────────┐                 |
      {1:~}│{4:1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*11
      {3:[No Name]                     }|
                                    |
    ]])
    -- clear statusline when laststatus is 3
    command('tabclose | set laststatus=2')
    screen:expect([[
                                    |
      {1:~}┌──────────┐{1:                 }|
      {1:~}│{4:^1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}│{3:<Name] [+]}│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*10
      {2:[No Name]                     }|
                                    |
    ]])
    command('set laststatus=0')
    screen:expect([[
                                    |
      {1:~}┌──────────┐{1:                 }|
      {1:~}│{4:^1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*12
                                    |
    ]])

    command('set laststatus=3')
    screen:expect([[
                                    |
      {1:~}┌──────────┐{1:                 }|
      {1:~}│{4:^1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*11
      {3:[No Name] [+]                 }|
                                    |
    ]])
    api.nvim_buf_set_name(buf, 'stl_test')
    screen:expect([[
                                    |
      {1:~}┌──────────┐{1:                 }|
      {1:~}│{4:^1         }│{1:                 }|
      {1:~}│{4:2         }│{1:                 }|
      {1:~}│{4:3         }│{1:                 }|
      {1:~}│{4:4         }│{1:                 }|
      {1:~}└──────────┘{1:                 }|
      {1:~                             }|*11
      {3:stl_test [+]                  }|
                                    |
    ]])
  end)

  it("clears inherited window-local 'statusline' on creation", function()
    command('set laststatus=2')
    api.nvim_set_option_value('statusline', 'global', {})
    local curwin = api.nvim_get_current_win()
    api.nvim_set_option_value('statusline', 'split-local', { win = curwin })
    api.nvim_open_win(0, true, { relative = 'editor', row = 1, col = 1, height = 2, width = 4 })
    screen:expect([[
                                    |
      {1:~}{4:^    }{1:                         }|
      {1:~}{11:~   }{1:                         }|
      {1:~                             }|*15
      {2:split-local                   }|
                                    |
    ]])
  end)
end)
