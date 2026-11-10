-- Bring nvim back after a reboot, together with tmux-resurrect.
--
-- Inside tmux, nvim keeps a session (buffers, splits, tabs, cursor) per tmux
-- pane in stdpath("state")/tmux-sessions/<session>_<window>_<pane>.vim,
-- rewritten as you move around, not only on exit: a shutdown may never let
-- VimLeave run. When tmux-resurrect relaunches nvim in a restored pane,
-- tmux/resurrect-extras.sh first drops a marker file for that pane; nvim sees
-- it on startup, loads the pane's session, and if Claude Code was running in it
-- reopens it with `:ClaudeCode --resume <id>` (the id is in the marker).
-- A plain nvim start (no marker) never touches the saved session.
local M = {}

local state = vim.fn.stdpath("state")
local session_dir = state .. "/tmux-sessions"
local marker_dir = state .. "/tmux-restore"
local ready = false -- no saving until startup (and any restore) is done
local timer

-- Same key as pane_key() in tmux/resurrect-extras.sh.
local function pane_key()
  local pane = vim.env.TMUX_PANE
  if not pane then
    return nil
  end
  local res = vim
    .system({ "tmux", "display", "-p", "-t", pane, "#{session_name}_#{window_index}_#{pane_index}" }, { text = true })
    :wait()
  if res.code ~= 0 then
    return nil
  end
  return (vim.trim(res.stdout):gsub("[^%w_.-]", "_"))
end

function M.save()
  local key = pane_key()
  if not key then
    return
  end
  vim.fn.mkdir(session_dir, "p")
  -- No terminals: a restored terminal would rerun its command (e.g. a fresh
  -- claude). Claude is resumed separately, by session id.
  local saved = vim.o.sessionoptions
  vim.o.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize"
  pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(session_dir .. "/" .. key .. ".vim"))
  vim.o.sessionoptions = saved
end

local function schedule_save()
  if not ready then
    return
  end
  timer = timer or vim.uv.new_timer()
  timer:stop()
  timer:start(1000, 0, vim.schedule_wrap(M.save))
end

-- Windows left empty by the session where a terminal (Claude) used to be.
local function close_empty_windows()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if
      #vim.api.nvim_list_wins() > 1
      and vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[buf].buftype == ""
      and vim.api.nvim_buf_get_name(buf) == ""
      and not vim.bo[buf].modified
      and vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
    then
      pcall(vim.api.nvim_win_close, win, false)
    end
  end
end

local function restore()
  local key = pane_key()
  local marker = key and (marker_dir .. "/" .. key)
  if not (marker and vim.uv.fs_stat(marker)) then
    return
  end
  local claude_id = vim.trim(table.concat(vim.fn.readfile(marker), ""))
  os.remove(marker)
  local session = session_dir .. "/" .. key .. ".vim"
  if vim.uv.fs_stat(session) then
    pcall(vim.cmd, "silent source " .. vim.fn.fnameescape(session))
    close_empty_windows()
  end
  if claude_id ~= "" then
    -- claudecode.nvim is lazy-loaded on its keys, so :ClaudeCode may not exist yet.
    vim.defer_fn(function()
      pcall(function()
        require("lazy").load({ plugins = { "claudecode.nvim" } })
      end)
      local ok, err = pcall(vim.cmd, "ClaudeCode --resume " .. claude_id)
      if not ok then
        vim.notify("session: could not resume Claude " .. claude_id .. ": " .. err, vim.log.levels.WARN)
      end
    end, 500)
  end
end

local group = vim.api.nvim_create_augroup("tmux_pane_session", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  nested = true, -- so the restored buffers get filetype/LSP/render autocmds
  callback = function()
    if vim.env.TMUX_PANE then
      restore()
      ready = true
    end
  end,
})
vim.api.nvim_create_autocmd(
  { "BufEnter", "WinNew", "WinClosed", "TabNew", "TabClosed", "VimResized", "FocusLost", "DirChanged" },
  { group = group, callback = schedule_save }
)
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    if ready then
      M.save()
    end
  end,
})

return M
