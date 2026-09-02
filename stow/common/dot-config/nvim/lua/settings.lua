local common = require "common"

-- Add luarocks to rtp
local home = vim.uv.os_homedir()
package.path = package.path .. ";" .. home .. "/.luarocks/share/lua/5.1/?/init.lua;"
package.path = package.path .. ";" .. home .. "/.luarocks/share/lua/5.1/?.lua;"

-- Line Numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Indent Settings
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = false

-- Highlight line number without higlighting the whole line
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"

-- Miscellaneous
vim.opt.wrap = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 4
vim.opt.termguicolors = true
vim.opt.laststatus = 3 -- global statusline
vim.o.updatetime = 200 -- CursorHold time default is 4s. Way too long
vim.opt.showcmd = false -- prevent flickering if j/k is being held
vim.opt.title = true -- turn on for tmux and terminal apps tab title
vim.o.splitright = true
vim.o.exrc = true -- search local directory for .nvim.lua config

-- Clipboard
vim.opt.clipboard:append("unnamedplus")

if not vscode then
  local function copy(register)
    if not TMUX then
      return require('vim.ui.clipboard.osc52').copy(register)
    else
      return {"tmux", "load-buffer", "-w", "-"}
    end
    -- return function(lines) vim.fn.setreg("+", lines) end
  end
  local function paste(register)
    if not TMUX then
      return require('vim.ui.clipboard.osc52').paste(register)
    else
      return { 'bash', '-c', 'tmux refresh-client -l && sleep 0.05 && tmux save-buffer -' }
    end
    -- return { vim.fn.split(vim.fn.getreg("+"), "\n"), vim.fn.getregtype("+") }
  end

  vim.g.clipboard = {
    name = 'OSC 52 with tmux',
    copy = {
      ['+'] = copy('+'),
      ['*'] = copy('*'),
    },
    paste = {
      ['+'] = paste('+'),
      ['*'] = paste('*'),
    }
  }
end

-- don't continue comment on newline
vim.cmd("autocmd BufEnter * setlocal formatoptions-=cro")

vim.g.mapleader = " "

-- nicer markings
vim.opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  diff = "╱",
}

vim.opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }

vim.opt.spelllang = 'en_us'

local function augroup(name)
  return vim.api.nvim_create_augroup("jorbik_" .. name, { clear = true })
end

-- Restore cursor position on buffer read
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("restore_cursor"),
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" or vim.tbl_contains({ "gitcommit", "gitrebase", "hgcommit", "svn" }, vim.bo[args.buf].filetype) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

local function auto_change_cwd()
  local starting_args = vim.fn.argv()

  -- Check if there is exactly one argument and it is a directory
  if #starting_args == 1 then
    local dir = starting_args[1]
    if vim.fn.isdirectory(dir) == 1 then
      local ok, err = pcall(vim.api.nvim_set_current_dir, dir)
      if not ok then
        vim.api.nvim_err_writeln("Failed to change directory to: " .. dir .. "\nError: " .. err)
      end
    end
  end
end
auto_change_cwd()

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})
-- resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})
-- file associations
vim.cmd([[
  augroup FileAssociations
    autocmd!
    autocmd BufRead,BufNewFile *.launch set filetype=xml
  augroup end
]])
vim.cmd([[
  augroup FileAssociations
    autocmd!
    autocmd BufRead,BufNewFile *.envrc set filetype=sh
  augroup end
]])

-- improve file reloads
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
-- vim.api.nvim_create_autocmd("FocusGained", {
  desc = "Reload files from disk when we focus vim",
  pattern = "*",
  group = augroup("checktime_focus"),
  command = "if getcmdwintype() == '' | checktime | endif",
})
vim.api.nvim_create_autocmd("BufEnter", {
  desc = "Every time we enter an unmodified buffer, check if it changed on disk",
  pattern = "*",
  group = augroup("checktime_enter"),
  command = "if &buftype == '' && !&modified && expand('%') != '' | exec 'checktime ' . expand('<abuf>') | endif",
})
-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  group = augroup("auto_create_dir"),
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.loop.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

vim.g.diagnostics_separate = false
-- Reserve space for diagnostic icons
if vim.g.diagnostics_separate then
  vim.opt.signcolumn = 'yes:3'
else
  vim.opt.signcolumn = 'yes'
end

-- statuscolumn using snacks.nvim
if vim.fn.has("nvim-0.9.0") == 1 then
  vim.opt.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]
end

-- folding
-- TODO maybe make it a separate module similarly like folke?
-- https://github.com/LazyVim/LazyVim/blob/2fc7697786e72e02db91dd2242d1407f5b80856b/lua/lazyvim/util/ui.lua#L10-L25
function Foldexpr()
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf].ts_folds == nil then
    -- as long as we don't have a filetype, don't bother
    -- checking if treesitter is available (it won't)
    if vim.bo[buf].filetype == "" then
      return "0"
    end
    if vim.bo[buf].filetype:find("dashboard") then
      vim.b[buf].ts_folds = false
    else
      vim.b[buf].ts_folds = pcall(vim.treesitter.get_parser, buf)
    end
  end
  return vim.b[buf].ts_folds and vim.treesitter.foldexpr() or "0"
end

-- use tree-sitter for folding. If needed to use normal folding, run :set foldmethod=syntax
vim.opt.foldmethod = "expr"
if vim.fn.has("nvim-0.10") == 1 then
  vim.opt.foldexpr = "v:lua.Foldexpr()"
else
  vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
end
vim.opt.foldlevelstart = 99 -- don't fold by default
-- end folding
