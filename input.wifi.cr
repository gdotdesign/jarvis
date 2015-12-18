require "./jarvis-wifi/*"
#require "ssh2"
require "process"
require "http/client"

module Jarvis::Wifi
  class Api
    getter server_list

    def initialize
      @server_list = [ "10.11.1.251",                                                                                                                                                   [42/170]
                       "10.11.1.252",
                       "10.11.1.253" ]
      @raw_results = ""
      @old_macs = [] of String
      @new_macs = [] of String
    end

    def process
      query
      reset_new_macs
      get_macs
      if @old_macs.size > 0
        mac_added
        mac_removed
      end
      update_macs
      timeout_process
    end

    def query
      jarvis_io = MemoryIO.new("")
      server_list.each do |ip|
        args = "-p Cx3I23wa ssh api@10.11.1.251 /interface wireless registration-table print".split(" ")
        Process.run("sshpass", args: args, output: jarvis_io, error: STDOUT)
      end
      jarvis_io.rewind
      @raw_results = jarvis_io.gets_to_end
    end

    def reset_new_macs
      @new_macs = [] of String
    end

    def get_macs
      puts "Getting mac addresses"
      @raw_results.split("\n").each do |row|
        row.match(/[\w\d]{2}:[\w\d]{2}:[\w\d]{2}:[\w\d]{2}:[\w\d]{2}:[\w\d]{2}/) { |m| @new_macs << m[0] }
      end
    end

    def mac_added
      #puts @new_macs
      macs = (@new_macs - @old_macs).uniq
      puts "Macs added #{macs}"
      macs.each do |mac|
        puts "Posting  mac address as added #{mac}"
        headers = "application/json"
        body = "{\"address\": \"#{mac}\" }"
        client = HTTP::Client.new("10.11.1.103", port: 3000)
        client.post("/wifi/connected", headers: HTTP::Headers{"Content-Type": "application/json"}, body: body) do |response|
          puts response.status_code
          #puts response.body.lines.first
        end
      end
    end

    def mac_removed
      macs = (@old_macs - @new_macs).uniq
      puts "Macs removed #{(macs)}"
      macs.each do |mac|
        puts "Posting  mac address as added #{mac}"
        headers = "application/json"
        body = "{\"address\": \"#{mac}\" }"
        client = HTTP::Client.new("10.11.1.103", port: 3000)
        client.post("/wifi/disconnected", headers: HTTP::Headers{"Content-Type": "application/json"}, body: body) do |response|
          puts response.status_code
        end
      end
    end

    def update_macs
      @old_macs = @new_macs
    end

    def timeout_process
      sleep 3
      process
    end

  end
end

api = Jarvis::Wifi::Api.new
api.process
