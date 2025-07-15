local common = require("common")

local function map(mode, key, action, opts)
  local options = { noremap = true, silent = false }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, key, action, options)
end

local function toggle(option, silent, values)
  if values then
    if vim.opt_local[option]:get() == values[1] then
      vim.opt_local[option] = values[2]
    else
      vim.opt_local[option] = values[1]
    end
    return print("Set " .. option .. " to " .. vim.opt_local[option]:get(), { title = "Option" })
  end
  vim.opt_local[option] = not vim.opt_local[option]:get()
  if not silent then
    if vim.opt_local[option]:get() then
      print("Enabled " .. option, { title = "Option" })
    else
      print("Disabled " .. option, { title = "Option" })
    end
  end
end

vim.g.mapleader = " "
map("n", "<leader>X", "<cmd>!chmod +x %<CR>", { silent = true })
map("n", "<leader>bq", "<cmd>bp <BAR> bd #<CR>", { desc = "Close buffer"})
map({"n", "v"}, "<leader>d", [["_d]])
map({"n", "v"}, "<leader>D", [["_D]])
map({"n", "v"}, "<leader>c", [["_c]])
map({"n", "v"}, "<leader>C", [["_C]])
map("n", "<leader>aq", "<cmd>tabclose<cr>", { desc = "t[a]b [q] close" })
map("n", "<leader>ac", "<cmd>tabnew<CR>", { desc = "t[a]b [c]reate"})
map("n", "<leader>an", "<cmd>tabnew<CR>", { desc = "t[a]b [n]ew"})
map("n", "yr", "<cmd>let @+ = expand('%:~:.')<cr><cmd>lua vim.notify('Yanked relative path')<cr>", { desc = "Copy relative path", silent = true })
map("n", "yp", "<cmd>let @+ = expand('%:p')<cr><cmd>lua vim.notify('Yanked full path')<cr>", { desc = "Copy full path", silent = true })
map("n", "<leader>tf", function()
  if vim.b.orbik_disable_autoformat then
    common.enableAutoformat()
    vim.b.orbik_disable_autoformat = false
    vim.notify("Autoformat enabled for the buffer", vim.log.levels.INFO)
  else
    common.disableAutoformat()
    vim.b.orbik_disable_autoformat = true
    vim.notify("Autoformat disabled for the buffer", vim.log.levels.INFO)
  end
end, { desc = "[t]oggle auto[f]ormat" })
map("n", "<leader>tm", function()
  if vim.o.mouse == "nvi" then
    vim.opt.mouse = ""
    vim.notify("Vim mouse disabled", vim.log.levels.INFO)
  else
    vim.opt.mouse = "nvi"
    vim.notify("Vim mouse enabled", vim.log.levels.INFO)
  end
end, { desc = "[t]oggle [m]ouse" })

-- don't enter command history
map("n", "Q", "<nop>")
map("n", "q:", "<nop>")

-- don't break scrolling. If you need join, use gJ instead
map({"n", "x"}, "J", "j")

-- select last pasted text
map('n', 'gV', '`[v`]')

map("n", "<leader>bn", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })

-- better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- toggle settings
map("n", "<leader>tw", function() toggle("wrap") end, { desc = "[t]oggle word [w]rap" })
map("n", "<leader>to", function() vim.cmd("ASToggle"); require('gitsigns').toggle_current_line_blame() end, { desc = "[t]oggle development [o]ptions" })
if vim.fn.has("nvim-0.9.0") == 1 then
  map("n", "<leader>ti", vim.show_pos, { desc = "Inspect Pos" }) -- highlights under cursor
end

-- quit
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- Save jumps > 5 lines to the jumplist
-- Jumps <= 5 respect line wraps
map("n", "j", [[(v:count > 5 ? "m'" . v:count . 'j' : 'gj')]], { expr = true })
map("n", "k", [[(v:count > 5 ? "m'" . v:count . 'k' : 'gk')]], { expr = true })

local function type_no_escape(text)
  vim.api.nvim_feedkeys(text, "n", false)
end
local function type_escape(text)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, true, true), "n", false)
end

-- replace keymaps
local function replace_keymap(confirmation, visual)
  local text = [[:%s/]]
  local search_string = ''
  if visual then
    search_string = common.getVisualSelection()
  else
    text = text .. [[\<]]
    search_string = vim.fn.expand('<cword>')
  end
  text = text .. common.escape(search_string, '[]')
  if not visual then
    text = text .. [[\>]]
  end
  text = text.. "/" .. common.escape(search_string, '&')
  if confirmation then
    text = text .. [[/gcI]]
  else
    text = text .. [[/gI]]
  end
  type_no_escape(text)

  if not_vscode() then
    local move_text = [[<Left><Left><Left>]]
    if confirmation then
      move_text = move_text .. [[<Left>]]
    end
    type_escape(move_text)
  end
end
map('n', "<leader>r", function() replace_keymap(false, false) end, { desc = 'Find and [r]eplace word under cursor'})
map('n', "<leader>rc", function() replace_keymap(true, false) end, { desc = 'Find and [r]eplace word under cursor with [c]onfirmation'})
map('v', "<leader>r", function() replace_keymap(false, true) end, { desc = 'Find and [r]eplace selected'})
map('v', "<leader>rc", function() replace_keymap(true, true) end, { desc = 'Find and [r]eplace selected with [c]onfirmation'})

-- custom search mappings
map('n', "<leader>/", function()
  type_no_escape("/" .. common.escape(vim.fn.getreg("+")))
  type_escape("<CR>")
end, { desc = "Search for clipboard content"})

-- Makes * and # work in visual mode - comes from https://github.com/stevearc/dotfiles/blob/66f2a389bb0647c0b88ee23d0f264d67b8e8cec3/.config/nvim/init.lua#L287-L295
-- could be improved

map("n", "S", '"_cc')

if not vscode then
  map('i', '<C-c>', "<Esc>")
  -- Move Lines - this messes up VSCode pasting for some reason. Leave it here or find some plugin to do the same better
  map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" })
  map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" })
  map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
  map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })
  map("v", "<A-j>", ":m '>+1<cr>gv=gv", { silent = true, desc = "Move down" })
  map("v", "<A-k>", ":m '<-2<cr>gv=gv", { silent = true, desc = "Move up" })
  map("n", "<leader>V", function() vim.system({"code", vim.fn.getcwd()}, {detach=true, cwd=vim.fn.expand('~')}) end, { desc = "Start VSCode in root folder"})

  -- from https://www.reddit.com/r/neovim/comments/17hjcng/comment/k6nywnx/?utm_source=share&utm_medium=web2x&context=3
  -- Compare clipboard to current buffer
  vim.api.nvim_create_user_command("NewCleanBufferInSplit", function()
    vim.cmd([[
      execute 'vsplit | enew'
      setlocal buftype=nofile
      setlocal bufhidden=hide
      setlocal noswapfile
    ]])
  end, { nargs = 0 })

  vim.api.nvim_create_user_command("CompareClipboard", function()
    local ftype = vim.api.nvim_eval("&filetype") -- original filetype
    vim.cmd([[
      tabnew %
      NewCleanBufferInSplit
      normal! P
      windo diffthis
    ]])
    vim.cmd("set filetype=" .. ftype)
  end, { nargs = 0 })
  vim.keymap.set("n", "<leader>vc", "<cmd>CompareClipboard<cr>", { desc = "Compare clipboard", silent = true })
  -- Compare clipboard to visual selection
  vim.api.nvim_create_user_command("CompareClipboardSelection", function()
    vim.cmd([[
      " yank visual selection to z register
      normal! gv"zy
      " open new tab, set options to prevent save prompt when closing
      execute 'tabnew | setlocal buftype=nofile bufhidden=hide noswapfile'
      " paste z register into new buffer
      normal! V"zp
      NewCleanBufferInSplit
      normal! Vp
      windo diffthis
    ]])
  end, {
    nargs = 0,
    range = true,
  })
  vim.keymap.set("v", "<leader>vc", "<esc><cmd>CompareClipboardSelection<cr>", { desc = "Compare clipboard", silent = true })
  map("i", "<S-Tab>", "<C-d>")
else
  map('n', '<leader>?', "<Cmd>call VSCodeNotify('workbench.action.findInFiles', { 'query': expand('<cword>')})<CR>")
  map('v', '<leader>?', "\"fy<Cmd>call VSCodeNotify('workbench.action.findInFiles', { 'query': eval('@f')})<CR>")
  -- Get folding working with vscode neovim plugin
  map('n', 'zM', ":call VSCodeNotify('editor.foldAll')<CR>")
  map('n', 'zR', ":call VSCodeNotify('editor.unfoldAll')<CR>")
  map('n', 'zc', ":call VSCodeNotify('editor.fold')<CR>")
  map('n', 'zC', ":call VSCodeNotify('editor.foldRecursively')<CR>")
  map('n', 'zo', ":call VSCodeNotify('editor.unfold')<CR>")
  map('n', 'zO', ":call VSCodeNotify('editor.unfoldRecursively')<CR>")
  map('n', 'za', ":call VSCodeNotify('editor.toggleFold')<CR>")
  -- Fix issues with undo https://github.com/vscode-neovim/vscode-neovim/issues/1192
  -- Update: seems fixed for now
  -- map('n', 'u', ":call VSCodeNotify('undo')<CR>")
  -- map('n', '<C-r>', ":call VSCodeNotify('redo')<CR>")
  local function moveCursor(direction)
    if (vim.fn.reg_recording() == '' and vim.fn.reg_executing() == '') then
      return ('g' .. direction)
    else
      return direction
    end
  end
  map({'n', 'x'}, "<leader>ca", ":call VSCodeNotify('editor.action.quickFix')<CR>")
  map({'n', 'x'}, 'go', ":call VSCodeNotify('editor.action.goToTypeDefinition')<CR>")
  map({'n', 'x'}, 'gl', ":call VSCodeNotify('editor.action.showHover')<CR>")
end

-- remove the default mapping set in https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_defaults.lua
-- I use it for substitute
vim.keymap.del('n', 'gri', {})
