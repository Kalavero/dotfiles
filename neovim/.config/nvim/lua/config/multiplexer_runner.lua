local M = {}

local runner_pane

local function notify_error(message)
  vim.notify("Runner: " .. message, vim.log.levels.ERROR)
end

local function herdr(args)
  local command = vim.list_extend({ "herdr" }, args)
  local result = vim.system(command, { text = true }):wait()

  if result.code ~= 0 then
    local message = vim.trim(result.stderr or "")
    notify_error(message ~= "" and message or "Herdr command failed")
    return nil
  end

  if not result.stdout or vim.trim(result.stdout) == "" then
    return {}
  end

  local ok, response = pcall(vim.json.decode, result.stdout)
  if not ok then
    notify_error("Herdr returned invalid JSON")
    return nil
  end

  return response
end

local function available_panes()
  local response = herdr({ "pane", "list" })
  local panes = response and response.result and response.result.panes or {}

  return vim.tbl_filter(function(pane)
    return pane.pane_id ~= vim.env.HERDR_PANE_ID
      and pane.tab_id == vim.env.HERDR_TAB_ID
  end, panes)
end

local function pane_label(pane)
  local detail = pane.terminal_title_stripped
    or pane.foreground_cwd
    or pane.cwd
    or ""

  if detail == "" then
    return pane.pane_id
  end

  return string.format("%s  %s", pane.pane_id, detail)
end

function M.is_herdr()
  return vim.env.HERDR_ENV == "1"
    and vim.env.HERDR_PANE_ID ~= nil
    and vim.env.HERDR_PANE_ID ~= ""
    and (vim.env.TMUX == nil or vim.env.TMUX == "")
end

function M.target()
  return runner_pane
end

function M.attach(pane_id, on_attached)
  if not M.is_herdr() then
    notify_error("Neovim is not running directly in Herdr")
    return false
  end

  if not pane_id or pane_id == "" then
    local panes = available_panes()
    if #panes == 0 then
      notify_error("No other pane is available in this Herdr tab")
      return false
    end

    if #panes == 1 then
      return M.attach(panes[1].pane_id, on_attached)
    end

    vim.ui.select(panes, {
      prompt = "Runner pane: ",
      format_item = pane_label,
    }, function(pane)
      if pane then
        M.attach(pane.pane_id, on_attached)
      end
    end)
    return true
  end

  if pane_id == vim.env.HERDR_PANE_ID then
    notify_error("Cannot attach the runner to Neovim's own pane")
    return false
  end

  local response = herdr({ "pane", "get", pane_id })
  local pane = response and response.result and response.result.pane
  if not pane or pane.pane_id ~= pane_id then
    notify_error("Invalid Herdr pane ID: " .. pane_id)
    return false
  end

  runner_pane = pane_id
  vim.notify("Runner pane set to: " .. pane_id)
  if on_attached then
    on_attached()
  end
  return true
end

function M.unset()
  runner_pane = nil
end

function M.send(command, ensure_pane)
  if not M.is_herdr() then
    if vim.fn.exists("*VtrSendCommand") == 0 then
      notify_error("vim-tmux-runner is not available")
      return false
    end

    vim.fn.VtrSendCommand(command, ensure_pane and 1 or 0)
    return true
  end

  if not runner_pane then
    if ensure_pane then
      return M.attach(nil, function()
        M.send(command, false)
      end)
    end

    notify_error("No runner pane attached")
    return false
  end

  if not command or command == "" then
    notify_error("Command string required")
    return false
  end

  if vim.g.VtrClearBeforeSend ~= 0 then
    if not herdr({ "pane", "send-keys", runner_pane, "ctrl+u", "ctrl+l" }) then
      return false
    end
  end

  return herdr({ "pane", "run", runner_pane, command }) ~= nil
end

function M.setup()
  if not M.is_herdr() then
    return
  end

  vim.api.nvim_create_user_command("VtrAttachToPane", function(opts)
    M.attach(opts.args)
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("VtrSendCommandToRunner", function(opts)
    if opts.args ~= "" then
      M.send(opts.args, opts.bang)
      return
    end

    vim.ui.input({ prompt = "Command to run: " }, function(command)
      if command and command ~= "" then
        M.send(command, opts.bang)
      end
    end)
  end, { bang = true, nargs = "?" })

  vim.api.nvim_create_user_command("VtrUnsetRunnerPane", M.unset, {})
end

return M
