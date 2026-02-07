return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  dependencies = {
    "RRethy/nvim-treesitter-endwise",
  },
  config = function()
    require("nvim-treesitter").setup({
      ensure_installed = {
        "ruby", "javascript", "typescript", "tsx",
        "lua", "html", "css", "json", "yaml",
        "markdown", "bash", "vim", "vimdoc",
        "embedded_template",
      },
    })
  end,
}
