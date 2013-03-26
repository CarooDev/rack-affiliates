module Rack
  #
  # Rack Middleware for extracting information from the request params and cookies.
  # It populates +env['affiliate.tag']+, # +env['affiliate.from']+ and
  # +env['affiliate.time'] if it detects a request came from an affiliated link
  #
  class Affiliates
    COOKIE_TAG = "aff_tag"
    COOKIE_FROM = "aff_from"
    COOKIE_TIME = "aff_time"
    COOKIE_FB_REQUEST_IDS = "aff_fb_request_ids"

    def initialize(app, opts = {})
      @app = app
      @param = opts[:param] || "ref"
      @from = opts[:from] || "s"
      @fb_request_ids = opts[:fb_request_ids] || "request_ids"
      @cookie_ttl = opts[:ttl] || 60*60*24*30  # 30 days
      @cookie_domain = opts[:domain] || nil
    end

    def call(env)
      req = Rack::Request.new(env)

      params_tag = req.params[@param]
      cookie_tag = req.cookies[COOKIE_TAG]

      if cookie_tag
        tag, from, time, fb_request_ids = cookie_info(req)
      end

      if params_tag && params_tag != cookie_tag
        tag, from, time, fb_request_ids = params_info(req)
      end

      if tag
        env["affiliate.tag"] = tag
        env['affiliate.from'] = from
        env['affiliate.time'] = time
        env['affiliate.fb_request_ids'] = fb_request_ids
      end

      status, headers, body = @app.call(env)

      response = Rack::Response.new body, status, headers

      if tag != cookie_tag
        bake_cookies(response, tag, from, time, fb_request_ids)
      end

      response.finish
    end

    def affiliate_info(req)
      params_info(req) || cookie_info(req)
    end

    def params_info(req)
      [req.params[@param], req.params[@from], Time.now.to_i,
        req.params[@fb_request_ids]]
    end

    def cookie_info(req)
      [req.cookies[COOKIE_TAG], req.cookies[COOKIE_FROM],
        req.cookies[COOKIE_TIME].to_i, req.cookies[COOKIE_FB_REQUEST_IDS]]
    end

    protected
    def bake_cookies(res, tag, from, time, fb_request_ids)
      expires = Time.now + @cookie_ttl
      { COOKIE_TAG => tag,
        COOKIE_FROM => from,
        COOKIE_TIME => time,
        COOKIE_FB_REQUEST_IDS => fb_request_ids }.each do |key, value|
          cookie_hash = {:value => value, :expires => expires}
          cookie_hash[:domain] = @cookie_domain if @cookie_domain
          res.set_cookie(key, cookie_hash)
      end
    end
  end
end
