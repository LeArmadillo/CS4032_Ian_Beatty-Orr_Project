require 'json'
require 'socket'

class SearchResult
  words = nil
  url = nil
  frequency = nil
end

def Hash_Func( str )
  hash = 0
  i = 0
  while i < str.length
    i = i + 1
    c = str[i]
    hash = hash * 31 + ?c.ord
  end
  return hash.abs
end

class PeerSearchInterface

  def initialize
    @s = nil
    @id = "NILID"
    @port = nil
    @ip = "NILIP"
    @guid = "NILGUID"
    @bootstrap_ip = "NILIP"
    @routing_table = {}
    @nid = 0
  end

  def init( udp_socket )
    @s = udp_socket
    self.listenLoop()
  end

  def joinNetwork( ip_in, port_in, id_in, target_id )
    @nid += 1
    @id = id_in
    @ip = ip_in
    @guid = Hash_Func( @id )
    @port = port_in
    if target_id == nil
      puts @id, "First Node in Network!  Waiting for peers ..."
      return @nid
    else
      joinMesg = { :type => "JOINING_NETWORK_SIMPLIFIED", :node_id => @guid, :target_id => Hash_Func( target_id ), \
                   :ip_address => @ip }.to_json
      puts @id, joinMesg
      @s.send joinMesg, 0, @ip, @port
      return @nid
    end
  end

  def leaveNetwork( network_id )
    if routing_table.empty
      puts "You may not leave the network as you are the sole bootstrap node"
    else
      leaveMesg = { :type => "LEAVING_NETWORK", :node_id => @guid }.to_json
      puts leaveMesg
      @s.send leaveMesg, 0, @ip, @port
    end

  end

  def indexPage( url, unique_words )
    for i in unique_words.length
      wordHash = Hash( unique_words[i] )
      indexMesg = { :type => "INDEX", :node_id => @hash, :sender_id => @guid , :keyword => @unique_words[i],
                    :link => url }.to_json
      #s.puts indexMesg
    end
  end

  def search( words )
    for i in words.length
      wordHash = Hash( words[i] )
      searchMesg = { :type => "SEARCH", :word => words[i], :node_id => wordHash, :sender_id => guid }.to_json
      #s.puts searchMesg
    end
    end

  def listenLoop()
    x = Thread.new{
      puts "I am a thread"
      i = 0
      while true
        i = i + 1
        puts "Loop", i
        jsonIN = p @s.recv(65536)
        puts jsonIN
        parsed = JSON.parse(jsonIN)
        self.respond( parsed )
      end
    }
  end

  def respond( message )
    if message["type"] == "JOINING_NETWORK_SIMPLIFIED"
      @routing_table[:message["node_id"]] = message["ip_address"]
    end
    if message["type"] == "JOINING_NETWORK_SIMPLIFIED" || message.type == "JOINING_NETWORK_RELAY_SIMPLIFIED"
      if self.closest( message["node_id"] ) == @guid
        puts "LLLLLL"
        routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => @guid, :node_id => message["node_id"], \
         :ip_address => @ip, :route_table => routing_table }.to_json
        puts routingInfoMesg
        @s.send routingInfoMesg, 0, @ip, @port
      else
        puts "MMMMMM"
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
        :target_id => message["target_id"], :gateway_id => @guid }.to_json
        puts joinMesgRelay
        @s.send joinMesgRelay, 0, @ip, @port
      end
    end
  end

  def closest( node_id )
    close = @guid
    dist = node_id - @guid
    dist = dist.abs
    puts ":", @routing_table
    @routing_table.each_key{ |key|
      puts key, "loo"
      lll = node_id - key
      puts "boo"
      if lll.abs < dist
        puts "doo"
        dist = ( node_id - key ).abs
        close = key
      end
    }
    puts "mango"
    return guid
  end

end

