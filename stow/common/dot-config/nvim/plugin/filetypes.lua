local ftplugin = require("ftplugin")

local function run_file(cmd)
  vim.cmd.update()
  local task = require("overseer").new_task({
    cmd = cmd,
    components = { "unique", "default" },
  })
  task:start()
  local bufnr = task:get_bufnr()
  if bufnr then
    local splitright = vim.o.splitright  -- Save the current value of 'splitright'
    vim.cmd("set splitright")  -- Set 'splitright' to ensure the split goes to the right
    vim.cmd.vsplit()
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.o.splitright = splitright  -- Restore the original value of 'splitright'
  end
end

ftplugin.extend_all({
  DressingInput = {
    keys = {
      { "<C-k>", '<CMD>lua require("dressing.input").history_prev()<CR>', mode = "i" },
      { "<C-j>", '<CMD>lua require("dressing.input").history_next()<CR>', mode = "i" },
    },
  },
  python = {
    abbr = {
      inn = "is not None",
      ipmort = "import",
      improt = "import",
    },
    callback = function(bufnr)
      if vim.fn.executable("autoimport") == 1 then
        vim.keymap.set("n", "<leader>o", function()
          vim.cmd.write()
          vim.cmd("silent !autoimport " .. vim.api.nvim_buf_get_name(0))
          vim.cmd.edit()
          vim.lsp.buf.formatting({})
        end, { buffer = bufnr })
      end
      vim.keymap.set(
        "n",
        "<leader>e",
        function() run_file({ "python", vim.api.nvim_buf_get_name(0) }) end,
        { buffer = bufnr }
      )
    end,
  },
  rust = {
    compiler = "cargo",
    callback = function(bufnr)
      vim.keymap.set("n", "<leader>e", function() run_file({ "cargo", "run" }) end, { buffer = bufnr })
    end,
  },
  sh = {
    callback = function(bufnr)
      vim.keymap.set(
        "n",
        "<leader>e",
        function() run_file({ "bash", vim.api.nvim_buf_get_name(0) }) end,
        { buffer = bufnr }
      )
    end,
  },
})

ftplugin.setup()
