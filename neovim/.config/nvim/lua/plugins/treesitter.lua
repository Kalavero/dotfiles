return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  dependencies = {
    "RRethy/nvim-treesitter-endwise",
  },
  config = function()
    require("nvim-treesitter").install({
      "ruby", "javascript", "typescript", "tsx",
      "lua", "html", "css", "json", "yaml",
      "markdown", "bash", "vim", "vimdoc",
      "embedded_template",
    })

    -- The main branch has no auto-highlight module; start treesitter per
    -- buffer, silently skipping filetypes without an installed parser.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter_highlight", {}),
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
