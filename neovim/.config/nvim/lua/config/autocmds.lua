local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local vimrc = augroup("vimrcEx", { clear = true })

-- Jump to last cursor position (not for git commits)
autocmd("BufReadPost", {
  group = vimrc,
  callback = function()
    if vim.bo.filetype == "gitcommit" then return end
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- File type detection
autocmd({ "BufRead", "BufNewFile" }, {
  group = vimrc,
  pattern = "Appraisals",
  callback = function() vim.bo.filetype = "ruby" end,
})

-- Markdown: enable spell check and wrap at 80
autocmd("FileType", {
  group = vimrc,
  pattern = "markdown",
  callback = function()
    vim.wo.spell = true
    vim.bo.textwidth = 80
  end,
})

-- Git commit: wrap at 72, enable spell check
autocmd("FileType", {
  group = vimrc,
  pattern = "gitcommit",
  callback = function()
    vim.bo.textwidth = 72
    vim.wo.spell = true
  end,
})

-- CSS/SCSS/Sass: allow hyphenated words in autocomplete
autocmd("FileType", {
  group = vimrc,
  pattern = { "css", "scss", "sass" },
  callback = function()
    vim.opt_local.iskeyword:append("-")
  end,
})

-- Rebalance windows on resize
autocmd("VimResized", {
  callback = function() vim.cmd("wincmd =") end,
})
