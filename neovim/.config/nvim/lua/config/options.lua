local opt = vim.opt

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- General
opt.backspace = "2"
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.history = 1000
opt.ruler = true
opt.showcmd = true
opt.autowrite = true
opt.showmode = true
opt.visualbell = true
opt.errorbells = false
opt.modeline = true
opt.modelines = 5

-- Search
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Display
opt.wrap = false
opt.laststatus = 2
opt.number = true
opt.numberwidth = 5
opt.relativenumber = true
opt.termguicolors = true
opt.background = "dark"

-- Indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.shiftround = true
opt.expandtab = true

-- Text width
opt.textwidth = 80
opt.colorcolumn = "+1"

-- Completion
opt.wildmode = "list:longest,list:full"
opt.wildignore:append({ "*/tmp/*", "*.so", "*.swp", "*.zip", "*.cache" })

-- Whitespace display
opt.list = true
opt.listchars = { tab = "»·", trail = "·", nbsp = "·" }

-- Spell
opt.spellfile = vim.fn.expand("$HOME/.vim-spell.utf-8.add")
opt.complete:append("kspell")
opt.spelllang = "en_us,pt_br"

-- Diff
opt.diffopt = "filler,closeoff,vertical"

-- Splits
opt.splitbelow = true
opt.splitright = true

-- Grep (use ripgrep)
opt.grepprg = "rg --vimgrep --smart-case"
opt.grepformat = "%f:%l:%c:%m"

-- Persistent undo
opt.undofile = true
opt.undodir = vim.fn.expand("$HOME/.config/nvim/undodir")

-- Filetype
vim.cmd("filetype plugin indent on")
