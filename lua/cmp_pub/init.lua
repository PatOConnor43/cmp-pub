local cmp = require('cmp')
local job = require('plenary.job')
local cancellable_job = require('cmp_pub.util.cancellable_job')

local endpoint = "https://pub.dartlang.org/api"
local useragent = vim.fn.shellescape("cmp_pubspec (https://github.com/PatOConnor43/cmp_pub)")
local header = "Content-Type: application/json"
local name_cache = {}
local version_cache = {}
local cjob = nil


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
    return packages_items
end

local function parse_versions_json(response)
    if not response then
        return nil
    end
    local success, data = pcall(vim.fn.json_decode, response)

    if not success or data == nil then return nil end

    local packages_items = {}
    for _, value in ipairs(data.versions) do
        table.insert(packages_items, { label = value.version, kind = cmp.lsp.CompletionItemKind.Text })
    end
    return packages_items
end

local function simple_case_without_version(name, completion_callback)
    if name_cache[name] then
        completion_callback(name_cache[name])
        return
    end

    local url = endpoint .. "/search?q=" .. name .. "&page=1"

    local j = job:new {
        command = "curl",
        args = { "-sLA", useragent, url,"-H", header},
    }

    local result, code = j:sync()
    if code ~= 0 then
        completion_callback()
        return
    end
    local resp = table.concat(result, "\n")
    print('resp ' .. name .. ' ' .. resp)
    local items = parse_packages_json(resp)
    name_cache[name] = items
    completion_callback(items)

end

local function simple_case_with_version(name, completion_callback)
    if version_cache[name] then
        completion_callback(version_cache[name])
        return
    end

    local url = endpoint .. "/packages/" .. name

    local j = job:new {
        command = "curl",
        args = { "--compressed", "-sLA", useragent, url,"-H", header},
    }

    local result, code = j:sync()
    if code ~= 0 then
        completion_callback()
        return
    end
    local resp = table.concat(result, "\n")
    print('resp ' .. name .. ' ' .. resp)
    local items = parse_versions_json(resp)
    version_cache[name] = items
    completion_callback(items)

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
    return 'pub'
end

function source.resolve(self, completion_item, callback)
    callback(completion_item)
end

function source.execute(self, completion_item, callback)
    callback(completion_item)
end

function source.get_trigger_characters(self, config)
    return {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '_',
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
            '.', '^', ' '
    }
end

--function source.get_keyword_pattern()
--  return [[\w\+]]
--end

function source.complete(self, params, callback)
    local cur_line = params.context.cursor_line
    local name, version

    -- Try to match simple case with version
    name, version = cur_line:match('%s%s([%w_]+):%s?(.*)')
    if name ~= nil and version ~= nil then
        print('incoming name: ' .. name .. ' version: ' .. version)
        local cursor = vim.api.nvim_win_get_cursor(0)
        local row = cursor[1]
        local col = cursor[2]
        print('cursor position: ' .. row .. ',' .. col)
        local colon_index = cur_line:find(':')
        if not colon_index then
            callback()
            return
        end
        if colon_index < col then
            local on_run = function()
                simple_case_with_version(name, callback)
            end
            local on_cancel = function()
                print('cancelled')
                callback()
            end
            cjob = cancellable_job.new({duration = 1000, on_run = on_run, on_cancel = on_cancel})
            cjob:start()

        end

        return
    end

    name = cur_line:match('%s%s([%w_]+)(.*)')
    if name ~= nil and name:gsub('%s*', '') ~= '' then
        print('incoming name ' .. name)
        if cjob ~= nil then
            cjob:cancel()
            cjob = nil
        end
        local on_run = function()
            simple_case_without_version(name, callback)
        end
        local on_cancel = function()
            print('cancelled')
            callback()
        end
        cjob = cancellable_job.new({duration = 1000, on_run = on_run, on_cancel = on_cancel})
        cjob:start()

    end
end



return source
