-- Combined markdown + mermaid render toggle.
--
-- One key (<leader>mi) flips BOTH render-markdown (headings/tables/code/...) and
-- the inline mermaid ASCII rendering for the current buffer, keeping them in
-- sync. Both auto-render when a markdown buffer opens; toggle off to get raw
-- source back for editing (there is no per-cursor auto-reveal -- the render
-- stays put until you toggle it off).

local M = {}

-- mermaid inline is the source of truth for "currently rendered?" -- it is
-- always loaded (lazy=false) and auto-enables on markdown open.
local function currently_on(buf)
  local ok, mermaid = pcall(require, "core.mermaid")
  if ok then
    return mermaid.inline_enabled(buf)
  end
  return true
end

function M.toggle()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "markdown" then
    vim.notify("markdown render toggle: not a markdown buffer", vim.log.levels.WARN)
    return
  end

  local turn_on = not currently_on(buf)

  local ok_m, mermaid = pcall(require, "core.mermaid")
  if ok_m then
    mermaid.set_inline(buf, turn_on)
  end

  local ok_r, rm = pcall(require, "render-markdown")
  if ok_r then
    rm.set_buf(turn_on) -- buffer-local enable/disable
  end

  vim.notify("markdown + mermaid render: " .. (turn_on and "on" or "off"), vim.log.levels.INFO)
end

return M
