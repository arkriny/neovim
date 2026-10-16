--- @alias test.reporter.SummaryStatus 'skipped' | 'failure' | 'error'

--- @class test.reporter.FileElement
--- @field name string
--- @field duration? number

--- @class test.reporter.Options
--- @field verbose boolean
--- @field summary_file string

--- @class test.base_reporter
--- @field new fun(opts: test.reporter.Options): test.base_reporter
--- @field suite_start fun(self: test.base_reporter, repeat_index?: integer, repeat_count?: integer)
--- @field file_start fun(self: test.base_reporter, file: test.reporter.FileElement)
--- @field test_start fun(self: test.base_reporter, name: string)
--- @field test_end fun(self: test.base_reporter, record: test.harness.Record)
--- @field file_end fun(self: test.base_reporter, file: test.reporter.FileElement, test_count: integer)
--- @field suite_end fun(self: test.base_reporter, duration: number, run_summary: test.harness.RunSummary, failure_output?: string)

--- @class test.reporter : test.base_reporter
--- @field opts test.reporter.Options
local M = {}
M.__index = M

--- @param path? string
--- @return file
local function open_summary_file(path)
  if type(path) ~= 'string' or path == '-' then
    return io.stdout
  end

  return (assert(io.open(path, 'w')))
end

--- @param opts test.reporter.Options
--- @return test.reporter
function M.new(opts)
  --- @type test.reporter
  local self = setmetatable({
    opts = opts,
  }, M)

  return self
end

--- @param element? { duration?: number }
--- @return number
local function get_elapsed_time_ms(element)
  if element and element.duration then
    return element.duration * 1000
  end

  return tonumber('nan')
end

--- @private
--- @param status test.harness.ResultStatus
--- @return string
function M:result_text(status)
  if status == 'success' then
    return 'OK\n'
  elseif status == 'pending' then
    return 'SKIP\n'
  elseif status == 'failure' then
    return 'FAIL\n'
  end

  return 'ERR\n'
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @return string
function M:summary_label(status)
  if status == 'skipped' then
    return 'SKIPPED '
  elseif status == 'failure' then
    return 'FAILED  '
  end

  return 'ERROR   '
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @return string
function M:summary_header_noun(status, count)
  if status == 'error' then
    return count == 1 and 'error' or 'errors'
  end

  return count == 1 and 'test' or 'tests'
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @return string
function M:summary_footer_noun(status, count)
  if status == 'skipped' then
    return count == 1 and 'SKIPPED TEST' or 'SKIPPED TESTS'
  elseif status == 'failure' then
    return count == 1 and 'FAILED TEST' or 'FAILED TESTS'
  elseif status == 'error' then
    return count == 1 and 'ERROR' or 'ERRORS'
  end

  return count == 1 and 'TEST' or 'TESTS'
end

--- @param message any
--- @return string
local function stringify_message(message)
  if type(message) == 'string' then
    return message
  elseif message == nil then
    return ''
  end

  return vim.inspect(message)
end

--- @private
--- @param pending test.harness.Record
--- @return boolean
function M:na_check(pending)
  if pending.name and vim.list_contains(vim.split(pending.name, '[ :]'), 'N/A') then
    return true
  end

  if type(pending.message) == 'string' then
    return vim.list_contains(vim.split(pending.message, '[ :]'), 'N/A')
  end

  return false
end

--- @private
--- @param pending test.harness.Record
--- @return string
function M:pending_description(pending)
  local message = stringify_message(pending.message)
  if message == '' then
    return ''
  end

  return table.concat({ message, '\n' })
end

--- @private
--- @param failure test.harness.Record
--- @return string
function M:failure_description(failure)
  local message = stringify_message(failure.message)
  if message == '' then
    message = 'Nil error'
  end

  local parts = { message, '\n' }
  if self.opts.verbose and failure.traceback then
    parts[#parts + 1] = failure.traceback
    parts[#parts + 1] = '\n'
  end

  return table.concat(parts)
end

--- @private
--- @param trace? test.harness.Trace
--- @return string
function M:get_file_line(trace)
  if not trace or not trace.short_src then
    return ''
  end

  local source = vim.fs.normalize(trace.short_src)
  local line = trace.currentline or 0
  return source .. ' @ ' .. line .. ': '
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @param list test.harness.Record[]
--- @param describe fun(self: test.reporter, item: test.harness.Record): string
--- @return string
function M:get_test_list(status, count, list, describe)
  if count == 0 then
    return ''
  end

  local label = self:summary_label(status)
  local parts = {
    ('%s %s %s, listed below:\n'):format(
      label,
      count,
      self:summary_header_noun(status, count)
    ),
  }
  local na_count = 0

  for _, item in ipairs(list) do
    if status == 'skipped' and self:na_check(item) then
      na_count = na_count + 1
    else
      local fullname = self:get_file_line(item.trace) .. item.name
      parts[#parts + 1] = ('%s %s\n'):format(label, fullname)
      parts[#parts + 1] = describe(self, item)
    end
  end

  if na_count > 0 then
    parts[#parts + 1] =
      (('%d N/A %s not shown\n'):format(na_count, na_count == 1 and 'test' or 'tests'))
  end

  return table.concat(parts)
end

--- @private
--- @param status test.reporter.SummaryStatus
--- @param count integer
--- @return string
function M:get_summary(status, count)
  if count == 0 then
    return ''
  end

  return (' %s %s\n'):format(count, self:summary_footer_noun(status, count))
end

--- @private
--- @return string
--- @param summary test.harness.RunSummary
function M:get_summary_string(summary)
  local tests = summary.success_count == 1 and 'test' or 'tests'
  local parts = {
    ('PASSED %s %s.\n'):format(summary.success_count, tests),
    self:get_test_list('skipped', summary.skipped_count, summary.pendings, M.pending_description),
    self:get_test_list('failure', summary.failure_count, summary.failures, M.failure_description),
    self:get_test_list('error', summary.error_count, summary.errors, M.failure_description),
  }

  if (summary.skipped_count + summary.failure_count + summary.error_count) > 0 then
    parts[#parts + 1] = '\n'
  end

  parts[#parts + 1] = self:get_summary('skipped', summary.skipped_count)
  parts[#parts + 1] = self:get_summary('failure', summary.failure_count)
  parts[#parts + 1] = self:get_summary('error', summary.error_count)
  return table.concat(parts)
end

--- @return nil
--- @param repeat_index? integer
--- @param repeat_count? integer
function M:suite_start(repeat_index, repeat_count)
  if repeat_count and repeat_count > 1 and repeat_index then
    io.write(('\nRepeating all tests (run %d of %d) . . .\n\n'):format(repeat_index, repeat_count))
  end
  io.write('-------- Global test environment setup.\n')
  io.flush()
end

--- @param file test.reporter.FileElement
function M:file_start(file)
  io.write(
    ('-------- Running tests from %s\n'):format(
      vim.fs.normalize(file.name)
    )
  )
  io.flush()
end

--- @param name string
function M:test_start(name)
  local desc = ('%s %s'):format(_G._nvim_test_id or '', name)
  io.write(('RUN      %s: '):format(desc))
  io.flush()
end

--- @private
--- @param record { duration?: number }
--- @param text string
function M:write_status(record, text)
  io.write(('%.2f ms %s'):format(get_elapsed_time_ms(record), text))
  io.flush()
end

--- @param record test.harness.Record
function M:test_end(record)
  local text = self:result_text(record.status)
  if record.status == 'failure' or record.status == 'error' then
    text = text .. self:failure_description(record)
  end

  self:write_status(record, text)
end

--- @param file test.reporter.FileElement
--- @param test_count integer
function M:file_end(file, test_count)
  io.write(
    ('-------- %s %s from %s (%.2f ms total)\n\n'):format(
      test_count,
      test_count == 1 and 'test' or 'tests',
      vim.fs.normalize(file.name),
      get_elapsed_time_ms(file)
    )
  )
  io.flush()
end

--- @param duration number
--- @param run_summary test.harness.RunSummary
--- @param failure_output? string
function M:suite_end(duration, run_summary, failure_output)
  local tests = run_summary.test_count == 1 and 'test' or 'tests'
  local files = run_summary.file_count == 1 and 'file' or 'files'

  io.write('-------- Global test environment teardown.\n')
  io.flush()

  local summary_file = open_summary_file(self.opts.summary_file)
  summary_file:write('\n')
  summary_file:write(
    ('======== %s %s from %s test %s ran. (%.2f ms total)\n'):format(
      run_summary.test_count,
      tests,
      run_summary.file_count,
      files,
      duration * 1000
    )
  )
  summary_file:write(self:get_summary_string(run_summary))
  if failure_output then
    summary_file:write(failure_output)
  end
  summary_file:flush()
  if summary_file ~= io.stdout then
    summary_file:close()
  end
end

return M
