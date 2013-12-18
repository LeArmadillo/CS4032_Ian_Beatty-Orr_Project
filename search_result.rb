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
  print "HASH: ", hash.abs
  return hash.abs
end

InetAddr = Struct.new(:ip, :port)

class PeerSearchInterface

  def initialize
    @s = nil
    @localInetAddr = nil
    @id = "NILID"
    @guid = "NILGUID"
    @bootstrap_ip = "NILIP"
    @routing_table = {}
    @next_nid = 0
    @m_max = 32     # log2b(L)
    @n_max = 16     # 2b-1
  end

  def init( udp_socket, inetAddr_in )
    @s = udp_socket
    @localInetAddr = inetAddr_in
    self.listenLoop()
  end

  def joinNetwork( gateInetAddr_in, id_in, target_id )
    @localInetAddr = inetAddr_in
    @id = id_in
    @gateInetAddr = gateInetAddr_in
    @guid = Hash_Func( @id )
    @routing_table[@next_nid] = [@m_max][@n_max+1]
    if target_id == nil
      puts @id, "First Node in Network!  Waiting for peers ..."
      return @next_nid
    else
      joinMesg = { :type => "JOINING_NETWORK_SIMPLIFIED", :node_id => @guid, :target_id => Hash_Func( target_id ), \
                   :ip_address => @localInetAddr.ip, :port => @localInetAddr.port }.to_json
      #puts @id, joinMesg
      @s.send joinMesg, 0, @gateInetAddr.ip, @gateInetAddr.port
      return @next_nid
    end
    @next_nid += 1
  end

  def leaveNetwork( network_id )
    if routing_table.empty
      puts "You may not leave the network as you are the sole bootstrap node"
    else
      leaveMesg = { :type => "LEAVING_NETWORK", :node_id => @guid }.to_json
      puts leaveMesg
      @s.send leaveMesg, 0, @localInetAddr.ip, @localInetAddr.port
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
      #puts "I am a thread"
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
      joining_guid = message["node_id"]
      local_guid = @guid.to_s(4)
      joining_guid = joining_guid.to_s(4)
      m = 0
      n = -1
      joining_length = joining_guid.length
      local_length = local_guid.length
      puts local_length, local_guid, joining_length, joining_guid
      while m < local_length && m < joining_length && local_guid[m] == joining_guid[m]
        #puts m
        m += 1
      end
      if m >= local_length && m >= joining_length
        puts "Equivalent GUIDs we shall not add this node to our routing table as it is ME!"
      elsif m < local_length && m >= joining_length
        puts "This has a shorter GUID than me, in the very left it goes: n=0"
        n = 0
      elsif m >= local_length && m < joining_length
        puts "Lets just forget about this one for now"
      elsif
        puts "This is just a plain entry for the routing table"
        n = joining_guid[m] + 1
      end
      if n >= 0
        routing_table[0][m][n] =  { :node_id => message["node_id"], :ip_address => message["ip_address"], \
         :ip_address => message["port"] }
      end
      puts "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5"
      puts @routing_table
    end
    if message["type"] == "JOINING_NETWORK_SIMPLIFIED" || message["type"] == "JOINING_NETWORK_RELAY_SIMPLIFIED"
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

