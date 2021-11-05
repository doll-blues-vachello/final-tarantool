local cartridge = require('cartridge')
local errors = require('errors')
local log = require('log')

local err_vshard_router = errors.new_class("Vshard routing error")
local err_httpd = errors.new_class("httpd error")

local function json_response(req, json, status)
    local resp = req:render({json = json})
    resp.status = status
    return resp
end


local function set_url(req)
    local url = req:post_param('url')
    log.info(req:post_param())
    if url == nil then
        return json_response(req, {ok=false}, 400)
    end

    local router = cartridge.service_get('vshard-router').get()

    local id
    repeat
        id = math.random(0x1000000000000000, 0xffffffffffffffff)
        local bucket_id = router:bucket_id_mpcrc32(id)
        -- local res = router:call(bucket_id, 'write', 'link_set', {id, url, bucket_id})
        local resp, error = err_vshard_router:pcall(
            router.call, router, bucket_id, 'write', 'link_set', {id, url, bucket_id}
        )
        if error then
            return json_response(req, {e=error, r=resp}, 500)
        end
    until resp


    return {status=200, body="http://127.0.0.1:8080/r/"..string.format("%x", id)}
end

local function get_url(req)
    local id = req:stash('id')
    id = tonumber(id, 16)
    if id == nil then
        return {status=400, body="Bad url"}
    end

    local router = cartridge.service_get('vshard-router').get()
    local bucket_id = router:bucket_id_mpcrc32(id)

    local url = router:call(bucket_id, 'read', 'link_get', {id})
    if url == nil then
        return {status=404, body="Not found"}
    end

    return {status=302, headers = {['Location'] = url}}

end

local function init(opts)
    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    local httpd = require('http.server').new('0.0.0.0', 8080)

    httpd:route({path = '/set', method = 'POST'}, set_url)
    httpd:route({path = '/r/:id', method = 'GET'}, get_url)

    httpd:start()

    log.info("Created httpd FUCK FUCK")
    return true
end

return {
    role_name = 'api',
    init = init,
    dependencies = {
        'cartridge.roles.vshard-router'
    }
}