local cjson = require("cjson")
local http = require("resty.http")
local redis = require("resty.redis")  

local function close_redis(red)  
	if not red then  
		return  
	end  
	local pool_max_idle_time = 10000 
	local pool_size = 100 
	local ok, err = red:set_keepalive(pool_max_idle_time, pool_size)  
	if not ok then  
		ngx.say("set keepalive error : ", err)  
	end  
end 

local uri_args = ngx.req.get_uri_args()
local productId = uri_args["productId"]

local cache_ngx = ngx.shared.my_cache
local productCacheKey = "product_"..productId
local productCache = cache_ngx:get(productCacheKey)

if productCache == "" or productCache == nil then
  local red = redis:new()  
  red:set_timeout(1000)  
  local ip = "192.168.31.223"  
  local port = 1112  
  local ok, err = red:connect(ip, port)  
  if not ok then  
    ngx.say("connect to redis error : ", err)  
    return close_redis(red)  
  end

  local redisResp, redisErr = red:get("dim_product_"..productId)

  if redisResp == ngx.null then  
    local httpc = http.new()
    local resp, err = httpc:request_uri("http://192.168.31.179:8767",{
      method = "GET",
      path = "/product?productId="..productId
    })
	
    productCache = resp.body
  end

  productCache = redisResp

  math.randomseed(tostring(os.time()):reverse():sub(1, 7))
  local expireTime = math.random(600, 1200)  

  cache_ngx:set(productCacheKey, productCache, expireTime)
end

local context = {
  productInfo = productCache,
}

local template = require("resty.template")
template.render("product.html", context)
