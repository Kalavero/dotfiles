return {
  "nvim-telescope/telescope.nvim",
  branch = "master",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({
      defaults = {
        file_ignore_patterns = { "node_modules", ".git/", "vcr_cassettes" },
        path_display = { "truncate" },
      },
      pickers = {
        find_files = {
          find_command = { "rg", "--files", "--hidden", "-g", "!.git" },
        },
      },
    })
    telescope.load_extension("fzf")
  end,
}
