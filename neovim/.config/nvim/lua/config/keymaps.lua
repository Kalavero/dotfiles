local map = vim.keymap.set

-- Switch between the last two files
map("n", "<Leader><Leader>", "<C-^>", { desc = "Switch last two files" })

-- Window splits
map("n", "vv", "<C-w>v", { silent = true, desc = "Vertical split" })
map("n", "ss", "<C-w>s", { silent = true, desc = "Horizontal split" })

-- ERB tags
map("i", "<C-K>", "<%=  %><Esc>2hi", { silent = true, desc = "ERB output tag" })
map("i", "<C-J>", "<%  %><Esc>2hi", { silent = true, desc = "ERB tag" })

-- Tmux navigator (custom mappings, no defaults)
vim.g.tmux_navigator_no_mappings = 1
map("n", "<C-h>", ":TmuxNavigateLeft<CR>", { silent = true })
map("n", "<C-j>", ":TmuxNavigateDown<CR>", { silent = true })
map("n", "<C-k>", ":TmuxNavigateUp<CR>", { silent = true })
map("n", "<C-l>", ":TmuxNavigateRight<CR>", { silent = true })

-- Reload config
map("n", "<Leader>vr", ":source $MYVIMRC<CR>", { silent = true, desc = "Reload config" })

-- Clear search highlight
map("n", "//", ":nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

-- Toggle highlight search
map("n", "<Leader>hl", ":set hlsearch! hlsearch?<CR>", { desc = "Toggle hlsearch" })

-- Telescope (replaces CtrlP)
map("n", "<Leader>t", "<cmd>Telescope find_files<CR>", { silent = true, desc = "Find files" })
map("n", "<Leader>b", "<cmd>Telescope buffers<CR>", { silent = true, desc = "Buffers" })
map("n", "<Leader>m", "<cmd>Telescope oldfiles<CR>", { silent = true, desc = "Recent files" })

-- Grep word under cursor (replaces :Ag <cword>)
map("n", "K", "<cmd>Telescope grep_string<CR>", { silent = true, desc = "Grep word under cursor" })

-- Zoom pane / re-balance
map("n", "<Leader>-", ":wincmd _<CR>:wincmd |<CR>", { silent = true, desc = "Zoom pane" })
map("n", "<Leader>=", ":wincmd =<CR>", { silent = true, desc = "Re-balance splits" })

-- Tabs
map("n", "<S-Tab>", "gt", { desc = "Next tab" })
map("n", "<S-t>", ":tabnew<CR>", { silent = true, desc = "New tab" })

-- Clipboard (system)
map("n", "<Leader>y", '"+y', { desc = "Yank to clipboard" })
map("n", "<Leader>p", '"+p', { desc = "Paste from clipboard" })

-- nvim-tree (replaces NERDTree)
map("n", "<C-\\>", "<cmd>NvimTreeToggle<CR>", { silent = true, desc = "Toggle file tree" })

-- vim-rspec mappings
map("n", "<Leader>rs", ":call RunCurrentSpecFile()<CR>", { desc = "Run current spec" })
map("n", "<Leader>rn", ":call RunNearestSpec()<CR>", { desc = "Run nearest spec" })
map("n", "<Leader>rl", ":call RunLastSpec()<CR>", { desc = "Run last spec" })
map("n", "<Leader>ra", ":call RunAllSpecs()<CR>", { desc = "Run all specs" })

-- Rubocop via VTR
map("n", "<Leader>ru", ":call VtrSendCommand('rubocop')<CR>", { desc = "Rubocop dir" })
map("n", "<Leader>rfu", function()
  vim.cmd("call VtrSendCommand('rubocop ' . expand('%'))")
end, { desc = "Rubocop file" })

-- Flog via VTR
map("n", "<Leader>fl", function()
  vim.cmd("call VtrSendCommand('flog ' . expand('%'))")
end, { desc = "Flog file" })

-- Ctags
map("n", "<Leader>ct", ":!ctags -R .<CR>", { desc = "Generate ctags" })

-- Git Status (fugitive)
map("n", "<Leader>gs", ":Git<CR>", { desc = "Git status" })

-- Smart tab completion
vim.cmd([[
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
    else
        return "\<c-p>"
    endif
endfunction
inoremap <Tab> <c-r>=InsertTabWrapper()<cr>
inoremap <S-Tab> <c-n>
]])
