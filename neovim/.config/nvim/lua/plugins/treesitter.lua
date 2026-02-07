return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  dependencies = {
    "RRethy/nvim-treesitter-endwise",
  },
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "ruby", "javascript", "typescript", "tsx",
        "lua", "html", "css", "json", "yaml",
        "markdown", "bash", "vim", "vimdoc",
        "embedded_template",
      },
      highlight = { enable = true },
      endwise = { enable = true },
    })
  end,
}
