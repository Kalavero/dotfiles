return {
  "thoughtbot/vim-rspec",
  config = function()
    if vim.fn.filereadable("./bin/rspec") == 1 then
      vim.g.rspec_command = "VtrSendCommandToRunner! ./bin/rspec {spec}"
    else
      vim.g.rspec_command = "VtrSendCommandToRunner! rspec {spec}"
    end
  end,
}
