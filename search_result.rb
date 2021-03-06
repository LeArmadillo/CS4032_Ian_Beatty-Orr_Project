require 'json'
require 'socket'

class SearchResult
  words = nil
  url = nil
  frequency = nil
end

InetAddr = Struct.new(:ip, :port)

class PeerSearchInterface
  attr_accessor :name

  def initialize(name_in)
    @name = name_in
    @s = nil
    @localInetAddr = nil
    @id = "NILID"
    @guid = "NILGUID"
    @bootstrap_ip = "NILIP"
    @routing_table = Hash.new #HashWithIndifferentAccess.new
    @gateway_table = {}
    @next_nid = 0
    @m_max = 32     # log2b(L)
    @n_max = 16     # 2b-1
    @b = 4
    @lc = 32
    @lb = 128
  end

  def init( udp_socket, inetAddr_in )
    @s = udp_socket
    @localInetAddr = inetAddr_in
    #puts "PPPPPPPPPPPPPPPPPPPP", @localInetAddr
    self.listenLoop()
  end

  def PaddGUID( guid_in )
    guid_in = guid_in.to_s(4)
    padd_amount = @lc - guid_in.length
    for i in 0..padd_amount-1
      guid_in = "0" + guid_in
    end
    return guid_in
  end

  def Hash_Func( str )
    hash = 0
    i = 0
    while i < str.length
      i = i + 1
      c = str[i]
      hash = hash * 31 + ?c.ord
    end
    #print "HASH: ", hash.abs
    hash = hash.abs
    return PaddGUID( hash )
  end

  def joinNetwork( gateInetAddr_in, id_in, target_id )
    @id = id_in
    @gateInetAddr = gateInetAddr_in
    @guid = Hash_Func( @id )
    for m in 0..@guid.length
      n = @guid[m].to_i
      @routing_table[[0,m,n]] = { :node_id => @guid, :ip_address => @localInetAddr.ip, \
       :port => @localInetAddr.port }
    end
    #puts "ROUTING TABLE HERE WE COME", @next_nid, @routing_table
    #puts @routing_table, nil
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
      #puts leaveMesg
      @s.send leaveMesg, 0, @localInetAddr.ip, @localInetAddr.port
    end

  end

  def indexPage( url, unique_words )
    puts unique_words, unique_words.length
    for i in 0..unique_words.length
      wordHash = Hash_Func( unique_words[i] )
      puts unique_words[i]
      indexMesg = { :type => "INDEX", :target_id => wordHash, :sender_id => @guid , :keyword => unique_words[i],
                    :link => url }.to_json
      nh = nextHop( wordHash )
      s.puts indexMesg, 0, nh.ip, nh.port
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
        puts @name, "Loop", i
        jsonIN = @s.recv(65536)
        puts @name, jsonIN
        parsed = JSON.parse(jsonIN)
        self.respond( parsed )
      end
    }
  end

  def respond( message )
    if message["type"] == "JOINING_NETWORK_SIMPLIFIED"
      #puts "h1"
      target_guid = message["target_id"]
      joining_guid = message["node_id"]
      #puts "h2"
      tm, tn = getMnN( target_guid )
      #puts "h3"
      jm, jn = getMnN( joining_guid )
      #puts "h4"
      @gateway_table[:node_id] =  { :node_id => message["node_id"], :ip_address => message["ip_address"], \
       :ip_address => message["port"] }
      #puts "h5"
      if !@routing_table.has_key?([0,jm,jn]) || diff( joining_guid ) < diff( @routing_table[[0,jm,jn]]["node_id"] )
        #puts "h6"
        @routing_table[[0,jm,jn]] = { :node_id => message["node_id"], :ip_address => message["ip_address"], \
         :port => message["port"] }
      end
      #puts"h7", tm
      if tm < 32
        puts "C"
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :target_id => message["target_id"], :gateway_id => @guid }.to_json
        puts "CD"
        puts @routing_table, tm, tn
        @s.send joinMesgRelay, 0, @routing_table[[0,tm,tn]]["ip_address"], @routing_table[[0,tm,tn]]["port"]
        puts "D"
        #puts @routing_table[0][m][n]["ip_address"], @routing_table[0][m][n]["port"]
      elsif tm == 32
        #puts "F"
        #puts @guid, message["node_id"], @localInetAddr.ip, @localInetAddr.port, @routing_table
        routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => @guid, :node_id => message["node_id"], \
         :ip_address => @localInetAddr.ip, :port => @localInetAddr.port, :route_table => @routing_table }.to_json
        #puts "G"
        @s.send routingInfoMesg, 0, message["ip_address"], message["port"]
        #puts "H"
      else
        puts "M is bigger than 32 ERROR!"
      end
    end


    if message["type"] == "JOINING_NETWORK_RELAY_SIMPLIFIED"
      puts "RELAY"
      target_guid = message["target_id"]
      joining_guid = message["node_id"]
      gateway_guid = message["gateway_id"]
      tm, tn = getMnN( target_guid )
      jm, jn = getMnN( joining_guid )
      nh, gm, gn = nextHop( joining_guid )
      if tm < 32
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :target_id => message["target_id"], :gateway_id => message["gateway_id"] }.to_json
        @s.send joinMesgRelay, 0, @routing_table[[0,tm,tn]]["ip_address"], @routing_table[[0,tm,tn]]["port"]
      elsif tm == 32
        #puts @guid, message["node_id"], @localInetAddr.ip, @localInetAddr.port, @routing_table
        routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => message["gateway_id"], :node_id => message["node_id"], \
         :ip_address => @localInetAddr.ip, :port => @localInetAddr.port, :route_table => @routing_table }.to_json
        @s.send routingInfoMesg, 0, nh.ip, nh.port
      else
        puts "M is bigger than 32 ERROR!"
      end
    end

    if message["type"] == "ROUTING_INFO"
      gateway_guid = message["gateway_id"]
      if message["node_id"] == @guid
        puts "RIM is at the JN"
        art = message["route_table"]
        puts art.length
        for addr in art.keys

          addr2 = addr.gsub('[', '')
          addr2 = addr2.gsub(']', '')
          c = addr2.split(', ')
          c0 = c[0].to_i
          c1 = c[1].to_i
          c2 = c[2].to_i
          addr = [c0,c1,c2]
          if !@routing_table.has_key?(addr) || diff( joining_guid ) < diff( @routing_table[addr]["node_id"] )
            puts "h6"
            @routing_table[addr] = { :node_id => message["node_id"], :ip_address => message["ip_address"], \
             :port => message["port"] }
            puts "h7"
          end
          #Hash[@routing_table.map{ |k, v| [k.to_sym, v] }]
        end
        #puts @routing_table

      else
        nh, gm, gn = nextHop( gateway_guid )
      end
    end



=begin
    if message["type"] == "JOINING_NETWORK_RELAY_SIMPLIFIED"
        target_guid = message["target_id"]
        local_guid = @guid
        m = 0
        n = -1
        puts local_guid, target_guid
        while local_guid[m] == target_guid[m]
          #puts m
          m += 1
        end
        if m < 32
          n = target_guid[m]
          joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :target_id => message["target_id"], :gateway_id => message["gateway_id"] }.to_json
          @s.send joinMesgRelay, 0, @routing_table[0][m][n]["ip_address"], @routing_table[0][m][n]["port"]

          if( diff(joining_guid) < diff( padd_GUID( @routing_table[0][m][n]["node_id"] ) ) )
            routing_table[0][m][n] =  { :node_id => message["node_id"], :ip_address => message["ip_address"], \
           :ip_address => message["port"] }
          end
        elsif m == 32
          routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => message["gateway_id"], :node_id => message["node_id"], \
           :ip_address => @localInetAddr.ip, :route_table => routing_table }.to_json
          nh = nextHop( message["gateway_id"] )
          @s.send routingInfoMesg, 0, nh.ip, nh.port
        else
          puts "M is begger than 32 ERROR!"
        end
      end
=end

  end




  def nextHop( target_id )
    m = 0
    n = -1
    #puts @guid, target_id
    while @guid[m] == target_id[m] && m < @m_max
      #puts m
      m += 1
    end
    n = target_id[m].to_i
    print name, "nextHop"
    #puts @routing_table
    return InetAddr.new( @routing_table[[0,m,n]]["ip_address"], @routing_table[[0,m,n]]["port"] ), m, n
  end

  def getMnN( target_id )
    m = 0
    n = -1
    #puts @guid, target_id
    while @guid[m] == target_id[m] && m < @m_max
      #puts m
      m += 1
    end
    n = target_id[m].to_i
    return m, n
  end


  def diff( node_guid )
    #puts @guid, node_guid
    iGuid = @guid.to_i
    iNodeGuid = node_guid.to_i
    t = iGuid - iNodeGuid
    return t.abs
  end

=begin
  def diff( node_id )
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
=end

end

