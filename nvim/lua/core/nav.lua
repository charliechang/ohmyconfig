-- C-h/j/k/l: move between nvim windows; at nvim's edge hand over to
-- tmux/nav.sh, which continues into the next tmux pane or terminal split
-- (Ghostty / Windows Terminal), local or remote. Replaces
-- nvim-tmux-navigation, which can only run a plain `tmux select-pane`.
-- Design + progress log: docs/terminal-split-nav.md
--
-- nav.sh tells this nvim it was *entered* (from the side it came from) over
-- RPC: v:lua.require'core.nav'.enter(dir). For that, nvim publishes its
-- server socket and binary on its tmux pane (@nvim_sock / @nvim_bin).
local M = {}

local script = vim.fn.resolve(vim.fn.stdpath("config")) .. "/../tmux/nav.sh"
local wincmd = { L = "h", D = "j", U = "k", R = "l" }
local back = { L = "R", R = "L", U = "D", D = "U" }

local function tmux(args)
  if vim.env.TMUX and vim.env.TMUX_PANE then
    vim.system(vim.list_extend({ "tmux" }, args))
  end
end

-- Terminal app the editor runs in directly (no tmux in between).
local function term_kind()
  if vim.env.TERM_PROGRAM == "ghostty" or vim.env.TERM == "xterm-ghostty" then
    return "ghostty"
  elseif vim.env.WT_SESSION or vim.fn.isdirectory("/mnt/c/Windows") == 1 then
    return "wt"
  end
  return "none"
end

function M.move(dir)
  local k = wincmd[dir]
  if vim.fn.winnr(k) ~= vim.fn.winnr() then
    vim.cmd("wincmd " .. k)
  elseif vim.env.TMUX then
    vim.system({ script, "move", dir, vim.env.TMUX_PANE or "" })
  else
    vim.system({ script, "term-move", dir, term_kind() })
  end
end

-- Entered while moving `dir`: go to the window on the edge it came in from
-- (moving right lands in the leftmost window, at the cursor's height).
function M.enter(dir)
  vim.cmd("999wincmd " .. wincmd[back[dir]])
  vim.cmd("redraw")
  return ""
end

for dir, key in pairs({ L = "<C-h>", D = "<C-j>", U = "<C-k>", R = "<C-l>" }) do
  vim.keymap.set({ "n", "x", "t" }, key, function()
    M.move(dir)
  end, { desc = "Move " .. wincmd[dir] .. " (nvim / tmux / terminal split)" })
end

local group = vim.api.nvim_create_augroup("core_nav", { clear = true })
if vim.env.TMUX and vim.env.TMUX_PANE then
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      tmux({ "set", "-p", "-t", vim.env.TMUX_PANE, "@nvim_sock", vim.v.servername })
      tmux({ "set", "-p", "-t", vim.env.TMUX_PANE, "@nvim_bin", vim.v.progpath })
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      vim.system({ "tmux", "set", "-pu", "-t", vim.env.TMUX_PANE, "@nvim_sock" }):wait()
      vim.system({ "tmux", "set", "-pu", "-t", vim.env.TMUX_PANE, "@nvim_bin" }):wait()
    end,
  })
else
  -- nvim straight in a terminal split: take the entry side ourselves.
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      vim.system({ script, "take" }, { text = true }, function(res)
        local dir = vim.trim(res.stdout or "")
        if wincmd[dir] then
          vim.schedule(function()
            M.enter(dir)
          end)
        end
      end)
    end,
  })
end

return M
