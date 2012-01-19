module HttpLog
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @proxy = RequestProxy.new(env)

      if passes_filters?
        request =  HttpLog::Request.from_request(@proxy)

        HttpLog.callbacks.each do |callback|
          callback.call @proxy, request
        end

        request.save
        env['http_log.request_id'] = request.id.to_s
      end

      # Wipe away all remains of anything action_dispatch does.
      # Apparently it modifies the env in such a way that
      # that all the paramters do not make it to the controller.
      env.keys.select {|k| k =~ /action_dispatch/}.each do |k|
        env.delete k
      end

      @app.call env
    end

    def passes_filters?
      HttpLog.filters.each do |filter|
        matches_filter = if filter.is_a? Symbol
                   @proxy.path_info =~ /\.#{filter}$/
                 elsif filter.is_a? Regexp
                    @proxy.url =~ filter
                 else
                   filter.call @proxy
                 end

        return false if matches_filter
      end

      true
    end

  end
end
