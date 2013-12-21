require 'rubygems'
require 'sinatra'
require 'json'
require 'bunny'

enable :sessions
set :show_exceptions, true

# Extract the connection string for the rabbitmq service from the
# service information provided by Cloud Foundry in an environment
# variable.
def amqp_url
  if not ENV['VCAP_SERVICES']
    return {
        :host => "172.16.32.11",
        :port => 5672,
        :username => "guest",
        :password => "guest",
        :vhost => "/",
    }
  end

  services = JSON.parse(ENV['VCAP_SERVICES'], :symbolize_names => true)
  url = services.values.map do |srvs|
    srvs.map do |srv|
      if srv[:label] =~ /^rabbitmq-/
        srv[:credentials]
      else
        []
      end
    end
  end.flatten!.first
end

# Opens a client connection to the RabbitMQ service, if one isn't
# already open.  This is a class method because a new instance of
# the controller class will be created upon each request.  But AMQP
# connections can be long-lived, so we would like to re-use the
# connection across many requests.
def client
  unless $client
    u = amqp_url
    puts u
    c = Bunny.new(u)
    c.start
    $client = c

    # We only want to accept one un-acked message
    $client.qos :prefetch_count => 1
  end
  $client
end

def exchange exchange_name
  exchange = client.exchange exchange_name, :type => 'topic', :durable => true

end

def queue queue_name, key, exchange_name
  queue = client.queue(queue_name)
  queue.bind(exchange_name, :key => key)
end

def publish(message, exchange_name, queue_name, key)
  queue_exchange = exchange exchange_name
  queue queue_name, key, exchange_name
  queue_exchange.publish message,:key => key
end

get "/" do
  erb :index
  #"/events is rest api.<p>"
  #"RABBITMQ_URL: #{ENV['RABBITMQ_URL']}"
end

post "/events" do
  "please use PUT."
end

put "/events" do
  puts "incoming request"
  payload = request.body.string
  data = JSON.parse(payload)

  if data.nil? or !data.has_key?("Type")
    status 400
  else

    publish payload,  "stackato-events.topic", "kato-events", "all.events"

    status 200
    body JSON.pretty_generate(data)
  end
end
