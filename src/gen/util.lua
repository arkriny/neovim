-- TODO(justinmk): move most of this to `vim.text`.

local M = {}

-- Map of api_level:version, by inspection of:
--    :lua= vim.mpack.decode(vim.fn.readfile('test/functional/fixtures/api_level_9.mpack','B')).version
M.version_level = {
  [14] = '0.12.0',
  [13] = '0.11.0',
  [12] = '0.10.0',
  [11] = '0.9.0',
  [10] = '0.8.0',
  [9] = '0.7.0',
  [8] = '0.6.0',
  [7] = '0.5.0',
  [6] = '0.4.0',
  [5] = '0.3.2',
  [4] = '0.3.0',
  [3] = '0.2.1',
  [2] = '0.2.0',
  [1] = '0.1.0',
}

--- @param txt string
--- @param srow integer
---
--- Does not wrap, not important for "meta" files.
---
--- @param text string
--- @param prefix_ string
function M.prefix_lines(prefix_, text)
  local r = ''
  for _, l in ipairs(vim.split(text, '\n', { plain = true })) do
    r = r .. vim.trim(prefix_ .. l) .. '\n'
  end
  return r
end

--- @param x string
--- @param start_indent integer
--- @param indent integer
--- @param text_width integer
--- @return string
function M.wrap(x, start_indent, indent, text_width)
  local words = vim.split(vim.trim(x), '%s+')
  local parts = { string.rep(' ', start_indent) } --- @type string[]
  local count = indent

  for i, w in ipairs(words) do
    if count > indent and count + #w > text_width - 1 then
      parts[#parts + 1] = '\n'
      parts[#parts + 1] = string.rep(' ', indent)
      count = indent
    elseif i ~= 1 then
      parts[#parts + 1] = ' '
      count = count + 1
    end
    count = count + #w
    parts[#parts + 1] = w
  end

  return (table.concat(parts):gsub('%s+\n', '\n'):gsub('\n+$', ''))
end
return M
