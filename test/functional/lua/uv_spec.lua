-- Test suite for testing interactions with API bindings
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local fn = n.fn
local api = n.api
local clear = n.clear
local sleep = vim.uv.sleep
local feed = n.feed
local eq = t.eq
local eval = n.eval
local matches = t.matches
local exec_lua = n.exec_lua
local retry = t.retry

before_each(clear)

describe('vim.uv', function()
  it('version', function()
    assert(fn.luaeval('vim.uv.version()') >= 72961, 'libuv version too old')
    matches('(%d+)%.(%d+)%.(%d+)', fn.luaeval('vim.uv.version_string()'))
  end)

  it('timer', function()
    exec_lua('vim.api.nvim_set_var("coroutine_cnt", 0)', {})

    local code = function()
      local touch = 0
      local function wait(ms)
        local this = coroutine.running()
        assert(this)
        local timer = assert(vim.uv.new_timer())
        timer:start(
          ms,
          0,
          vim.schedule_wrap(function()
            timer:close()
            touch = touch + 1
            coroutine.resume(this)
            touch = touch + 1
            assert(touch == 3)
            vim.api.nvim_set_var('coroutine_cnt_1', touch)
          end)
        )
        coroutine.yield()
        touch = touch + 1
        return touch
      end
      coroutine.wrap(function()
        local touched = wait(10)
        assert(touched == touch)
        vim.api.nvim_set_var('coroutine_cnt', touched)
      end)()
    end

    eq(0, api.nvim_get_var('coroutine_cnt'))
    exec_lua(code)
    retry(2, nil, function()
      sleep(50)
      eq(2, api.nvim_get_var('coroutine_cnt'))
    end)
    eq(3, api.nvim_get_var('coroutine_cnt_1'))
  end)

  it("is equal to require('luv')", function()
    eq(true, exec_lua("return vim.uv == require('luv')"))
  end)

  it('non-string error() #32595', function()
    local screen = Screen.new(50, 10)
    exec_lua(function()
      local timer = assert(vim.uv.new_timer())
      timer:start(0, 0, function()
        timer:close()
        error(nil)
      end)
    end)
    local s = [[
                                                        |
      {1:~                                                 }|*5
      {3:                                                  }|
      {9:Lua callback:}                                     |
      {9:[NULL]}                                            |
      {6:Press ENTER or type command to continue}^           |
    ]]
    screen:expect(s)
    feed('<cr>')
    n.assert_alive()
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*8
                                                        |
    ]])
    exec_lua(function()
      vim.uv.fs_stat('non-existent-file', function()
        error(nil)
      end)
    end)
    screen:expect(s)
    feed('<cr>')
    n.assert_alive()
  end)

  it("doesn't crash on async callbacks throwing nil error", function()
    local screen = Screen.new(50, 4)

    exec_lua(function()
      _G.idle = vim.uv.new_idle()
      _G.idle:start(function()
        _G.idle:stop()
        error()
      end)
    end)

    screen:expect([[
      {3:                                                  }|
      {9:Lua callback:}                                     |
      {9:[NULL]}                                            |
      {6:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')

    exec_lua(function()
      _G.idle:close()
    end)
  end)

  it("doesn't crash on async callbacks throwing object as an error", function()
    local screen = Screen.new(50, 4)

    exec_lua(function()
      _G.idle = vim.uv.new_idle()
      _G.idle:start(function()
        _G.idle:stop()
        error(_G.idle) -- userdata with __tostring method
      end)
    end)

    screen:expect([[
      {3:                                                  }|
      {9:Lua callback:}                                     |
      {9:uv_idle_t: 0x{MATCH:%w+}}{MATCH: +}|
      {6:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')

    exec_lua(function()
      _G.idle:close()
    end)
  end)
end)
