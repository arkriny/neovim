local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local insert = n.insert
local exec_lua = n.exec_lua
local eval = n.eval
local feed = n.feed
local command = n.command
local api = n.api
local fn = n.fn
local eq = t.eq

local hl_query_c = [[
  ; query
  (ERROR) @error

  "if" @keyword
  "else" @keyword
  "for" @keyword
  "return" @keyword

  "const" @type
  "static" @type
  "struct" @type
  "enum" @type
  "extern" @type

  ; nonexistent specializer for string should fallback to string
  (string_literal) @string.nonexistent_specializer

  (number_literal) @number
  (char_literal) @string

  (type_identifier) @type
  ((type_identifier) @constant.builtin (#eq? @constant.builtin "LuaRef"))

  (primitive_type) @type
  (sized_type_specifier) @type

  ; Use lua regexes
  ((identifier) @function (#contains? @function "lua_"))
  ((identifier) @Constant (#lua-match? @Constant "^[A-Z_]+$"))
  ((identifier) @Normal (#vim-match? @Normal "^lstate$"))

  ((binary_expression left: (identifier) @warning.left right: (identifier) @warning.right) (#eq? @warning.left @warning.right))

  (comment) @comment
]]

local hl_text_c = [[
/// Schedule Lua callback on main loop's event queue
static int nlua_schedule(lua_State *const lstate)
{
  if (lua_type(lstate, 1) != LUA_TFUNCTION
      || lstate != lstate) {
    lua_pushliteral(lstate, "vim.schedule: expected function");
    return lua_error(lstate);
  }

  LuaRef cb = nlua_ref(lstate, 1);

  multiqueue_put(main_loop.events, nlua_schedule_event,
                 1, (void *)(ptrdiff_t)cb);
  return 0;
}]]


local hl_grid_ts_c = [[
  ^/// Schedule Lua callback on main loop's event queue             |
  static int nlua_schedule(lua_State *const lstate)                |
  {                                                                |
    if (lua_type(lstate, 1) != LUA_TFUNCTION                       |
        || lstate != lstate) {                                     |
      lua_pushliteral(lstate, "vim.schedule: expected function");  |
      return lua_error(lstate);                                    |
    }                                                              |
                                                                   |
    LuaRef cb = nlua_ref(lstate, 1);                               |
                                                                   |
    multiqueue_put(main_loop.events, nlua_schedule_event,          |
                   1, (void *)(ptrdiff_t)cb);                      |
    return 0;                                                      |
  }                                                                |
  {1:~                                                                }|*2
  {MATCH:1?4? m?o?r?e? l?i?n?e?s?.*}|
]]

local test_text_c = [[
void ui_refresh(void)
{
  int width = INT_MAX, height = INT_MAX;
  bool ext_widgets[kUIExtCount];
  for (UIExtension i = 0; (int)i < kUIExtCount; i++) {
    ext_widgets[i] = true;
  }

  bool inclusive = ui_override();
  for (size_t i = 0; i < ui_count; i++) {
    UI *ui = uis[i];
    width = MIN(ui->width, width);
    height = MIN(ui->height, height);
    foo = BAR(ui->bazaar, bazaar);
    for (UIExtension j = 0; (int)j < kUIExtCount; j++) {
      ext_widgets[j] &= (ui->ui_ext[j] || inclusive);
    }
  }
}]]

local injection_text_c = [[
int x = INT_MAX;
#define READ_STRING(x, y) (char *)read_string((x), (size_t)(y))
#define foo void main() { \
              return 42;  \
            }
]]

local injection_grid_c = [[
  int x = INT_MAX;                                                 |
  #define READ_STRING(x, y) (char *)read_string((x), (size_t)(y))  |
  #define foo void main() { \                                      |
                return 42;  \                                      |
              }                                                    |
  ^                                                                 |
  {1:~                                                                }|*11
                                                                   |
]]

local injection_grid_expected_c = [[
  {6:int} x = {26:INT_MAX};                                                 |
  #define {26:READ_STRING}(x, y) ({6:char} *)read_string((x), ({6:size_t})(y))  |
  #define foo {6:void} main() { \                                      |
                {15:return} {26:42};  \                                      |
              }                                                    |
  ^                                                                 |
  {1:~                                                                }|*11
                                                                   |
]]

describe('treesitter highlighting (nested injections)', function()
  local screen --- @type test.functional.ui.screen

  before_each(function()
    clear()
    screen = Screen.new(80, 7)
  end)

  it('correctly redraws nested injections (GitHub #25252)', function()
    insert [=[
function foo() print("Lua!") end

local lorem = {
    ipsum = {},
    bar = {},
}
vim.cmd([[
    augroup RustLSP
    autocmd CursorHold silent! lua vim.lsp.buf.document_highlight()
    augroup END
]])
    ]=]

    exec_lua(function()
      vim.opt.scrolloff = 0
      vim.bo.filetype = 'lua'
      vim.treesitter.start()
    end)

    -- invalidate the language tree
    feed('ggi--[[<ESC>04x')

    screen:expect({
      grid = [[
        {15:^function} {25:foo}{16:()} {16:print(}{26:"Lua!"}{16:)} {15:end}                                                |
                                                                                        |
        {15:local} {25:lorem} {15:=} {16:{}                                                                 |
            {25:ipsum} {15:=} {16:{},}                                                                 |
            {25:bar} {15:=} {16:{},}                                                                   |
        {16:}}                                                                               |
                                                                                        |
      ]],
    })

    -- spam newline insert/delete to invalidate Lua > Vim > Lua region
    feed('3jo<ESC>ddko<ESC>ddko<ESC>ddko<ESC>ddk0')

    screen:expect({
      grid = [[
        {15:function} {25:foo}{16:()} {16:print(}{26:"Lua!"}{16:)} {15:end}                                                |
                                                                                        |
        {15:local} {25:lorem} {15:=} {16:{}                                                                 |
        ^    {25:ipsum} {15:=} {16:{},}                                                                 |
            {25:bar} {15:=} {16:{},}                                                                   |
        {16:}}                                                                               |
                                                                                        |
      ]],
    })
  end)
end)

describe('treesitter highlighting (markdown)', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 6)
    exec_lua(function()
      vim.bo.filetype = 'markdown'
      vim.treesitter.start()
    end)
  end)

  it('supports hyperlinks', function()
    local url = 'https://example.com'
    insert(string.format('[This link text](%s) is a hyperlink.', url))
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.DarkCyan, url = 'https://example.com' },
      [101] = {
        foreground = Screen.colors.SlateBlue,
        url = 'https://example.com',
        underline = true,
      },
    })
    screen:expect({
      grid = [[
        {100:[This link text](}{101:https://example.com}{100:)} is|
         a hyperlink^.                           |
        {1:~                                       }|*3
                                                |
      ]],
    })
  end)

  local code_block = [[
- $f(0)=\sum_{k=1}^{\infty}\frac{2}{\pi^{2}k^{2}}+\lim_{w \to 0}x$.

```c
printf('Hello World!');
```
    ]]

  it('works with spellchecked and smoothscrolled topline', function()
    insert(code_block)
    command('set spell smoothscroll')
    feed('gg<C-E>')
    screen:add_extra_attr_ids({ [100] = { undercurl = true, special = Screen.colors.Red } })
    screen:expect({
      grid = [[
        {1:<<<}k^{2}}+\{100:lim}_{w \to 0}x$^.             |
                                                |
        {18:```}{15:c}                                    |
        {25:printf}{16:(}{26:'Hello World!'}{16:);}                 |
        {18:```}                                     |
                                                |
      ]],
    })
  end)

  it('works with concealed lines', function()
    insert(code_block)
    screen:expect({
      grid = [[
                                                |
        {18:```}{15:c}                                    |
        {25:printf}{16:(}{26:'Hello World!'}{16:);}                 |
        {18:```}                                     |
        ^                                        |
                                                |
      ]],
    })
    feed('ggj')
    command('set number conceallevel=3')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }^                                    |
        {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
        {8:  6 }                                    |
                                                |
      ]],
    })
    feed('j')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }                                    |
        {8:  3 }{18:^```}{15:c}                                |
        {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
                                                |
      ]],
    })
    feed('j')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }                                    |
        {8:  4 }{25:^printf}{16:(}{26:'Hello World!'}{16:);}             |
        {8:  6 }                                    |
                                                |
      ]],
    })
    feed('j')
    screen:expect({
      grid = [[
        {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
        {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
        {8:  2 }                                    |
        {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
        {8:  5 }{18:^```}                                 |
                                                |
      ]],
    })
    -- Concealed lines highlight until changed botline
    screen:try_resize(screen._width, 16)
    feed('y3k30P:<Esc><C-F><C-B>')
    screen:expect([[
      {8:  1 }{16:- }$f(0)=\sum_{k=1}^{\infty}\frac{2}{|
      {8:    }\pi^{2}k^{2}}+\lim_{w \to 0}x$.     |
      {8:  2 }                                    |
      {8:  4 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:  6 }                                    |
      {8:  8 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 10 }                                    |
      {8: 12 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 14 }                                    |
      {8: 16 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 18 }                                    |
      {8: 20 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 22 }                                    |
      {8: 24 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 25 }{18:^```}                                 |
                                              |
    ]])
    feed('G')
    screen:expect([[
      {8: 98 }                                    |
      {8:100 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:102 }                                    |
      {8:104 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:106 }                                    |
      {8:108 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:110 }                                    |
      {8:112 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:114 }                                    |
      {8:116 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:118 }                                    |
      {8:120 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:122 }                                    |
      {8:124 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:126 }^                                    |
                                              |
    ]])
    feed('ggdj')
    command('set concealcursor=n')
    screen:expect([[
      {8:  2 }{25:^printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:  4 }                                    |
      {8:  6 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8:  8 }                                    |
      {8: 10 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 12 }                                    |
      {8: 14 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 16 }                                    |
      {8: 18 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 20 }                                    |
      {8: 22 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 24 }                                    |
      {8: 26 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
      {8: 28 }                                    |
      {8: 30 }{25:printf}{16:(}{26:'Hello World!'}{16:);}             |
                                              |
    ]])
    exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
      assert(vim.api.nvim_win_text_height(0, {}).all == 1, 'line concealed')
    end)
  end)
end)

it('no nil index for missing highlight query', function()
  clear()
  local cqueries = t.paths.test_source_path .. '/runtime/queries/c/'
  os.rename(cqueries .. 'highlights.scm', cqueries .. '_highlights.scm')
  finally(function()
    os.rename(cqueries .. '_highlights.scm', cqueries .. 'highlights.scm')
  end)
  exec_lua([[
    local parser = vim.treesitter.get_parser(0, 'c')
    vim.treesitter.highlighter.new(parser)
  ]])
end)

it('spell navigation correctly wraps back to the first line (Row 0) #36970', function()
  clear()
  insert([[
mispelledone
mispelledtwo]])

  command('set spell')
  command('set wrapscan')
  exec_lua(function()
    vim.treesitter.start(0, 'markdown')
  end)

  api.nvim_win_set_cursor(0, { 2, 0 })

  feed(']s')

  local pos = api.nvim_win_get_cursor(0)
  eq(1, pos[1], 'Should have wrapped back to Line 1')
end)
