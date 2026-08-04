local config_root = vim.fn.getcwd() .. "/neovim/.config/nvim"
vim.opt.runtimepath:prepend(config_root)

vim.env.HERDR_ENV = "1"
vim.env.HERDR_PANE_ID = "wA:p1"
vim.env.HERDR_TAB_ID = "wA:t1"
vim.env.TMUX = nil

vim.system = function(args)
  return {
    wait = function()
      if vim.deep_equal(args, { "herdr", "pane", "get", "wA:p4" }) then
        return {
          code = 0,
          stdout = vim.json.encode({
            result = {
              pane = {
                pane_id = "wA:p4",
                tab_id = "wA:t1",
              },
            },
          }),
          stderr = "",
        }
      end

      return {
        code = 1,
        stdout = "",
        stderr = "unexpected command: " .. table.concat(args, " "),
      }
    end,
  }
end

package.loaded["config.lazy"] = true
dofile(config_root .. "/init.lua")
vim.cmd("VtrAttachToPane wA:p4")

local runner = require("config.multiplexer_runner")
if runner.target() ~= "wA:p4" then
  error("Neovim did not use the Herdr runner during normal startup")
end

local tmux_runner = dofile(config_root .. "/lua/plugins/tmux-runner.lua")
if tmux_runner.enabled() then
  error("vim-tmux-runner is enabled inside a direct Herdr pane")
end

print("neovim_herdr_config_test: ok")
