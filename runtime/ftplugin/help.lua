--- Apply current colorscheme to lists of default highlight groups
---
--- Note: {patterns} is assumed to be sorted by occurrence in the file.
--- @param patterns {start:string,stop:string,match:string}[]
local function colorize_hl_groups(patterns)
  local ns = vim.api.nvim_create_namespace('nvim.vimhelp')
  vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

  local save_cursor = vim.fn.getcurpos()

  for _, pat in pairs(patterns) do
    local start_lnum = vim.fn.search(pat.start, 'c')
    local end_lnum = vim.fn.search(pat.stop)
    if start_lnum == 0 or end_lnum == 0 then
      break
    end

    for lnum = start_lnum, end_lnum do
      local word = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]:match(pat.match)
      if vim.fn.hlexists(word) ~= 0 then
        vim.api.nvim_buf_set_extmark(0, ns, lnum - 1, 0, { end_col = #word, hl_group = word })
      end
    end
  end

  vim.fn.setpos('.', save_cursor)
end

-- Add custom highlights for list in `:h highlight-groups`.
local bufname = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
if vim.endswith(bufname, '/doc/syntax.txt') then
  colorize_hl_groups({
    { start = [[\*group-name\*]], stop = '^======', match = '^(%w+)\t' },
    { start = [[\*highlight-groups\*]], stop = '^======', match = '^(%w+)\t' },
  })
elseif vim.endswith(bufname, '/doc/treesitter.txt') then
  colorize_hl_groups({
    {
      start = [[\*treesitter-highlight-groups\*]],
      stop = [[\*treesitter-highlight-spell\*]],
      match = '^@[%w%p]+',
    },
  })
elseif vim.endswith(bufname, '/doc/diagnostic.txt') then
  colorize_hl_groups({
    { start = [[\*diagnostic-highlights\*]], stop = '^======', match = '^(%w+)' },
  })
elseif vim.endswith(bufname, '/doc/lsp.txt') then
  colorize_hl_groups({
    { start = [[\*lsp-highlight\*]], stop = '^------', match = '^(%w+)' },
    { start = [[\*lsp-semantic-highlight\*]], stop = '^======', match = '^@[%w%p]+' },
  })
end
