return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "ts_ls",
          "eslint",
          "ruby_lsp",
          "lua_ls",
        },
      })

      -- LSP keymaps on attach (Neovim 0.11+ native API)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf, silent = true }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "gh", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<Leader>lr", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<Leader>la", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "<Leader>lf", function()
            vim.lsp.buf.format({ async = true })
          end, opts)
          vim.keymap.set("n", "<Leader>ld", vim.diagnostic.open_float, opts)
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        end,
      })

      -- Configure LSP servers (Neovim 0.11+ vim.lsp.config)
      vim.lsp.config("ts_ls", {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
      })
      vim.lsp.config("eslint", {
        cmd = { "vscode-eslint-language-server", "--stdio" },
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte" },
        root_markers = { "package.json", ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.json", ".git" },
      })
      vim.lsp.config("ruby_lsp", {
        cmd = { "ruby-lsp" },
        filetypes = { "ruby" },
        root_markers = { "Gemfile", ".git" },
      })
      vim.lsp.config("lua_ls", {
        cmd = { "lua-language-server" },
        filetypes = { "lua" },
        root_markers = { ".luarc.json", ".luarc.jsonc", ".stylua.toml", ".git" },
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim" } },
            workspace = { library = vim.api.nvim_get_runtime_file("", true) },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.enable({ "ts_ls", "eslint", "ruby_lsp", "lua_ls" })
    end,
  },
}
