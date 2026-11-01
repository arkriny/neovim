local api = vim.api
local fn = vim.fn

local M = {}

--- @alias vim.filetype.mapfn fun(path:string,bufnr:integer, ...):string?, fun(b:integer)?
--- @alias vim.filetype.mapopts { priority: number }
--- @alias vim.filetype.maptbl [string|vim.filetype.mapfn, vim.filetype.mapopts]
--- @alias vim.filetype.mapping.value string|vim.filetype.mapfn|vim.filetype.maptbl
--- @alias vim.filetype.mapping table<string,vim.filetype.mapping.value>

--- @class vim.filetype.mapping.sorted
--- @nodoc
--- @field [1] string parent pattern
--- @field [2] string pattern
--- @field [3] string|vim.filetype.mapfn
--- @field [4] integer priority

--- Get a line range from the buffer.
---@param bufnr integer The buffer to get the lines from
---@param start_lnum integer|nil The line number of the first line (inclusive, 1-based)
---@param end_lnum integer|nil The line number of the last line (inclusive, 1-based)
---@return string[] # Array of lines
function M._getlines(bufnr, start_lnum, end_lnum)
  if not bufnr or bufnr < 0 then
    return {}
  end

  if start_lnum then
    return api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum or start_lnum, false)
  end

  -- Return all lines
  return api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

--- Get a single line from the buffer.
---@param bufnr integer The buffer to get the lines from
---@param start_lnum integer The line number of the first line (inclusive, 1-based)
---@return string
function M._getline(bufnr, start_lnum)
  if not bufnr or bufnr < 0 then
    return ''
  end

  -- Return a single line
  return api.nvim_buf_get_lines(bufnr, start_lnum - 1, start_lnum, false)[1] or ''
end

--- Check whether a string matches any of the given Lua patterns.
---
---@param s string? The string to check
---@param patterns string[] A list of Lua patterns
---@return boolean `true` if s matched a pattern, else `false`
function M._findany(s, patterns)
  if not s then
    return false
  end
  for _, v in ipairs(patterns) do
    if s:find(v) then
      return true
    end
  end
  return false
end

--- Get the next non-whitespace line in the buffer.
---
---@param bufnr integer The buffer to get the line from
---@param start_lnum integer The line number of the first line to start from (inclusive, 1-based)
---@return string|nil line The first non-blank line if found or `nil` otherwise
---@return integer|nil lnum The line number of the first non-blank line or `nil`
function M._nextnonblank(bufnr, start_lnum)
  for off, line in ipairs(M._getlines(bufnr, start_lnum, -1)) do
    if not line:find('^%s*$') then
      return line, start_lnum + off - 1
    end
  end
  return nil, nil
end

do
  --- @type table<string,vim.regex>
  local regex_cache = {}

  --- Check whether the given string matches the Vim regex pattern.
  --- @param s string?
  --- @param pattern string
  --- @return boolean
  function M._matchregex(s, pattern)
    if not s then
      return false
    end
    if not regex_cache[pattern] then
      regex_cache[pattern] = vim.regex(pattern)
    end
    return regex_cache[pattern]:match_str(s) ~= nil
  end
end

-- Filetype detection logic is encoded in three tables:
-- 1. `extension` for literal extension lookup
-- 2. `filename` for literal full path or basename lookup;
-- 3. `pattern` for matching filenames or paths against Lua patterns,
--     optimized for fast lookup.
-- See `:h dev-vimpatch-filetype` for guidance when porting Vim filetype patches.

---@diagnostic disable: unused-local
---@type vim.filetype.mapping
local extension = {}

---@type vim.filetype.mapping
local filename = {}

---@type table<string,vim.filetype.mapping>
local pattern = {}

--- Lookup table/cache for patterns
--- @alias vim.filetype.pattern_cache { has_env: boolean, has_slash: boolean }
--- @type table<string,vim.filetype.pattern_cache>
local pattern_lookup = {}

--- @param a vim.filetype.mapping.sorted
--- @param b vim.filetype.mapping.sorted
local function compare_by_priority(a, b)
  return a[4] > b[4]
end

--- @param pat string
--- @return { has_env: boolean, has_slash: boolean }
local function parse_pattern(pat)
  return { has_env = pat:find('%$%b{}') ~= nil, has_slash = pat:find('/') ~= nil }
end

--- @param t table<string,vim.filetype.mapping>
--- @return vim.filetype.mapping.sorted[]
--- @return vim.filetype.mapping.sorted[]
local function sort_by_priority(t)
  -- Separate patterns with non-negative and negative priority because they
  -- will be processed separately
  local pos = {} --- @type vim.filetype.mapping.sorted[]
  local neg = {} --- @type vim.filetype.mapping.sorted[]
  for parent, ft_map in pairs(t) do
    pattern_lookup[parent] = pattern_lookup[parent] or parse_pattern(parent)
    for pat, maptbl in pairs(ft_map) do
      local ft_or_fun = type(maptbl) == 'table' and maptbl[1] or maptbl
      assert(
        type(ft_or_fun) == 'string' or type(ft_or_fun) == 'function',
        'Expected string or function for filetype'
      )

      -- Parse pattern for common data and cache it once
      pattern_lookup[pat] = pattern_lookup[pat] or parse_pattern(pat)

      --- @type vim.filetype.mapopts?
      local opts = (type(maptbl) == 'table' and type(maptbl[2]) == 'table') and maptbl[2] or nil
      local priority = opts and opts.priority or 0

      table.insert(priority >= 0 and pos or neg, { parent, pat, ft_or_fun, priority })
    end
  end

  table.sort(pos, compare_by_priority)
  table.sort(neg, compare_by_priority)
  return pos, neg
end

local pattern_sorted_pos, pattern_sorted_neg = sort_by_priority(pattern)

--- @param path string
--- @param as_pattern? true
--- @return string
local function normalize_path(path, as_pattern)
  local normal = path:gsub('\\', '/')
  if normal:find('^~') then
    if as_pattern then
      -- Escape Lua's metacharacters when $HOME is used in a pattern.
      -- The rest of path should already be properly escaped.
      normal = vim.pesc(vim.env.HOME) .. normal:sub(2)
    else
      normal = vim.env.HOME .. normal:sub(2) --- @type string
    end
  end
  return normal
end

--- @class vim.filetype.add.filetypes
--- @inlinedoc
--- @field pattern? vim.filetype.mapping
--- @field extension? vim.filetype.mapping
--- @field filename? vim.filetype.mapping

--- Add new filetype mappings.
---
--- Filetype mappings can be added either by extension or by filename (either
--- the "tail" or the full file path). The full file path is checked first,
--- followed by the file name. If a match is not found using the filename, then
--- the filename is matched against the list of |lua-pattern|s (sorted by priority)
--- until a match is found. Lastly, if pattern matching does not find a
--- filetype, then the file extension is used.
---
--- The filetype can be either a string (in which case it is used as the
--- filetype directly) or a function. If a function, it takes the full path and
--- buffer number of the file as arguments (along with captures from the matched
--- pattern, if any) and should return a string that will be used as the
--- buffer's filetype. Optionally, the function can return a second function
--- value which, when called, modifies the state of the buffer. This can be used
--- to, for example, set filetype-specific buffer variables. This function will
--- be called by Nvim before setting the buffer's filetype.
---
--- Filename patterns can specify an optional priority to resolve cases when a
--- file path matches multiple patterns. Higher priorities are matched first.
--- When omitted, the priority defaults to 0.
--- A pattern can contain environment variables of the form "${SOME_VAR}" that will
--- be automatically expanded. If the environment variable is not set, the pattern
--- won't be matched.
---
--- See $VIMRUNTIME/lua/vim/filetype.lua for more examples.
---
--- Example:
---
--- ```lua
--- vim.filetype.add({
---   extension = {
---     foo = 'fooscript',
---     bar = function(path, bufnr)
---       if some_condition() then
---         return 'barscript', function(bufnr)
---           -- Set a buffer variable
---           vim.b[bufnr].barscript_version = 2
---         end
---       end
---       return 'bar'
---     end,
---   },
---   filename = {
---     ['.foorc'] = 'toml',
---     ['/etc/foo/config'] = 'toml',
---   },
---   pattern = {
---     ['.*/etc/foo/.*'] = 'fooscript',
---     -- Using an optional priority
---     ['.*/etc/foo/.*%.conf'] = { 'dosini', { priority = 10 } },
---     -- A pattern containing an environment variable
---     ['${XDG_CONFIG_HOME}/foo/git'] = 'git',
---     ['.*README.(%a+)'] = function(path, bufnr, ext)
---       if ext == 'md' then
---         return 'markdown'
---       elseif ext == 'rst' then
---         return 'rst'
---       end
---     end,
---   },
--- })
--- ```
---
--- To add a fallback match on contents, use
---
--- ```lua
--- vim.filetype.add {
---   pattern = {
---     ['.*'] = {
---       function(path, bufnr)
---         local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
---         if vim.regex([[^#!.*\\<mine\\>]]):match_str(content) ~= nil then
---           return 'mine'
---         elseif vim.regex([[\\<drawing\\>]]):match_str(content) ~= nil then
---           return 'drawing'
---         end
---       end,
---       { priority = -math.huge },
---     },
---   },
--- }
--- ```
---
---@param filetypes vim.filetype.add.filetypes A table containing new filetype maps (see example).
function M.add(filetypes)
  for k, v in pairs(filetypes.extension or {}) do
    extension[k] = v
  end

  for k, v in pairs(filetypes.filename or {}) do
    filename[normalize_path(k)] = v
  end

  for k, v in pairs(filetypes.pattern or {}) do
    -- Add to "match all" parent pattern (might be better to optimize later or document
    -- supplying `opts.parent` directly)
    -- User patterns are assumed to be implicitly anchored (as in Vim)
    pattern['']['^' .. normalize_path(k, true) .. '$'] = v
  end

  if filetypes.pattern then
    -- TODO: full resorting might be expensive with a lot of separate `vim.filetype.add()` calls.
    -- Consider inserting new patterns precisely into already sorted lists of built-in patterns.
    pattern_sorted_pos, pattern_sorted_neg = sort_by_priority(pattern)
  end
end

--- @param ft vim.filetype.mapping.value
--- @param path? string
--- @param bufnr? integer
--- @param ... any
--- @return string?
--- @return fun(b: integer)?
local function dispatch(ft, path, bufnr, ...)
  if type(ft) == 'string' then
    return ft
  end

  if type(ft) ~= 'function' then
    return
  end

  assert(path)

  ---@type string|false?, fun(b: integer)?
  local ft0, on_detect
  if bufnr then
    ft0, on_detect = ft(path, bufnr, ...)
  else
    -- If bufnr is nil (meaning we are matching only against the filename), set it to an invalid
    -- value (-1) and catch any errors from the filetype detection function. If the function tries
    -- to use the buffer then it will fail, but this enables functions which do not need a buffer
    -- to still work.
    local ok
    ok, ft0, on_detect = pcall(ft, path, -1, ...)
    if not ok then
      return
    end
  end

  if not ft0 then
    return
  end

  return ft0, on_detect
end

--- @param pat string
--- @return boolean
--- @return string
local function expand_envvar_pattern(pat)
  local some_env_missing = false
  local expanded = pat:gsub('%${(%S-)}', function(env)
    local val = vim.env[env] --- @type string?
    some_env_missing = some_env_missing or val == nil
    return vim.pesc(val or '')
  end)
  return some_env_missing, expanded
end

--- @param name string
--- @param path string
--- @param tail string
--- @param pat string
--- @param try_all_candidates boolean
--- @return string?
local function match_pattern(name, path, tail, pat, try_all_candidates)
  local pat_cache = pattern_lookup[pat]
  local has_slash = pat_cache.has_slash

  if pat_cache.has_env then
    local some_env_missing, expanded = expand_envvar_pattern(pat)
    -- If any environment variable is present in the pattern but not set, there is no match
    if some_env_missing then
      return nil
    end
    pat = expanded
    has_slash = has_slash or expanded:find('/') ~= nil
  end

  -- Try all possible candidates to make parent patterns not depend on slash presence
  if try_all_candidates then
    return (path:match(pat) or name:match(pat) or tail:match(pat))
  end

  -- If the pattern contains a / match against the full path, otherwise just the tail
  if has_slash then
    -- Similar to |autocmd-pattern|, if the pattern contains a '/' then check for a match against
    -- both the short file name (as typed) and the full file name (after expanding to full path
    -- and resolving symlinks)
    return (name:match(pat) or path:match(pat))
  end

  return (tail:match(pat))
end

--- @param name string
--- @param path string
--- @param tail string
--- @param pattern_sorted vim.filetype.mapping.sorted[]
--- @param parent_matches table<string,boolean>
--- @param bufnr integer?
local function match_pattern_sorted(name, path, tail, pattern_sorted, parent_matches, bufnr)
  for _, p in ipairs(pattern_sorted) do
    local parent, pat, ft_or_fn = p[1], p[2], p[3]

    local parent_is_matched = parent_matches[parent]
    if parent_is_matched == nil then
      parent_matches[parent] = match_pattern(name, path, tail, parent, true) ~= nil
      parent_is_matched = parent_matches[parent]
    end

    if parent_is_matched then
      local matches = match_pattern(name, path, tail, pat, false)
      if matches then
        local ft, on_detect = dispatch(ft_or_fn, path, bufnr, matches)
        if ft then
          return ft, on_detect
        end
      end
    end
  end
end

--- @class vim.filetype.match.args
--- @inlinedoc
---
--- Buffer number to use for matching. Mutually exclusive with {contents}
--- @field buf? integer
---
--- Filename to use for matching. When {buf} is given,
--- defaults to the filename of the given buffer number. The
--- file need not actually exist in the filesystem. When used
--- without {buf} only the name of the file is used for
--- filetype matching. This may result in failure to detect
--- the filetype in cases where the filename alone is not
--- enough to disambiguate the filetype.
--- @field filename? string
---
--- An array of lines representing file contents to use for
--- matching. Can be used with {filename}. Mutually exclusive
--- with {buf}.
--- @field contents? string[]

--- Perform filetype detection.
---
--- The filetype can be detected using one of three methods:
--- 1. Using an existing buffer
--- 2. Using only a file name
--- 3. Using only file contents
---
--- Of these, option 1 provides the most accurate result as it uses both the buffer's filename and
--- (optionally) the buffer contents. Options 2 and 3 can be used without an existing buffer, but
--- may not always provide a match in cases where the filename (or contents) cannot unambiguously
--- determine the filetype.
---
--- Each of the three options is specified using a key to the single argument of this function.
--- Example:
---
--- ```lua
--- -- Using a buffer number
--- vim.filetype.match({ buf = 42 })
---
--- -- Override the filename of the given buffer
--- vim.filetype.match({ buf = 42, filename = 'foo.c' })
---
--- -- Using a filename without a buffer
--- vim.filetype.match({ filename = 'main.lua' })
---
--- -- Using file contents
--- vim.filetype.match({ contents = {'#!/usr/bin/env bash'} })
--- ```
---
---@param args vim.filetype.match.args Table specifying which matching strategy to use.
---                 Accepted keys are:
---@return string|nil   # The matched filetype, if any.
---@return function|nil # A function `fun(buf: integer)` that modifies buffer state when called (for
---                     example, to set some filetype specific buffer variables).
---@return boolean|nil  # true if a match was found by falling back to a generic filetype
---                     (i.e., ".conf"), which indicates the filetype should be set with
---                     `:setf FALLBACK conf`. See |:setfiletype|.
function M.match(args)
  vim.validate('arg', args, 'table')

  if not (args.buf or args.filename or args.contents) then
    error('At least one of "buf", "filename", or "contents" must be given')
  end

  local bufnr = args.buf
  local name = args.filename
  local contents = args.contents

  if bufnr and not name then
    name = api.nvim_buf_get_name(bufnr)
  end

  if name then
    name = normalize_path(name)

    local path = vim.fs.abspath(name)
    do -- First check for the simple case where the full path exists as a key
      local ft, on_detect = dispatch(filename[path], path, bufnr)
      if ft then
        return ft, on_detect
      end
    end

    local tail = vim.fs.basename(name)

    do -- Next check against just the file name
      local ft, on_detect = dispatch(filename[tail], path, bufnr)
      if ft then
        return ft, on_detect
      end
    end

    -- Next, check the file path against available patterns with non-negative priority
    -- Cache match results of all parent patterns to improve performance
    local parent_matches = {}
    do
      local ft, on_detect =
        match_pattern_sorted(name, path, tail, pattern_sorted_pos, parent_matches, bufnr)
      if ft then
        return ft, on_detect
      end
    end

    -- Next, check file extension
    -- Don't use fnamemodify() with :e modifier here,
    -- as that's empty when there is only an extension.
    do
      local ext = name:match('%.([^.]-)$') or ''
      local ft, on_detect = dispatch(extension[ext], path, bufnr)
      if ft then
        return ft, on_detect
      end
    end

    do -- Next, check patterns with negative priority
      local ft, on_detect =
        match_pattern_sorted(name, path, tail, pattern_sorted_neg, parent_matches, bufnr)
      if ft then
        return ft, on_detect
      end
    end
  end

  -- Finally, check file contents
  if contents or bufnr then
    if contents == nil then
      assert(bufnr)
      if api.nvim_buf_line_count(bufnr) > 101 then
        -- only need first 100 and last line for current checks
        contents = M._getlines(bufnr, 1, 100)
        contents[#contents + 1] = M._getline(bufnr, -1)
      else
        contents = M._getlines(bufnr)
      end
    end
  end
end

--- Get the default option value for a {filetype}.
---
--- The returned value is what would be set in a new buffer after 'filetype'
--- is set, meaning it should respect all FileType autocmds and ftplugin files.
---
--- Example:
---
--- ```lua
--- vim.filetype.get_option('vim', 'commentstring')
--- ```
---
--- Note: this uses |nvim_get_option_value()| but caches the result.
--- This means |ftplugin| and |FileType| autocommands are only
--- triggered once and may not reflect later changes.
--- @since 11
--- @param filetype string Filetype
--- @param option string Option name
--- @return string|boolean|integer: Option value
function M.get_option(filetype, option)
  return require('vim.filetype.options').get_option(filetype, option)
end

return M
