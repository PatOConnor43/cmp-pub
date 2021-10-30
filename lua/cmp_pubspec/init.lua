local cmp = require('cmp')
local job = require('plenary.job')

local endpoint = "https://pub.dartlang.org/api"
local useragent = vim.fn.shellescape("cmp_pubspec (https://github.com/PatOConnor43/cmp_pubspec)")
local header = "Content-Type: application/json"
local running_job_timer = nil
local name_cache = {}


local source = {}
local function parse_packages_json(response)
    if not response then
        return nil
    end
    local success, data = pcall(vim.fn.json_decode, response)

    if not success or data == nil then return nil end

    local packages_items = {}
    for _, value in ipairs(data.packages) do
        table.insert(packages_items, { label = value.package, kind = cmp.lsp.CompletionItemKind.Text })
    end
    --print(packages_items[1])
    return packages_items
end

local function simple_case_without_version(name, completion_callback)
    if name_cache[name] then
        completion_callback(name_cache[name])
        return
    end

    local url = endpoint .. "/search?q=" .. name .. "&page=1"
    -- handle simple case with version
    local function query_json()
        local function on_exit(j, code, _)
            if code ~= 0 then
                return
            end
            local resp = table.concat(j:result(), "\n")
            print('resp ' .. name .. ' ' .. resp)
            vim.schedule(function()
                local items = parse_packages_json(resp)
                name_cache[name] = items
                completion_callback(items)
            end)
        end
        local j = job:new {
            command = "curl",
            args = { "-sLA", useragent, url,"-H", header},
            on_exit = on_exit,
        }

        j:start()
    end

    pcall(query_json)
end

source.new = function()
    local self = setmetatable({}, { __index = source })
    return self
end

source.is_available = function()
    local filename = vim.fn.expand('%:t')
    return filename == 'pubspec.yaml'
end

function source.get_debug_name()
    return 'pubspec'
end

function source.resolve(self, completion_item, callback)
    callback(completion_item)
end

function source.execute(self, completion_item, callback)
    callback(completion_item)
end

function source.get_trigger_characters(self, config)
    return {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '_'}
end

--function source.get_keyword_pattern()
--  return [[\w\+]]
--end

function source.complete(self, params, callback)
    local items = {}
    job_cancelled = false
    --print(vim.inspect(params))
    table.insert(items, {label = 'asdf'})
    local cur_line = params.context.cursor_line

    -- Try to match simple case with version
    local name, version = cur_line:match('([%w_]+): (.*)')
    --print(name, version)
    if name ~= nil and version ~= nil then
        return
    end

    name = cur_line:match('([%w_]+)(.*)')
    print('hey ' .. name)
    if name ~= nil then
        --global_name = name
        --if running_job_timer ~= nil then
        --   running_job_timer:stop()
        --   running_job_timer:close()
        --   running_job_timer = nil
        --   print('New timer')
        --end
        running_job_timer = vim.loop.new_timer()
        running_job_timer:start(500, 0, function()
            print('Timer expired')
            vim.schedule(function() simple_case_without_version(name, callback) end)
            running_job_timer:close()
            running_job_timer = nil
        end)

    end
end



return source
