module StepFlow
  # store steps for flow
  # for example:
  # {
  #   "deploy_app" [:valid_request, :prepare_dirs]
  # }
  attr_reader :flow_steps
  attr_reader :step_failed

  private

  def step(step_key, first_or_last = nil, &block)
    return if @step_failed
    is_first = (first_or_last == :first_step)
    is_last  = (first_or_last == :last_step)
    flow = caller_locations(1,1)[0].label # # get from caller

    # init
    @flow_steps ||= {}
    if @flow_steps[flow].nil?
      if is_first
        @flow_steps[flow] = []
      else
        raise "should specific which is the first step"
      end
    end

    @flow_steps[flow].push step_key
    step_no = @flow_steps[flow].size
    log.info "#{flow} flow start:" if is_first
    log.info "  #{flow} #{step_no}):#{step_key}"
    result = nil
    # capture_stdout do
      result = yield
    # end
    # step_log step_stdout
    log.info "#{flow} flow end" if is_last
    result
  end

  def step_log(message)
    log.info "    #{message}"
  end

  # mark a step fails, reply errors message, stop rest steps
  def step_fails(response, failure)
    @step_failed = true
    flow = @flow_steps.keys.last
    step_no = @flow_steps[flow].size
    step_key = @flow_steps[flow].last
    failure = %{deploy faild on #{flow}(#{step_no}):#{step_key}\n} + failure
    response.reply(failure)
  end

end
