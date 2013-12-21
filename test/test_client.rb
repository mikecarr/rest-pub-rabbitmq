require 'test/unit'

require 'bunny'

#require_relative '../lib/utility/configuration'

class TestRabbit < Test::Unit::TestCase
  #configuration

  def amqp_url
    if not ENV['VCAP_SERVICES']
      return {
          :host => '192.168.1.170',
          :port => 10001,
          :user => 'uVeqpXrDo0cXA',
          :pass => 'pUwIaPiZQVuqj',
          :username => 'uVeqpXrDo0cXA',
          :password => 'pUwIaPiZQVuqj',
          #:user => 'au5RoK1a1trGJF',
          #:pass => 'apNM7uyzLrRUEH',
          :vhost => "va6dcfd1c749e4c06b8ea4392a0339c53",
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

  def client
    unless $client
      u = amqp_url
      c = Bunny.new(u, :logging => false)
      c.start
      $client = c

      # We only want to accept one un-acked message
      $client.qos :prefetch_count => 1
    end
    $client
  end

  def test_rabbit

    key = 'test.message'

    client
    puts client.inspect

    channel = client.channel
    puts channel.inspect

    # create exchange
    exchange = client.exchange 'test.topic', :type => 'topic', :durable => true
    puts exchange.inspect


    # create queue with ttl
    queue = client.queue('test.topic.queue',:arguments => { 'x-message-ttl' => 30000 })
    #queue = client.queue('test.topic.queue')

    # bind queue with key
    queue.bind("test.topic", :key=>"test.message");

    message = "A simple helloworld message"

    beginning_time = Time.now

    10000.times do

      exchange.publish(message, :key=> key)

    end

    end_time = Time.now
    puts "Time elapsed #{(end_time - beginning_time)*1000} milliseconds"

    #queue = client.queue('test.topic.queue',:arguments => { 'x-message-ttl' => 5000 })
    #queue = client.queue('test.topic.queue')
    #queue.bind('test.topic', :)

    #@@connection.queue(nil, :exclusive => true, :auto_delete => false, :arguments => { 'x-message-ttl' => 5000 })

    #queue.publish(message,:key => "#{key}")


  end

end