return {
  "ellisonleao/gruvbox.nvim",
  priority = 1000,
  config = function()
    require("gruvbox").setup({
      contrast = "", -- "hard" for darker bg, "soft" for lighter bg, "" for original
    })
    vim.cmd.colorscheme("gruvbox")
  end,
}
