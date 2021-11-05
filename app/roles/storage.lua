local errors = require('errors')
-- класс ошибок дуступа к хранилищу профилей
local err_storage = errors.new_class("Storage error")
local log = require('log')

local function init_space()
    local link = box.schema.space.create('link', {format = {{'link_id', 'unsigned'}, {'bucket_id', 'unsigned'}, {'url', 'string'}}, if_not_exists = true})
    link:create_index('link_id', {parts={'link_id'}, if_not_exists=true,unique=true})
    link:create_index('bucket_id', {
        parts = {'bucket_id'},
        unique = false,
        if_not_exists = true,
    })

end

local function link_set(id, url, bucket_id)
    local exists = box.space.link:get(id)
    if exists == nil then
        box.space.link:insert(box.space.link:frommap({link_id=id,url=url, bucket_id=bucket_id}))
        return true
    else
        return false
    end
end

local function link_get(id)
    log.info("trying to get "..tostring(id))
    local link = box.space.link.index.link_id:get(id)
    log.info(link)
    if link == nil then
        return nil
    end
    return link.url
end


local function init(opts)
    if opts.is_master then
        init_space()

        box.schema.func.create('link_set', {if_not_exists = true})
        box.schema.func.create('link_get', {if_not_exists = true})
    end

    rawset(_G, 'link_set', link_set)
    rawset(_G, 'link_get', link_get)
end

return {
    role_name = 'storage',
    init = init,
    utils = {
        link_set = link_set,
        link_get = link_get
    },
    dependencies = {
        'cartridge.roles.vshard-storage'
    }
}