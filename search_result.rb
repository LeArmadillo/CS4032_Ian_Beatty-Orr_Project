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
  s = nil
  id = "NILID"
  ip = "NILIP"
  guid = "NILGUID"
  bootstrap_ip = "NILIP"
  routing_table = {}

  def self.init( udp_socket, idIn, ipIn, b_ip )
    @s = udp_socket
    @bootstrap_ip = b_ip
    @id = idIn
    @ip = ipIn
    @guid = Hash_Func( @id )
    #@guid = @id
    self.listenLoop()
  end

  def self.joinNetwork( bootstrap_node=PeerSearchInterface::bootstrap_ip )
    if @bootstrap_ip == "NILIP"
      puts "First Node in Network!  Waiting for peers ..."
      return 0
    else
      joinMesg = { :type => "JOINING_NETWORK", :ip_address => bootstrap_node, :node_id => @guid }.to_json
      puts joinMesg
      @s.send joinMesg, 0, "127.0.0.1", 8777
      return 8777
    end
  end

  def self.leaveNetwork( network_id )
    if routing_table.empty
      puts "You may not leave the network as you are the sole bootstrap node"
    else
      leaveMesg = { :type => "LEAVING_NETWORK", :node_id => @guid }.to_json
      puts leaveMesg
      @s.send leaveMesg, 0, "127.0.0.1", 8777
    end

  end

  def self.indexPage( url, unique_words )
    for i in unique_words.length
      wordHash = Hash( unique_words[i] )
      indexMesg = { :type => "INDEX", :node_id => hash, :sender_id => guid , :keyword => unique_words[i],
                    :link => url }.to_json
      #s.puts indexMesg
    end
  end

  def self.search( words )
    for i in words.length
      wordHash = Hash( words[i] )
      searchMesg = { :type => "SEARCH", :word => words[i], :node_id => wordHash, :sender_id => guid }.to_json
      #s.puts searchMesg
    end
    end

  def self.listenLoop()
    x = Thread.new{
      puts "I am a thread"
      i = 0
      while true
        i = i + 1
        puts "Loop", i
        jsonIN = p @s.recv(65536)
        #puts jsonIN
        parsed = JSON.parse(jsonIN)
        self.respond( parsed )
      end
    }
  end

  def self.respond( message )
    if message.type == "JOINING_NETWORK"
      routing_table[node_id] = message.ip_address
    end
    if message.type == "JOINING_NETWORK" or message.type == "JOINING_NETWORK"
      if self.closest( message.node_id ) == guid
        routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => @guid, :node_id => message.node_ID, :ip_address => @ip, \
          :route_table => routing_table }.to_json
        puts routingInfoMesg
        @s.send routingInfoMesg, 0, "127.0.0.1", 8777
      else
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY", :node_id => @message.node_id, :gateway_id => guid }.to_json
        puts joinMesgRelay
        @s.send joinMesgRelay, 0, "127.0.0.1", 8777
      end
    end
  end

  def self.closest( node_id )
    close = guid
    dist = abs( node_id - guid )
    #@routing_table.each_key{
    #  if abs( node_id - key ) < dist
    #    dist = abs( node_id - key )
    #    close = key
    #  end
    #}
    return key
  end

end

