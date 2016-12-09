module Listeners
  class EmployerEventReducerListener < Amqp::Client
    def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.employer_event_reducer"
    end

    def resource_event_broadcast(level, event_key, r_code, body = "", other_headers = {})
        event_body = (body.respond_to?(:to_s) ? body.to_s : body.inspect)
        broadcast_event({
          :routing_key => "#{level}.application.glue.employer_event_reducer.#{event_key}",
          :headers => other_headers.merge({
            :return_status => r_code.to_s,
            :submitted_timestamp => Time.now
          })
        },event_body)
    end

    def resource_error_broadcast(event_key, r_code, body = "", other_headers = {})
      resource_event_broadcast("error", event_key, r_code, body, other_headers)
    end

    def process_retrieved_resource(delivery_info, employer_id, event_resource, m_headers, event_name, event_time)
      resource_event_broadcast("info", "event_stored", "200", event_resource, m_headers.merge({:event_name => event_name, :event_time => event_time.to_i.to_s}))
      EmployerEvent.store_and_yield_deleted(employer_id, event_name, event_time, event_resource) do |destroyed_employer_event|
        resource_event_broadcast("info", "event_reduced", "200", destroyed_event.resource_body, {
          :employer_id => destroyed_event.employer_id,
          :event_name => destroyed_event.event_name,
          :event_time => destroyed_event.event_time.to_i.to_s
        })
      end
      channel.ack(delivery_info.delivery_tag, false)
    end

    def request_resource(employer_id)
      begin
        di, rprops, resp_body = request({:headers => {:employer_id => employer_id}, :routing_key => "resource.employer"},"", 15)
        r_headers = (rprops.headers || {}).to_hash.stringify_keys
        r_code = r_headers['return_status'].to_s
        if r_code == "200"
          [r_code, resp_body]
        else
          [r_code, resp_body.to_s]
        end
      rescue Timeout::Error => e
        ["503", ""]
      end
    end

    def on_message(delivery_info, properties, body)
      m_headers = (properties.headers || {}).to_hash.stringify_keys
      employer_id = m_headers["employer_id"].to_s
      event_name = delivery_info.routing_key
      event_time = get_timestamp(properties)
      if EmployerEvent.newest_event?(employer_id, event_name, event_time)
        r_code, resource_or_body = request_resource(employer_id)
        case r_code.to_s
        when "200"
          process_retrieved_resource(delivery_info, employer_id, resource_or_body, m_headers, event_name, event_time)
        when "404"
          resource_error_broadcast("resource_not_found", r_code, m_headers, m_headers)
          channel.ack(delivery_info.delivery_tag, false)
        when "503"
          resource_error_broadcast("resource_timeout", r_code, m_headers, m_headers)
          channel.reject(delivery_info.delivery_tag, true)
        else
          resource_error_broadcast("unknown_error", r_code, resource_or_body, m_headers)
          channel.ack(delivery_info.delivery_tag, false)
        end
      else
        resource_event_broadcast("info", "event_reduced", "200", resource_or_body, m_headers.merge({:event_name => event_name}))
        channel.ack(delivery_info.delivery_tag, false)
      end
    end

    def get_timestamp(msg_properties)
      message_ts = msg_properties.timestamp
      return Time.now if message_ts.blank?
      return Time.at(message_ts) if message_ts.kind_of?(Fixnum) || message_ts.kind_of?(Integer)
      message_ts 
    end

    def self.create_bindings(chan, q)
      ec = ExchangeInformation
      event_topic_exchange_name = "#{ec.hbx_id}.#{ec.environment}.e.topic.events"
      event_topic_exchange = chan.topic(event_topic_exchange_name, {:durable => true})
      q.bind(event_topic_exchange, {:routing_key => "info.events.employer.#"})
    end

    def self.run
      Process.setproctitle("%s - %s" % [self.name , $$])
      conn = AmqpConnectionProvider.start_connection
      chan = conn.create_channel
      chan.prefetch(1)
      q = chan.queue(self.queue_name, :durable => true)
      create_bindings(chan, q)
      self.new(chan, q).subscribe(:block => true, :manual_ack => true)
      conn.close
    end
  end
end
