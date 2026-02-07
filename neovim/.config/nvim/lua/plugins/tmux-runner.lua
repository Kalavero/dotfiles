return {
  "christoomey/vim-tmux-runner",
  config = function()
    if vim.env.TMUX and vim.env.TMUX ~= "" then
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          vim.cmd("VtrAttachToPane")
        end,
      })
    end
  end,
}
