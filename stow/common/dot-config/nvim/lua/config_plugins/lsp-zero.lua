local common = require('common')
local lsp_zero = require('lsp-zero')

-- List LSP servers that will be automatically installed upon entering filetype for the first time.
-- LSP servers will be installed locally via mason at: ~/.local/share/nvim/mason/packages/
-- (lspconfig_name => { filetypes } or true)
local auto_filetype_packages = {
  -- @see $VIMPLUG/mason-lspconfig.nvim/lua/mason-lspconfig/mappings/filetype.lua
  -- list of LSP servers -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
  -- list of formatters -- https://github.com/jay-babu/mason-null-ls.nvim/blob/main/lua/mason-null-ls/mappings/filetype.lua
  -- list of DAP mappings -- https://github.com/jay-babu/mason-nvim-dap.nvim/blob/main/lua/mason-nvim-dap/mappings/filetypes.lua
  ['pyright'] = true,
  ['debugpy'] = true,
  ['ruff'] = true,
  ['black'] = true,
  ['lua_ls'] = true,
  ['bashls'] = true,
  ['ts_ls'] = true,
  ['cssls'] = true,
  ['clangd'] = true,
  ['codelldb'] = true, -- cpp debugger
  ['cpptools'] = true, -- cpp debugger
  ['rust_analyzer'] = true,
  ['texlab'] = true,
  ['yamlls'] = true,
  ['jsonlint'] = true,
  ['lemminx'] = true,  -- xml lsp
  ['xmlformatter'] = true,  -- xml formatter
  ['gopls'] = true,
  ['prettierd'] = true,
  ['shellcheck'] = true,
  ['shfmt'] = true,
}

local always_installed = {
  'codespell'
}

--  This function gets run when an LSP connects to a particular buffer.
local lsp_attach = function(client, bufnr)
  lsp_zero.default_keymaps({
    buffer = bufnr,
    exclude = {'gr', '<F3>'},
    preserve_mappings = false,
  })

  local nmap = function(keys, func, desc)
    if desc then
      desc = 'LSP: ' .. desc
    end
    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('gd', "<cmd>Glance definitions<cr>", '[G]oto [d]efinition')
  nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]ecalaration')
  nmap('gi', "<cmd>Glance implementations<cr>", '[G]oto [I]mplementation')
  nmap('gH', "<cmd>Glance references<cr>", 'Goto references')
  nmap('go', "<cmd>Glance type_definitions<cr>", 'Goto type lsp_definitions')
  nmap('<leader>gR', "<cmd>Glance resume<cr>", 'Goto type lsp_definitions')
  nmap('gh', vim.lsp.buf.hover, '[G][H]over documentation')
  nmap('gl', vim.diagnostic.open_float, 'Open diagnostics under cursor')

  nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

  -- Lesser used LSP functionality
  nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
  nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
  nmap('<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, '[W]orkspace [L]ist Folders')

  nmap('[e', '<cmd>lua vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })<CR>')
  nmap(']e', '<cmd>lua vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })<CR>')

  -- Create a command `:Format` local to the LSP buffer
  if vim.fn.has("nvim-0.9.0") == 1 then
    if (client.server_capabilities.semanticTokensProvider and client.server_capabilities.semanticTokensProvider ~= 0) then
      if vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] then vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]:destroy() end
    end
  end
end

lsp_zero.extend_lspconfig({
  capabilities = require('cmp_nvim_lsp').default_capabilities(),
  lsp_attach = lsp_attach,
  float_border = 'rounded',
  sign_text = true,
})

lsp_zero.set_sign_icons({
  error = '',
  warn = '',
  hint = '󰌶',
  info = ''
})

lsp_zero.format_on_save({
  servers = {
    ['clangd'] = {'cpp'},
  }
})

require('mason').setup({})
require('mason-lspconfig').setup({
  handlers = {
    lsp_zero.default_setup,
    lua_ls = function()
      local lua_opts = lsp_zero.nvim_lua_ls()
      require('lspconfig').lua_ls.setup(lua_opts)
    end,
    clangd = function()
      require('lspconfig').clangd.setup({
        on_attach = function(_, bufnr)
          vim.keymap.set('n', '<A-u>', vim.cmd.ClangdSwitchSourceHeader, { buffer = bufnr, desc = "Switch between so[u]rce / header" })
        end,
        cmd = {
          "clangd",
          "--background-index",
          "--header-insertion=never",
          "--offset-encoding=utf-16",
        },
      })
    end,
    pyright = function()
      local function get_python_path(workspace)
        local util = require('lspconfig/util')
        local path = util.path
        -- Use activated virtualenv.
        local virtualenv_env_vars = {vim.env.VIRTUAL_ENV, vim.env.CONDA_DEFAULT_ENV}
        for _, virtualenv_env_var in pairs(virtualenv_env_vars) do
          if virtualenv_env_var then
            local parts = common.split_string(virtualenv_env_var, '/')
            vim.g.virtualenv_name = parts[#parts]
            if #parts > 1 then
              return path.join(virtualenv_env_var, 'bin', 'python')
            else
              return vim.fn.exepath('python3') or vim.fn.exepath('python') or 'python'
            end
          end
        end
        -- trick to check the current directory if workspace is unset
        if workspace == nil then workspace = vim.fn.getcwd() end
        -- Find and use virtualenv in workspace directory.
        for _, pattern in ipairs({'*', '.*'}) do
          local match = vim.fn.glob(path.join(workspace, pattern, 'pyvenv.cfg'))
          if match ~= '' then
            return path.join(path.dirname(match), 'bin', 'python')
          end
        end

        -- Fallback to system Python.
        return vim.fn.exepath('python3') or vim.fn.exepath('python') or 'python'
      end

      -- filtering from https://www.reddit.com/r/neovim/comments/108tjy0/comment/j42cod9/?utm_source=share&utm_medium=web2x&context=3
      local function filter(arr, func)
        -- Filter in place
        -- https://stackoverflow.com/questions/49709998/how-to-filter-a-lua-array-inplace
        local new_index = 1
        local size_orig = #arr
        for old_index, v in ipairs(arr) do
          if func(v, old_index) then
            arr[new_index] = v
            new_index = new_index + 1
          end
        end
        for i = new_index, size_orig do arr[i] = nil end
      end

      local function pyright_accessed_filter(diagnostic)
        -- Allow kwargs to be unused, sometimes you want many functions to take the
        -- same arguments but you don't use all the arguments in all the functions,
        -- so kwargs is used to suck up all the extras
        -- if diagnostic.message == '"kwargs" is not accessed' then
        -- 	return false
        -- end
        --
        -- Allow variables starting with an underscore
        -- if string.match(diagnostic.message, '"_.+" is not accessed') then
        -- 	return false
        -- end


        -- For all messages "is not accessed"
        if string.match(diagnostic.message, '".+" is not accessed') then
          return false
        end

        return true
      end

      local function custom_on_publish_diagnostics(a, params, client_id, c, config)
        filter(params.diagnostics, pyright_accessed_filter)
        vim.lsp.diagnostic.on_publish_diagnostics(a, params, client_id, c, config)
      end

      require('lspconfig').pyright.setup({
        before_init = function(_, config)
          local python_path = get_python_path(config.root_dir)
          config.settings.python.pythonPath = python_path
          vim.g.python_host_prog = python_path
          vim.g.python3_host_prog = python_path
        end,
        on_attach = function(_, _)
          vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
            custom_on_publish_diagnostics, {})
        end,
      })
    end,
    ruff = function()
      require('lspconfig').ruff.setup({
        on_attach = function(client, _)
          -- Disable hover in favor of Pyright
          client.server_capabilities.hoverProvider = false
        end,
        init_options = {
          -- https://github.com/charliermarsh/ruff-lsp#settings
          settings = {
            organizeImports = false,  -- let conform take care of organizeImports
            -- Any extra CLI arguments for `ruff` go here.
            args = {
              "--ignore", table.concat({
                "E501", -- line-too-long
                "E402", -- module-import-not-at-top-of-file
                "E731", -- lambda-assignment
              }, ',')
            },
          }
        }
      })
    end,
    gopls = function()
      require'lspconfig'.gopls.setup{
        on_attach = function(_, _)
          vim.treesitter.start()
        end
      }
    end,
  },
})

local function mergeTablesWithLists(a, b)
    local result = {}

    -- Copy values from table 'a' to the result table
    for key, value in pairs(a) do
        result[key] = value
    end

    -- Merge values from table 'b' into the result table
    for key, value in pairs(b) do
        -- Check if the key already exists in 'a'
        if result[key] ~= nil then
            -- If the key exists in both tables, and both values are tables, merge them as arrays
            if type(result[key]) == "table" and type(value) == "table" then
                -- Concatenate the arrays
                for _, v in ipairs(value) do
                    table.insert(result[key], v)
                end
            else
                result[key] = value -- Override value from 'a' with value from 'b'
            end
        else
            result[key] = value -- Add key-value from 'b' if it doesn't exist in 'a'
        end
    end

    return result
end

-- Install auto_lsp_servers on demand (FileType)
local function ensure_mason_installed()
  local augroup = vim.api.nvim_create_augroup('mason_autoinstall', { clear = true })
  local lspconfig_to_package = require("mason-lspconfig.mappings").get_all().lspconfig_to_package
  local filetype_mappings = require("mason-lspconfig.mappings").get_all().filetypes
  local formatter_filetype_mappings = require("mason-null-ls.mappings.filetype")
  filetype_mappings = mergeTablesWithLists(filetype_mappings, formatter_filetype_mappings)
  local debugger_filetype_mappings_flipped = require("mason-nvim-dap.mappings.filetypes")
  local debugger_filetype_dap_to_pkg = require("mason-nvim-dap.mappings.source").nvim_dap_to_package
  local debugger_filetype_mappings = {}
  for debugger, filetypes in pairs(debugger_filetype_mappings_flipped) do
    -- TODO may need to do the same thing with formatters above
    if debugger_filetype_dap_to_pkg[debugger] ~= nil then
      debugger = debugger_filetype_dap_to_pkg[debugger]
    end
    for _, filetype in pairs(filetypes) do
      if debugger_filetype_mappings[filetype] == nil then
        debugger_filetype_mappings[filetype] = {}
      end
      table.insert(debugger_filetype_mappings[filetype], debugger)
    end
  end
  filetype_mappings = mergeTablesWithLists(filetype_mappings, debugger_filetype_mappings)

  local _requested = {}

  local function installPackage(package_name)
    local lsp_pkg_name = lspconfig_to_package[package_name]
    local mason_package_name = package_name
    if (lsp_pkg_name ~= nil) then
      mason_package_name = lsp_pkg_name
    end
    local ok, pkg = pcall(require("mason-registry").get_package, mason_package_name)
    if ok and not pkg:is_installed() and not _requested[mason_package_name] then
      _requested[mason_package_name] = true
      vim.notify_once(string.format("Installating [%s]...", mason_package_name), vim.log.levels.INFO)
      pkg:install():once("closed", function()
        if pkg:is_installed() then
          vim.schedule(function()
            vim.notify_once(string.format("Installation complete for [%s]", mason_package_name), vim.log.levels.INFO)
            if lsp_pkg_name ~= nil then
              -- is LSP server
              lsp_zero.setup_servers({ package_name })
            end
          end)
        end
      end)
    end
  end

  local ft_handler = {}
  for ft, package_names in pairs(filetype_mappings) do
    package_names = vim.tbl_filter(function(package_name)
      return auto_filetype_packages[package_name] == true or vim.tbl_contains(auto_filetype_packages[package_name] or {}, package_name)
    end, package_names)

    ft_handler[ft] = vim.schedule_wrap(function()
      for _, package_name in pairs(package_names) do
        installPackage(package_name)
      end
    end)

    -- Create FileType handler to auto-install LSPs for the &filetype
    if vim.tbl_count(package_names) > 0 then
      vim.api.nvim_create_autocmd('FileType', {
        pattern = ft,
        group = augroup,
        desc = string.format('Auto-install LSP server: %s (for %s)', table.concat(package_names, ","), ft),
        callback = function() ft_handler[ft]() end,
        once = true,
      })
    end
  end
  for _, package_name in pairs(always_installed) do
    installPackage(package_name)
  end
end

-- refreshes registry if needed and runs command
require("mason-registry").refresh(ensure_mason_installed)

-- miscellaneous

vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  update_in_insert = false,
  underline = true,
  float = {
    border = 'rounded',
  },
})

vim.keymap.set(
  "n",
  "<leader>td",
  function() vim.diagnostic.enable(not vim.diagnostic.is_enabled()) end,
  { desc = "[t]oggle [d]iagnostics" }
)

vim.api.nvim_create_user_command("VirtualTextToggle", function()
	local config = vim.diagnostic.config
	local vt = config().virtual_text
	config {
          virtual_text = not vt,
	}
end, { desc = "[t]oggle [v]irtual text" })
vim.keymap.set("n", "<leader>tv", "<cmd>VirtualTextToggle<CR>", { desc = "[t]oggle [v]irtual text" })

local cmp = require('cmp')
local cmp_action = require('lsp-zero').cmp_action()
require('luasnip.loaders.from_vscode').lazy_load() -- for snippets
require('luasnip.loaders.from_vscode').lazy_load({ paths = { vim.uv.os_homedir() .. "/.config/nvim/snippets" } }) -- for snippets
local has_words_before = function()
  unpack = unpack or table.unpack
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local cmp_mappings = cmp.mapping.preset.insert({
  ['<C-Space>'] = cmp.mapping.complete(),
  ['<CR>'] = cmp.mapping.confirm(),
  ['<Tab>'] = cmp.mapping(
    function(fallback)
      if cmp.visible() and cmp.get_active_entry() then
        -- completion if a cmp item is selected
        cmp.confirm({ select = false, behavior = cmp.ConfirmBehavior.Replace })
      elseif cmp.visible() then
        -- select first item if visible
        cmp.confirm({ select = true, behavior = cmp.ConfirmBehavior.Replace })
      else
        fallback()
      end
    end, {"i","s"}),
  ['<S-Tab>'] = vim.NIL,
  ['<C-d>'] = cmp.mapping.scroll_docs(4),
  ['<C-u>'] = cmp.mapping.scroll_docs(-4),
  -- jump between placeholders
  ['<C-f>'] = cmp_action.luasnip_jump_forward(),
  ['<C-b>'] = cmp_action.luasnip_jump_backward(),
})

-- Custom sorting/ranking for completion items.
local cmp_helper = {}
cmp_helper.compare = {
  ---Deprioritize items starting with underscores (private or protected)
  deprioritize_underscore = function(lhs, rhs)
    local l = (lhs.completion_item.label:find "^_+") and 1 or 0
    local r = (rhs.completion_item.label:find "^_+") and 1 or 0
    if l ~= r then return l < r end
  end,

  ---Prioritize items that ends with "= ..." (usually for argument completion).
  prioritize_argument = function(lhs, rhs)
    local l = (lhs.completion_item.label:find "=$") and 1 or 0
    local r = (rhs.completion_item.label:find "=$") and 1 or 0
    if l ~= r then return l > r end
  end,
}
local cmp_sorting = {
  -- see https://github.com/hrsh7th/nvim-cmp/blob/main/lua/cmp/config/compare.lua
  -- and https://github.com/hrsh7th/nvim-cmp/blob/main/lua/cmp/config/default.lua
  priority_weight = 2,
  comparators = {
    cmp.config.compare.offset,
    cmp.config.compare.exact,
    cmp.config.compare.score,
    function(...) return cmp_helper.compare.prioritize_argument(...) end,
    function(...) return cmp_helper.compare.deprioritize_underscore(...) end,
    cmp.config.compare.recently_used,
    cmp.config.compare.locality,
    cmp.config.compare.kind,
    cmp.config.compare.sort_text,
    cmp.config.compare.length,
    cmp.config.compare.order,
  },
}

cmp.setup({
  mapping = cmp_mappings,
  sources = {
    {name = 'path'},
    {name = 'nvim_lsp'},
    {name = 'buffer', keyword_length = 3},
    {name = 'luasnip', keyword_length = 2},
  },
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  sorting = cmp_sorting,
})

-- Use buffer source for `/`.
cmp.setup.cmdline('/', {
  mapping = cmp.mapping.preset.cmdline(),
  completion = { autocomplete = false },
  sources = {
    { name = 'buffer' }
  }
})

-- Use cmdline & path source for ':'.
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    { name = 'cmdline',
      option = {
        ignore_cmds = { 'Man', '!' }
      },
    },
  })
})

-- If you want to insert `(` after selected function
local ok, cmp_autopairs = pcall(require, 'nvim-autopairs.completion.cmp')
if ok then
  cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
end
