-- set up vscode-neovim helpers
function not_vscode()
  return vim.fn.exists('g:vscode') == 0
end

vscode = vim.fn.exists('g:vscode') ~= 0
TMUX = vim.env.TMUX ~= nil
function TableToString(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. TableToString(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local M = {}

function M.is_SSH()
  if TMUX then
    local handle = io.popen("tmux show-env")
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result:find("SSH_CONNECTION=") then
        return true
      end
      if result:find("-SSH_CONNECTION") then
        return false
      end
    end
  end
  return vim.env.SSH_CONNECTION ~= nil
end

local function is_dev_dir()
  local cwd_parts = vim.split(vim.fn.getcwd(), "/")
  vim.g.debug = cwd_parts

  local patterns = {'^Projects$', '^code$'}
  local num_parts_to_check = 2  -- Change this to check more parts

  for i = 0, num_parts_to_check - 1 do
    local directory = cwd_parts[#cwd_parts - i]
    if directory then
      vim.g.directory_name = directory
      for _, pattern in ipairs(patterns) do
        if directory:match(pattern) then
          return true
        end
      end
    end
  end

  return false
end
M.is_dev_dir = is_dev_dir()

function M.getGitMainBranch()
  local is_git_repo = string.gsub(vim.fn.system('git rev-parse --is-inside-work-tree 2>/dev/null'), "%s+", "")
  if is_git_repo ~= "true" then
    return nil
  end
  local origin_head = vim.fn.systemlist("git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null")[1]
  if vim.v.shell_error == 0 and origin_head and origin_head ~= "" then
    return origin_head:match("origin/(.+)$") or origin_head
  end
  for _, name in ipairs({ "main", "trunk", "master" }) do
    vim.fn.system("git show-ref --verify --quiet refs/heads/" .. name)
    if vim.v.shell_error == 0 then
      return name
    end
  end
  return "main"
end

function M.getVisualSelection()
  vim.cmd('noau normal! "vy"')
  local text = vim.fn.getreg('v')
  vim.fn.setreg('v', {})
  text = string.gsub(text, "\n", "")
  if #text > 0 then
    return text
  else
    return ''
  end
end

function M.escape(text, additional_char)
  if not additional_char then
    additional_char = ''
  end
  return vim.fn.escape(text, '/' .. additional_char)
end

function M.bufferEmpty(buffer)
  return vim.api.nvim_buf_line_count(buffer) == 1 and vim.api.nvim_buf_get_lines(buffer, 0, 1, {true})[1] == ""
end

function M.shallowCopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in pairs(orig) do
      copy[orig_key] = orig_value
    end
  else   -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function M.enableAutoformat()
  vim.b.lsp_zero_enable_autoformat = true
  -- conform.nvim
  vim.b.disable_autoformat = false
end

function M.disableAutoformat()
  vim.b.lsp_zero_enable_autoformat = false
  -- conform.nvim
  vim.b.disable_autoformat = true
end

M.fileExists = function(dir, file_pattern)
  local contains = function(tbl, str)
    for _, v in ipairs(tbl) do
      if v == str then
        return true
      end
    end
    return false
  end
  local scan = require "plenary.scandir"
  local dirs = scan.scan_dir(dir, { depth = 1, search_pattern = file_pattern })
  return contains(dirs, dir .. "/" .. file_pattern)
end

M.getGitRoot = function()
  -- Use the current buffer's path as the starting point for the git search
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir
  local cwd = vim.fn.getcwd()
  -- If the buffer is not associated with a file, return nil
  if current_file == "" then
    current_dir = cwd
  else
    -- Extract the directory from the current file's path
    current_dir = vim.fn.fnamemodify(current_file, ":h")
  end

  -- Find the Git root directory from the current file's path
  local git_root = vim.fn.systemlist("git -C " .. vim.fn.escape(current_dir, " ") .. " rev-parse --show-toplevel")[1]
  if vim.v.shell_error ~= 0 then
    print("Not a git repository. Searching on current working directory")
    return nil
  end
  return git_root
end

local function get_open_cmd(path)
  if vim.fn.has("mac") == 1 then
    return { "open", path }
  elseif vim.fn.executable("xdg-open") == 1 then
    return { "xdg-open", path }
  elseif vim.fn.has("win32") == 1 then
    if vim.fn.executable("rundll32") == 1 then
      return { "rundll32", "url.dll,FileProtocolHandler", path }
    else
      return nil, "rundll32 not found"
    end
  elseif vim.fn.executable("explorer.exe") == 1 then
    return { "explorer.exe", path }
  else
    return nil, "no handler found"
  end
end

M.openWithDefault = function(path)
  local cmd, err = get_open_cmd(path)
  if not cmd then
    vim.notify(string.format("Could not open %s: %s", path, err), vim.log.levels.ERROR)
    return
  end
  local jid = vim.fn.jobstart(cmd, { detach = true })
  assert(jid > 0, "Failed to start job")
end

M.getTableIndex = function(tab, val)
    local index = nil
    for k, v in ipairs (tab) do
        if (v == val) then
          index = k
          break
        end
    end
    return index
end

M.removeTableValue = function(tab, val)
  local idx = M.getTableIndex(tab, val)
  if idx == nil then
      print("Value does not exist")
  else
      table.remove(tab, idx)
  end
end

M.split_string = function(input, delimiter)
  local result = {}
  for part in string.gmatch(input, "([^" .. delimiter .. "]+)") do
    table.insert(result, part)
  end
  return result
end

M.matching_string = function(str, tbl)
  for _, v in ipairs(tbl) do
    if str:find(v, 1, true) then
      return v
    end
  end
  return nil
end

M.theme_extensions = {"onedark", "kanagawa"}
M.default_theme = "onedark"

return M
