-- Render mermaid diagrams as ASCII art inside Neovim.
--
-- Requires the `mermaid-ascii` binary:
--   CGO_ENABLED=0 go install github.com/AlexanderGrooff/mermaid-ascii@latest
-- It is looked up on $PATH, then falls back to ~/go/bin/mermaid-ascii.
--
-- Ways to view a diagram:
--   <leader>mm       -- render the ```mermaid block under the cursor as a real
--                       PNG (mermaid-cli) shown as a Sixel image in a tmux popup
--                       (:MermaidPopup). Needs a Sixel-capable tmux + terminal.
--   :MermaidRender   -- same block rendered as ASCII art in a float (no popup /
--                       tmux needed). A no-dependency fallback.
--   inline mode      -- on opening a markdown file, every ```mermaid block is
--                       rendered as ASCII *in place*: the source lines are
--                       concealed and the diagram is shown where they were. The
--                       render stays put regardless of cursor position; to get
--                       the raw source back for editing, toggle the whole thing
--                       off with :MermaidInlineToggle (<leader>mi).
--
-- Diagram types mermaid-ascii cannot handle (class, gantt, state, pie) simply
-- stay as raw source -- inline mode leaves them untouched.

local M = {}

-- Resolve the mermaid-ascii binary once.
local function binary()
  if vim.fn.executable("mermaid-ascii") == 1 then
    return "mermaid-ascii"
  end
  local fallback = vim.fn.expand("~/go/bin/mermaid-ascii")
  if vim.fn.executable(fallback) == 1 then
    return fallback
  end
  return nil
end

-- A line that opens a fenced mermaid block: ```mermaid  /  ~~~mermaid
local function is_open_fence(line)
  return line:match("^%s*```+%s*mermaid%s*$") ~= nil
    or line:match("^%s*~~~+%s*mermaid%s*$") ~= nil
end

-- A line that closes a fenced code block: ``` / ~~~ (no info string).
local function is_close_fence(line)
  return line:match("^%s*```+%s*$") ~= nil or line:match("^%s*~~~+%s*$") ~= nil
end

-- Run mermaid-ascii on `source` (a string) and return the ASCII lines, or
-- nil on failure / unsupported diagram. Callback style; runs `cb(lines|nil)`
-- on the main loop.
local function run_ascii(source, cb)
  local bin = binary()
  if not bin or source == "" then
    cb(nil)
    return
  end
  vim.system({ bin, "-f", "-" }, { stdin = source, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        cb(nil)
        return
      end
      local out = vim.split((res.stdout or ""):gsub("%s+$", ""), "\n", { plain = true })
      if #out == 0 or (#out == 1 and out[1] == "") then
        cb(nil)
        return
      end
      cb(out)
    end)
  end)
end

--------------------------------------------------------------------------------
-- Float renderer (:MermaidRender / <leader>mm)
--------------------------------------------------------------------------------

-- Return the mermaid source lines relevant to the cursor.
-- For markdown-ish buffers: the fenced block the cursor sits in.
-- For dedicated mermaid buffers: the whole file.
local function collect_source()
  local ft = vim.bo.filetype
  local name = vim.api.nvim_buf_get_name(0)
  local is_mermaid_file = ft == "mermaid"
    or name:match("%.mmd$") ~= nil
    or name:match("%.mermaid$") ~= nil

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  if is_mermaid_file then
    return lines
  end

  local cur = vim.api.nvim_win_get_cursor(0)[1] -- 1-indexed

  -- Search upward for the opening fence.
  local start_fence
  for i = cur, 1, -1 do
    if is_open_fence(lines[i]) then
      start_fence = i
      break
    end
    -- A closing fence above us (that is not our opener) means we walked out of
    -- an unrelated block; keep searching, mermaid opener may still be higher.
  end
  if not start_fence then
    return nil, "No ```mermaid block found around the cursor."
  end

  -- Search downward for the matching closing fence.
  local end_fence
  for i = start_fence + 1, #lines do
    if is_close_fence(lines[i]) then
      end_fence = i
      break
    end
  end
  if not end_fence then
    return nil, "Unterminated ```mermaid block (no closing fence)."
  end

  if cur < start_fence or cur > end_fence then
    return nil, "Cursor is not inside a ```mermaid block."
  end

  local body = {}
  for i = start_fence + 1, end_fence - 1 do
    body[#body + 1] = lines[i]
  end
  return body
end

-- Open the given text lines in a scratch floating window.
local function open_float(text_lines, title)
  local width = 0
  for _, l in ipairs(text_lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.max(width + 2, 20)
  local height = #text_lines

  local max_w = math.floor(vim.o.columns * 0.9)
  local max_h = math.floor(vim.o.lines * 0.85)
  width = math.min(width, max_w)
  height = math.min(height, max_h)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text_lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "mermaid_ascii"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = title and (" " .. title .. " ") or nil,
    title_pos = "center",
  })
  vim.wo[win].wrap = false

  -- Close helpers.
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true })
  end
end

-- Public: render the mermaid source near the cursor in a floating window.
function M.render()
  if not binary() then
    vim.notify(
      "mermaid-ascii not found. Install: CGO_ENABLED=0 go install "
        .. "github.com/AlexanderGrooff/mermaid-ascii@latest",
      vim.log.levels.ERROR
    )
    return
  end

  local src, err = collect_source()
  if not src then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  if #src == 0 then
    vim.notify("mermaid block is empty.", vim.log.levels.WARN)
    return
  end

  run_ascii(table.concat(src, "\n"), function(out)
    if not out then
      vim.notify(
        "mermaid render failed (unsupported diagram type or bad syntax).",
        vim.log.levels.ERROR
      )
      return
    end
    open_float(out, "mermaid")
  end)
end

--------------------------------------------------------------------------------
-- Popup renderer (real PNG -> Sixel, in a tmux popup)
--------------------------------------------------------------------------------

-- Public: render the mermaid block near the cursor to a PNG and show it as a
-- Sixel image in a temporary tmux window. Requires a Sixel-capable tmux +
-- terminal. A tmux *window* (real pane) is used rather than display-popup,
-- because popup overlays do not composite Sixel images -- only panes do.
function M.render_popup()
  if not vim.env.TMUX then
    vim.notify(
      "mermaid popup needs to run inside tmux (Sixel build). Use :MermaidRender for the ASCII float.",
      vim.log.levels.ERROR
    )
    return
  end
  for _, exe in ipairs({ "tmux", "mmdc", "chafa" }) do
    if vim.fn.executable(exe) == 0 then
      vim.notify("mermaid popup: '" .. exe .. "' not found on $PATH.", vim.log.levels.ERROR)
      return
    end
  end

  local src, err = collect_source()
  if not src then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  if #src == 0 then
    vim.notify("mermaid block is empty.", vim.log.levels.WARN)
    return
  end

  local tmp = vim.fn.tempname() .. ".mmd"
  vim.fn.writefile(src, tmp)

  -- Invoke via `bash` explicitly so it works even if the script lost its +x bit
  -- on checkout (e.g. a repo cloned onto a filesystem without exec bits).
  local script = vim.fs.joinpath(vim.fn.stdpath("config"), "scripts", "mermaid-popup.sh")
  local inner = "bash " .. vim.fn.shellescape(script) .. " " .. vim.fn.shellescape(tmp)

  -- Open a new tmux window that runs the render script; it closes itself when
  -- the script exits (on keypress), returning to this (nvim) window.
  vim.system({
    "tmux", "new-window", "-n", "mermaid", inner,
  }, {}, function(res)
    -- Note: new-window returns immediately, so do NOT delete `tmp` here (the
    -- script reads it asynchronously and removes it itself when done).
    if res.code ~= 0 and res.stderr and res.stderr ~= "" then
      vim.schedule(function()
        vim.notify("tmux new-window failed:\n" .. res.stderr, vim.log.levels.ERROR)
      end)
    end
  end)
end

--------------------------------------------------------------------------------
-- Inline renderer (render in place; toggle off to reveal source for editing)
--------------------------------------------------------------------------------

local ns = vim.api.nvim_create_namespace("mermaid_inline")

-- Cache ASCII output keyed by the exact block source, so unchanged blocks are
-- never re-run (across buffers). Value is a list of lines, or `false` for a
-- block mermaid-ascii could not render (so we don't retry it).
local ascii_cache = {}

-- Per-buffer state: { enabled, blocks, gen, timer }.
-- A block is { open, close, body(list), key(string), ascii(list|nil),
--              rendered(bool), mark_ids(list) } with 1-indexed line numbers.
local state = {}

-- Find every ```mermaid ... ``` block in the buffer (1-indexed line numbers).
local function scan_blocks(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local i = 1
  while i <= #lines do
    if is_open_fence(lines[i]) then
      local open = i
      local close
      for j = i + 1, #lines do
        if is_close_fence(lines[j]) then
          close = j
          break
        end
      end
      if not close then
        break
      end
      local body = {}
      for k = open + 1, close - 1 do
        body[#body + 1] = lines[k]
      end
      blocks[#blocks + 1] = { open = open, close = close, body = body }
      i = close + 1
    else
      i = i + 1
    end
  end
  return blocks
end

-- Draw the diagram for `block`: conceal its source lines and show the ASCII
-- where they were. Anchors the virtual lines on an *unconcealed* neighbouring
-- line so they always render.
local function place_block(bufnr, block)
  if not block.ascii then
    return
  end
  block.mark_ids = {}

  -- Conceal each source line (fences + body).
  for row = block.open - 1, block.close - 1 do
    local id = vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, { conceal_lines = "" })
    table.insert(block.mark_ids, id)
  end

  -- Build the virtual lines (left-aligned to column 0 for maximum width).
  local virt = {}
  for _, l in ipairs(block.ascii) do
    virt[#virt + 1] = { { l, "MermaidAscii" } }
  end

  local total = vim.api.nvim_buf_line_count(bufnr)
  local id
  if block.close < total then
    -- Attach above the first line *after* the block.
    id = vim.api.nvim_buf_set_extmark(bufnr, ns, block.close, 0, {
      virt_lines = virt,
      virt_lines_above = true,
      virt_lines_leftcol = true,
    })
  elseif block.open > 1 then
    -- Block ends the file: attach below the line before it.
    id = vim.api.nvim_buf_set_extmark(bufnr, ns, block.open - 2, 0, {
      virt_lines = virt,
      virt_lines_leftcol = true,
    })
  else
    -- Whole buffer is one block.
    id = vim.api.nvim_buf_set_extmark(bufnr, ns, block.open - 1, 0, {
      virt_lines = virt,
      virt_lines_above = true,
      virt_lines_leftcol = true,
    })
  end
  table.insert(block.mark_ids, id)
  block.rendered = true
end

-- Rescan the buffer and (re)render every block. Cached blocks render
-- synchronously; uncached ones spawn mermaid-ascii and render on completion.
-- The render stays put regardless of cursor position -- to edit a block, toggle
-- inline mode off (:MermaidInlineToggle) to reveal all source.
local function refresh(bufnr)
  local st = state[bufnr]
  if not (st and st.enabled) or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  st.gen = (st.gen or 0) + 1
  local gen = st.gen
  st.blocks = scan_blocks(bufnr)

  for _, block in ipairs(st.blocks) do
    local key = table.concat(block.body, "\n")
    block.key = key
    local cached = ascii_cache[key]
    if cached ~= nil then
      if cached then
        block.ascii = cached
        place_block(bufnr, block)
      end
    else
      run_ascii(key, function(ascii)
        ascii_cache[key] = ascii or false
        -- Bail if the buffer was re-scanned meanwhile (marks would be stale).
        if st.gen ~= gen or not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end
        if ascii then
          block.ascii = ascii
          place_block(bufnr, block)
        end
      end)
    end
  end
end

-- Debounced full refresh after edits (line counts / block bounds may shift).
local function schedule_refresh(bufnr)
  local st = state[bufnr]
  if not st then
    return
  end
  if st.timer then
    st.timer:stop()
    st.timer:close()
    st.timer = nil
  end
  local timer = vim.uv.new_timer()
  st.timer = timer
  timer:start(400, 0, function()
    timer:stop()
    timer:close()
    if st.timer == timer then
      st.timer = nil
    end
    vim.schedule(function()
      refresh(bufnr)
    end)
  end)
end

-- Ensure 'conceallevel' is high enough for the current window to hide lines.
local function ensure_conceal()
  if vim.wo.conceallevel < 2 then
    vim.wo.conceallevel = 2
  end
end

local function enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not binary() then
    vim.notify(
      "mermaid-ascii not found; inline rendering disabled. Install: "
        .. "CGO_ENABLED=0 go install github.com/AlexanderGrooff/mermaid-ascii@latest",
      vim.log.levels.WARN
    )
    return
  end
  state[bufnr] = state[bufnr] or {}
  state[bufnr].enabled = true
  ensure_conceal()
  refresh(bufnr)
end

local function disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local st = state[bufnr]
  if not st then
    return
  end
  st.enabled = false
  if st.timer then
    st.timer:stop()
    st.timer:close()
    st.timer = nil
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  st.blocks = {}
end

function M.enable_inline(bufnr)
  enable(bufnr)
end

-- Explicitly turn inline rendering on/off for a buffer (used by the combined
-- markdown+mermaid toggle so both stay in sync).
function M.set_inline(bufnr, on)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if on then
    enable(bufnr)
  else
    disable(bufnr)
  end
end

-- Is inline rendering currently enabled for this buffer?
function M.inline_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local st = state[bufnr]
  return st ~= nil and st.enabled == true
end

function M.toggle_inline(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local st = state[bufnr]
  if st and st.enabled then
    disable(bufnr)
  else
    enable(bufnr)
  end
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

-- opts.auto (default true): auto-enable inline rendering for markdown buffers.
function M.setup(opts)
  opts = opts or {}
  local auto = opts.auto ~= false

  vim.api.nvim_set_hl(0, "MermaidAscii", { default = true, link = "Comment" })

  vim.api.nvim_create_user_command("MermaidPopup", function()
    M.render_popup()
  end, { desc = "Render the mermaid diagram under the cursor as a PNG (Sixel) in a tmux popup" })

  vim.api.nvim_create_user_command("MermaidRender", function()
    M.render()
  end, { desc = "Render the mermaid diagram under the cursor as ASCII (float)" })

  vim.api.nvim_create_user_command("MermaidInlineToggle", function()
    M.toggle_inline()
  end, { desc = "Toggle inline ASCII rendering of mermaid blocks in this buffer" })

  vim.api.nvim_create_user_command("MermaidInlineRefresh", function()
    refresh(vim.api.nvim_get_current_buf())
  end, { desc = "Re-render inline mermaid blocks in this buffer" })

  local group = vim.api.nvim_create_augroup("MermaidInline", { clear = true })

  if auto then
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "markdown",
      callback = function(ev)
        ensure_conceal()
        enable(ev.buf)
      end,
    })
  end

  -- Keep 'conceallevel' correct whenever an enabled buffer enters a window.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      local st = state[ev.buf]
      if st and st.enabled then
        ensure_conceal()
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(ev)
      local st = state[ev.buf]
      if st and st.enabled then
        schedule_refresh(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(ev)
      state[ev.buf] = nil
    end,
  })

  -- Catch a markdown file that was opened before this plugin loaded
  -- (e.g. `nvim file.md`).
  if auto then
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype == "markdown" then
      ensure_conceal()
      enable(buf)
    end
  end
end

return M
