require "kemal"
require "process"
require "redis"
require "secure_random"

class Action
  def run
  end
end

class Rule
  def succeed : Action
    Action.new
  end

  def fail : Action
    Action.new
  end
end

class PlaySound < Action
  def initialize(@file)
  end

  def run
    Process.new("mplayer", [@file])
    true
  end
end

class MacaddressConnected < Rule
  class Data
    JSON.mapping({
      address: String,
      from:    Int32,
      to:      Int32,
      file:    String,
    })
  end

  def initialize(@address : String, @from : Int, @to : Int, @file : String)
  end

  def process(address : String) : Action
    return fail if address.upcase != @address.upcase
    @from < Time.now.hour < @to ? succeed : fail
  end

  def succeed : Action
    PlaySound.new @file
  end
end

redis = Redis.new

get "/" do |env|
  "Hello World!"
end

put "/wifi/connected" do |env|
  params = env.params
  data = {
    :address => params["address"] as String,
    :from    => params["from"] as Int,
    :to      => params["to"] as Int,
    :file    => params["file"] as String,
  }
  redis.hset("rules", SecureRandom.hex, data.to_json)
end

post "/wifi/connected" do |env|
  redis.hgetall("rules").each_slice(2) do |item|
    id, value = item
    next unless value
    case value
    when String
      data = MacaddressConnected::Data.from_json(value)
      rule = MacaddressConnected.new data.address,
        data.from,
        data.to,
        data.file
      rule.process(env.params["address"] as String).run
    else
      next
    end
  end
end
