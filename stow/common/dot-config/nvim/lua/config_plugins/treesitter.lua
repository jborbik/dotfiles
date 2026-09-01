local parsers_to_install = { "bash", "cmake", "cpp", "css", "dockerfile", "go",
    "html", "json", "lua", "markdown", "markdown_inline", "python",
    "regex", "rust", "typescript", "vim", "vimdoc", "yaml", "xml",
}
-- latex parser requires tree-sitter cli to be installed for compilation
if vim.fn.executable('tree-sitter') == 1 then
  parsers_to_install[#parsers_to_install+1] = "latex"
end
require('nvim-treesitter').setup({
  ensure_installed = parsers_to_install,
  textobjects = {
    select = {
      enable = true,
      -- Automatically jump forward to textobj, similar to targets.vim
      lookahead = true,
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ['aa'] = '@parameter.outer',
        ['ia'] = '@parameter.inner',
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",
        ["ai"] = "@conditional.outer",
        ["ii"] = "@conditional.inner",
        ["ao"] = "@loop.outer",
        ["io"] = "@loop.inner",
      },
      include_surrounding_whitespace = true,
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ["]m"] = "@function.outer",
        -- ["]]"] = { query = "@class.outer", desc = "Next class start" },
        ["]o"] = { query = { "@loop.outer" } },
        ["]i"] = "@conditional.outer",
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        -- ["]["] = "@class.outer",
        ["]O"] = { query = { "@loop.outer" } },
        ["]I"] = "@conditional.outer",
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        -- ["[["] = "@class.outer",
        ["[o"] = { query = { "@loop.outer" } },
        ["[i"] = "@conditional.outer",
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        -- ["[]"] = "@class.outer",
        ["[O"] = { query = { "@loop.outer" } },
        ["[I"] = "@conditional.outer",
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ["<leader>a"] = "@parameter.inner",
      },
      swap_previous = {
        ["<leader>A"] = "@parameter.inner",
      },
    },
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      node_incremental = ".",
      scope_incremental = ";",
      node_decremental = "<bs>",
    },
  },
  highlight = {
    enable = not vscode,
  },
  indent = {
    enable = not vscode,
    disable = { 'python' },
  },
  matchup = {
    enable = true,
    disable_virtual_text = vscode,
  },
})

vim.keymap.set("n", "<leader>th", "<cmd>TSToggle highlight<cr>", {desc="[t]oggle treesitter [h]ighlight"})
