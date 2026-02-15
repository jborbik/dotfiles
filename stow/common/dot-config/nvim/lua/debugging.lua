return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      {'rcarriga/nvim-dap-ui', dependencies = 'nvim-neotest/nvim-nio'},
      'theHamsta/nvim-dap-virtual-text',

      -- Installs the debug adapters
      'williamboman/mason.nvim',
      'jay-babu/mason-nvim-dap.nvim',

      -- Add your own debuggers here
      'leoluz/nvim-dap-go',
      'mfussenegger/nvim-dap-python',

      -- Miscellaneous
      {
        'Weissle/persistent-breakpoints.nvim',
        opts = {
          load_breakpoints_event = { "BufReadPost" }
        },
        config = function(_, opts)
          vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = '#993939' })
          vim.fn.sign_define('DapBreakpoint', { text = '•', texthl='DapBreakpoint'})
          vim.fn.sign_define('DapBreakpointCondition', { text = '', texthl='DapBreakpoint'})

          require("persistent-breakpoints").setup(opts)
          require("persistent-breakpoints.api").load_breakpoints()
        end
      },
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {
          virt_text_pos = 'eol',
        },
      },
      "stevearc/overseer.nvim",
    },
    keys = {
      { '<F5>',       function() require('dap').continue() end,          desc = 'Debug: Start/Continue' },
      { '<F17>',      function() require('dap').terminate() end,         desc = 'Debug: Stop' }, -- SHIFT+F5
      { '<F29>',      function() require('dap').run_last() end,          desc = 'Debug: Run last' }, -- CTRL+F5
      { '<F6>',       function() require('dap').pause() end,             desc = 'Debug: Pause' },
      { '<F9>',       function() require('dap').continue() end,          desc = 'Debug: Start/Continue' },
      { '<F11>',      function() require('dap').step_into() end,         desc = 'Debug: Step into' },
      { '<F10>',      function() require('dap').step_over() end,         desc = 'Debug: Step over' },
      { '<F23>',      function() require('dap').step_out() end,          desc = 'Debug: Step out' }, --SHIFT+F11
      { '<F8>',       function() require('persistent-breakpoints.api').toggle_breakpoint() end, desc = 'Debug: Toggle breakpoint' },
      { '<leader>eb', function() require('persistent-breakpoints.api').toggle_breakpoint() end, desc = 'Debug: Toggle breakpoint' },
      { '<leader>ec', function() require('persistent-breakpoints.api').set_conditional_breakpoint() end, desc = 'Debug: Set conditional breakpoint' },
      { '<leader>er', function() require('persistent-breakpoints.api').clear_all_breakpoints() end, desc = 'Debug: Remove all breakpoints' },
      { '<leader>et', function() require('dapui').toggle() end,          desc = 'Debug: UI toggle' },
      { '<leader>ee', function() require('dapui').eval() end, mode = {'n', 'x'},    desc = 'Debug: Eval current expression' },
      { '<leader>ei', function() require('dapui').eval(vim.fn.input("Expression to eval: ")) end, mode = {'n', 'x'},    desc = 'Debug: Eval input expression' },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      require('mason-nvim-dap').setup()

      -- Dap UI setup
      -- For more information, see |:help nvim-dap-ui|
      dapui.setup({})

      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      -- dap.listeners.before.event_terminated['dapui_config'] = dapui.close
      dap.listeners.before.event_exited['dapui_config'] = dapui.close

      -- Set up adapter specific configs
      require('dap-go').setup()
      require('dap-python').setup(vim.fn.stdpath('data') .. "/mason/packages/debugpy/venv/bin/python3")
      -- a lot of it comes from https://github.com/mfussenegger/dotfiles/blob/488c0a432ee8b569806707eae260055576777017/vim/.config/nvim/lua/me/dap.lua
      local last_program = vim.fn.getcwd() .. '/'
      local function program()
        local this_program = vim.fn.input({
          prompt = 'Path to executable: ',
          default = last_program,
          completion = 'file'
        })
        last_program = this_program
        return this_program
      end
      local last_args = ""
      local function args()
        local this_args = vim.fn.input({
          prompt = 'Arguments: ',
          default = last_args,
        })
        last_args = this_args
        return vim.split(this_args, " ")
      end
      local configs = {
        {
          name = "cppdbg: Launch",
          type = "cppdbg",
          request = "launch",
          program = program,
          cwd = '${workspaceFolder}',
          args = {},
        },
        {
          name = "cppdbg: Launch with args",
          type = "cppdbg",
          request = "launch",
          program = program,
          cwd = '${workspaceFolder}',
          args = args,
        },
        {
          name = "cppdbg: Attach",
          type = "cppdbg",
          request = "Attach",
          processId = function()
            return tonumber(vim.fn.input({ prompt = "Pid: "}))
          end,
          program = program,
          cwd = '${workspaceFolder}',
          args = {},
        },
        {
          name = "codelldb: Launch",
          type = "codelldb",
          request = "launch",
          program = program,
          cwd = '${workspaceFolder}',
          args = {},
        },
        {
          name = "codelldb: Launch with args",
          type = "codelldb",
          request = "launch",
          program = program,
          cwd = '${workspaceFolder}',
          args = args,
        },
        {
          name = "codelldb: Attach (select process)",
          type = 'codelldb',
          request = 'attach',
          pid = require('dap.utils').pick_process,
          args = {},
        },
        {
          name = "codelldb: Attach (input pid)",
          type = 'codelldb',
          request = 'attach',
          pid = function()
            return tonumber(vim.fn.input({ prompt = 'pid: '}))
          end,
          args = {},
        },
        {
          name = "lldb: Launch (integratedTerminal)",
          type = "lldb",
          request = "launch",
          program = program,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
          runInTerminal = true,
        },
        {
          name = "lldb: Launch (console)",
          type = "lldb",
          request = "launch",
          program = program,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
          runInTerminal = false,
        },
        {
          name = "lldb: Attach to process",
          type = 'lldb',
          request = 'attach',
          pid = require('dap.utils').pick_process,
          args = {},
        },
      }
      dap.adapters.cppdbg = {
        id = 'cppdbg',
        type = 'executable',
        command = vim.fn.stdpath('data') .. '/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7',
      }
      dap.adapters.codelldb = {
        type = 'server',
        port = "${port}",
        executable = {
          command = vim.fn.stdpath('data') .. '/mason/packages/codelldb/extension/adapter/codelldb',
          args = {"--port", "${port}"},
        }
      }
      dap.adapters.lldb = {
        type = 'executable',
        command = '/usr/bin/lldb-vscode',
        name = "lldb"
      }
      dap.configurations.c = configs
      dap.configurations.rust = configs
      dap.configurations.cpp = configs
      require('dap.ext.vscode').type_to_filetypes = {
        lldb = { 'rust', 'c', 'cpp' },
      }
      vim.schedule(function()
        require("overseer").enable_dap(true)
      end)
    end,
    cond = not_vscode
  },
}
