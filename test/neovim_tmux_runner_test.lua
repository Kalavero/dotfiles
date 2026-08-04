local config_root = vim.fn.getcwd() .. "/neovim/.config/nvim"
package.path = table.concat({
  config_root .. "/lua/?.lua",
  config_root .. "/lua/?/init.lua",
  package.path,
}, ";")

vim.env.HERDR_ENV = nil
vim.env.HERDR_PANE_ID = nil
vim.env.HERDR_TAB_ID = nil
vim.env.TMUX = "/tmp/tmux-501/default,1,0"

local captured
_G.capture_vtr_command = function(command, ensure_pane)
  captured = { command, ensure_pane }
end

vim.cmd([[
  function! VtrSendCommand(command, ...)
    call v:lua.capture_vtr_command(a:command, get(a:, 1, 0))
  endfunction
]])

local runner = require("config.multiplexer_runner")
if runner.is_herdr() then
  error("a nested tmux session must keep using vim-tmux-runner")
end

local tmux_runner = dofile(config_root .. "/lua/plugins/tmux-runner.lua")
if not tmux_runner.enabled() then
  error("vim-tmux-runner must remain enabled in a nested tmux session")
end

local sent = runner.send("bundle exec rspec", true)
if not sent or not vim.deep_equal(captured, { "bundle exec rspec", 1 }) then
  error("the multiplexer runner did not delegate to vim-tmux-runner")
end

print("neovim_tmux_runner_test: ok")
