return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    local api = require("nvim-tree.api")

    require("nvim-tree").setup({
      view = { width = 35 },
      filters = { dotfiles = false },
      git = { enable = true },
      on_attach = function(bufnr)
        api.config.mappings.default_on_attach(bufnr)

        local opts = function(desc)
          return {
            desc = "nvim-tree: " .. desc,
            buffer = bufnr,
            noremap = true,
            silent = true,
            nowait = true,
          }
        end

        vim.keymap.set("n", "s", api.node.open.horizontal, opts("Open: Horizontal Split"))
        vim.keymap.set("n", "v", api.node.open.vertical, opts("Open: Vertical Split"))
        vim.keymap.set("n", "t", api.node.open.tab, opts("Open: New Tab"))
      end,
    })
  end,
}
