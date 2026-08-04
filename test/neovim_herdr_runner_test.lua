local config_root = vim.fn.getcwd() .. "/neovim/.config/nvim"
package.path = table.concat({
  config_root .. "/lua/?.lua",
  config_root .. "/lua/?/init.lua",
  package.path,
}, ";")

local function assert_equal(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error(string.format(
      "%s\nexpected: %s\nactual:   %s",
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

vim.env.HERDR_ENV = "1"
vim.env.HERDR_PANE_ID = "wA:p1"
vim.env.HERDR_TAB_ID = "wA:t1"
vim.env.TMUX = nil

local calls = {}

vim.system = function(args)
  table.insert(calls, vim.deepcopy(args))

  local responses = {
    ["pane list"] = vim.json.encode({
      result = {
        panes = {
          { pane_id = "wA:p1", tab_id = "wA:t1" },
          { pane_id = "wA:p4", tab_id = "wA:t1", cwd = "/tmp/runner" },
          { pane_id = "wA:p7", tab_id = "wA:t3" },
        },
      },
    }),
    ["pane get wA:p4"] = vim.json.encode({
      result = {
        pane = {
          pane_id = "wA:p4",
          tab_id = "wA:t1",
        },
      },
    }),
    ["pane send-keys wA:p4 ctrl+u ctrl+l"] = '{"result":{}}',
    ["pane run wA:p4 bundle exec rspec spec/models/user_spec.rb:42"] = '{"result":{}}',
    ["pane run wA:p4 rubocop"] = '{"result":{}}',
  }

  return {
    wait = function()
      local command = table.concat(vim.list_slice(args, 2), " ")
      local stdout = responses[command]
      if stdout then
        return { code = 0, stdout = stdout, stderr = "" }
      end

      return { code = 1, stdout = "", stderr = "unexpected command: " .. command }
    end,
  }
end

local runner = require("config.multiplexer_runner")

assert_equal(true, runner.is_herdr(), "detects a Neovim process running directly in Herdr")

runner.setup()
assert_equal(2, vim.fn.exists(":VtrAttachToPane"), "defines the familiar VTR attach command in Herdr")
assert_equal(2, vim.fn.exists(":VtrSendCommandToRunner"), "defines the familiar VTR send command in Herdr")
runner.setup()

vim.cmd("VtrAttachToPane wA:p4")
assert_equal("wA:p4", runner.target(), "remembers the selected pane")

vim.cmd("VtrSendCommandToRunner bundle exec rspec spec/models/user_spec.rb:42")

vim.cmd("VtrAttachToPane")
assert_equal("wA:p4", runner.target(), "automatically attaches when the current tab has one other pane")

vim.cmd("VtrUnsetRunnerPane")
vim.cmd("VtrSendCommandToRunner! rubocop")
assert_equal("wA:p4", runner.target(), "the bang command attaches before sending when needed")
assert_equal({
  { "herdr", "pane", "get", "wA:p4" },
  { "herdr", "pane", "send-keys", "wA:p4", "ctrl+u", "ctrl+l" },
  { "herdr", "pane", "run", "wA:p4", "bundle exec rspec spec/models/user_spec.rb:42" },
  { "herdr", "pane", "list" },
  { "herdr", "pane", "get", "wA:p4" },
  { "herdr", "pane", "list" },
  { "herdr", "pane", "get", "wA:p4" },
  { "herdr", "pane", "send-keys", "wA:p4", "ctrl+u", "ctrl+l" },
  { "herdr", "pane", "run", "wA:p4", "rubocop" },
}, calls, "uses Herdr's pane API without coercing its ID to a number")

print("neovim_herdr_runner_test: ok")
