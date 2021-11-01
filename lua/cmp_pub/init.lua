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

local function string_not_empty(s)
    return s ~= nil and s:gsub('%s*', '') ~= nil
end

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

local function complete_names(name, completion_callback)
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
    local items = parse_packages_json(resp)
    name_cache[name] = items
    completion_callback(items)

end

local function complete_versions(name, completion_callback, package_host)
    if package_host ==  nil then
        package_host = endpoint
    end
    if version_cache[name] then
        completion_callback(version_cache[name])
        return
    end

    local url = package_host .. "/packages/" .. name

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
    local items = parse_versions_json(resp)
    version_cache[name] = items
    completion_callback(items)

end

local function search_for_hosted_name(row_to_search)
    -- An example of what the 'hosted' dependency looks like:
    -- package_name:
    --   hosted:
    --     name: package_name
    --     url: pub.private.com
    --   version: ^0.0.1    <- row_to_search should point here
    --
    -- The intent of this function is to find the top-most 'package_name' key and use that
    -- as the name to search versions for.
    local highest_potential_line = row_to_search - 5
    local lines = vim.api.nvim_buf_get_lines(0, highest_potential_line, row_to_search, false)
    local package_name_regex = '^%s%s([%w_]+):$'
    local url_regex = '^%s%s%s%s%s%surl:%s*(.*)$'
    local package_match = nil
    local url_match = nil
    for _, line in ipairs(lines) do
       local potential_package_match = line:match(package_name_regex)
       if potential_package_match ~= nil then
          package_match = potential_package_match
       end
       local potential_url_match = line:match(url_regex)
       if potential_url_match ~= nil then
          url_match = potential_url_match .. '/api'
       end
    end
    return package_match, url_match
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
    local name, version, package_host


    -- Try to match the literal string 'version:' for 'hosted' dependencies
    version = cur_line:match('%s%s%s%sversion:%s*(.*)')
    if version ~= nil then
        -- In this case we need to look through the yaml and find the actual name of the package.
        -- The name of the package should be above this line. We just may need to search up a couple lines.
        local cursor_row = params.context.cursor.row
        local cursor_col = params.context.cursor.col
        name, package_host = search_for_hosted_name(cursor_row)

        local colon_index = cur_line:find(':')
        if not colon_index then
            callback()
            return
        end
        print(colon_index < cursor_col)
        if colon_index < cursor_col then
            local on_run = function()
                complete_versions(name, callback, package_host)
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



    -- Try to match simple case with version
    name, version = cur_line:match('%s%s([%w_]+):%s*(.*)')
    if string_not_empty(name) and version ~= nil then
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
                complete_versions(name, callback)
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
    if string_not_empty(name) then
        print('incoming name ' .. name)
        if cjob ~= nil then
            cjob:cancel()
            cjob = nil
        end
        local on_run = function()
            complete_names(name, callback)
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
