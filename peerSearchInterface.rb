require 'json'
require 'socket'

class SearchResult
  words = nil
  url = nil
  frequency = nil
end

InetAddr = Struct.new(:ip, :port)
NodeAddr = Struct.new(:guid, :ip, :port)

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
    @linkHash = []
    @indexInProgress = false
    @searchInProgress = false
    @searchAckWait = {}
    @indexAckWait = {}
  end

  def init( udp_socket, inetAddr_in )
    @s = udp_socket
    self.listenLoop()
    @localInetAddr = inetAddr_in
    #puts "PPPPPPPPPPPPPPPPPPPP", @localInetAddr
  end


  def PaddGUID( guid_in )
    guid_in = guid_in.to_s(16)
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
      c = str[i]
      hash = hash * 31 + c.ord
      i = i + 1
    end
    #print "HASH: ", hash.abs
    hash = hash.abs
    return PaddGUID( hash )
  end

  def nextHop( target_id )
    m = 0
    n = -1
    puts @guid, target_id
    while @guid[m] == target_id[m] && m < @m_max
      #puts m
      m += 1
    end
    #puts "YOO"
    n = target_id[m]
    #puts n
    n = n.to_s
    #puts n
    n = n.hex
    #puts n
    #g = target_id[m]
    #g = g.to_s
    #l = 'e'
    #puts "YOO", l, l.hex, g, g.hex
    #sss = "1010"
    #puts l.to_i(16).to_s(10)
    #puts s.convert_base(2, 10)
    #puts l
    #l = l.to_s
    #puts l.convert_base(16, 10)
    #puts l, l.hex
    #puts l.hex
    puts name, "nextHop", m, n#, target_id[m].to_i, target_id[m].hex
    #puts @routing_table #,@routing_table[[0,m,n]], @routing_table[[0,m,n]][:ip_address], @routing_table[[0,m,n]][:port]
    if @routing_table[[0,m,n]] != nil
      #puts "aa"
      return InetAddr.new( @routing_table[[0,m,n]][:ip_address], @routing_table[[0,m,n]][:port] ), m, n
    else
      #puts "bb"
      shortestDistance = dist( target_id, @guid )
      #puts "cc"
      nh = InetAddr.new()
      @routing_table.each do |key, array|
        if dist( target_id, array[:node_id] ) < shortestDistance && dist( target_id, array[:node_id] ) != 0
          shortestDistance = dist( target_id, array[:node_id] )
          nh.ip = array[:ip_address]
          nh.port = array[:port]
        end
      end
      #puts "ee"
      return nh, m, n
    end
  end

  def nextCheckHop( target_id )
    m = 0
    n = -1
    #puts @guid, target_id
    while @guid[m] == target_id[m] && m < @m_max
      #puts m
      m += 1
    end
    n = target_id[m].to_i
    #puts name, "nextHopCheck"
    #puts @routing_table
    return NodeAddr.new( @routing_table[[0,m,n]]["node_id"], @routing_table[[0,m,n]]["ip_address"], @routing_table[[0,m,n]]["port"] ), m, n
  end

  def getMnN( target_id )
    m = 0
    n = -1
    #puts @guid, target_id
    while @guid[m] == target_id[m] && m < @m_max
      #puts m
      m += 1
    end
    #puts "YOO"
    n = target_id[m]
    #puts n
    n = n.to_s
    #puts n
    n = n.hex
    #puts n
    #g = target_id[m]
    #g = g.to_s
    #l = 'e'
    #puts "YOO", l, l.hex, g, g.hex
    #sss = "1010"
    #puts l.to_i(16).to_s(10)
    #puts s.convert_base(2, 10)
    #puts l
    #l = l.to_s
    #puts l.convert_base(16, 10)
    #puts l, l.hex
    #puts l.hex
    #puts name, "nextHop", m, n#, target_id[m].to_i, target_id[m].hex
    #puts @routing_table #,@routing_table[[0,m,n]], @routing_table[[0,m,n]][:ip_address], @routing_table[[0,m,n]][:port]
    return m, n
  end


  def diff( node_guid )
    #puts @guid, node_guid
    iGuid = @guid.hex
    iNodeGuid = node_guid.hex
    t = iGuid - iNodeGuid
    return t.abs
  end

  def dist( guid_1, guid_2 )
    #puts "D1"
    guid_1 = guid_1.hex
    #puts "D2"
    guid_2 = guid_2.hex
    #puts "D3"
    t = guid_1 - guid_2
    #puts "D4"
    return t.abs
  end

  def halfDiff( node_id )
    half_id = node_id.dup #
    #puts "d1", half_id, node_id
    m = 0
    #puts "d3"
    while @guid[m] == node_id[m] && m < @m_max
      m += 1
    end
    #puts "d4"
    if m > 30
      return -1
    end
    #puts "d5"
    #if node_id[m] > @guid[m]
    #  puts "d6a"
    #  half_id[m] = (node_id[m].to_i + 1).to_s
    #  puts "d6af"
    #elsif node_id[m] < @guid[m]
    #  puts "d6b"
    #  half_id[m] = (node_id[m].to_i - 1).to_s
    #else
    #  puts "d6c"
    #  puts "halfDiff Error"
    #end
    #puts "d6.5a"
    m += 1
    half_id[m] = "8"
    #puts "d6.5b"
    m += 1
    #puts "d7"
    #puts node_id, half_id, m, @m_max
    while m < @m_max
      #puts m
      half_id[m] = "0"
      m += 1
    end
    #puts "d8"
    #puts "d4", half_id.hex, node_id.hex
    t = half_id.hex - node_id.hex
    #puts "d9", t.abs, half_id, node_id
    return t.abs
  end

  def strToSym( str )
    #puts "a", str
    str = str.gsub('[', '')
    #puts "b"
    sym = sym.gsub(']', '')
    #puts "c"
    c = sym.split(', ')
    #puts "d"
    c0 = c[0].to_i
    #puts "e"
    c1 = c[1].to_i
    #puts "f"
    c2 = c[2].to_i
    #puts "g"
    return [c0,c1,c2]
  end


  def useRouteInfo( routeTable )
    for addr in routeTable
      #puts "NNNNNNNNNNNNNNNNNNNNNNNN"
      #puts addr
      addr2 = { :node_id => addr["node_id"], :ip_address => addr["ip_address"], :port => addr["port"] }
      #puts addr2
      #puts "?????????"
      #puts addr, @routing_table
      m, n = getMnN(addr["node_id"])
      if @routing_table.has_value?(addr)
        #puts "@@@@@@@@@@@@@"
        #puts halfDiff( addr["node_id"] )
        #puts halfDiff( @routing_table[[0,m,n]]["node_id"] )
        if halfDiff( @routing_table[[0,m,n]]["node_id"] ) < halfDiff( @routing_table[[0,m,n]]["node_id"] )
          #puts "CCCCCCCCCCCCCCCCCCC"
          @routing_table[[0,m,n]] = addr2
        end
      else
        #puts "XXXXXXXXXXXX"
        @routing_table[[0,m,n]] = addr2
      end
    end
  end

  def removeAddr( node_id )
    for addr in @routing_table.keys
      if @routing_table[addr]["node_id"] == node_id
        @routing_table.delete([addr])
      end
    end
  end

  # Send message to all nodes in routing table of node except messages with the node ID contain in <from>
  # <from> may be nil for a true broadcast
  def sendBroadCast( from, mesg )
    for addr in @routing_table.keys
      if @routing_table[addr]["node_id"] != from
        @s.send mesg, 0, @routing_table[addr]["ip_address"], @routing_table[addr]["port"]
      end
    end
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
      #puts "EE", @guid, id_in, target_id, Hash_Func( target_id ), @gateInetAddr.ip, @gateInetAddr.port
      joinMesg = { :type => "JOINING_NETWORK_SIMPLIFIED", :node_id => @guid, :target_id => Hash_Func( target_id ), \
                   :ip_address => @localInetAddr.ip, :port => @localInetAddr.port }.to_json
      #puts @id, joinMesg, @gateInetAddr
      @s.send joinMesg, 0, @gateInetAddr.ip, @gateInetAddr.port
      #puts "TTTTTTTTTTTTT"
      return @next_nid
    end
    @next_nid += 1
  end

  def leaveNetwork( network_id )
    if routing_table.empty
      puts "You may not leave the network as you are the sole bootstrap node"
    else
      leaveMesg = { :type => "LEAVING_NETWORK", :node_id => @guid }.to_json
      sendBroadCast( nil, leaveMesg )
    end

  end

  def indexPage( url, unique_words )
    y = unique_words.length - 1
    for i in 0..y
      Thread.new(i){ |i2|
        wordHash = Hash_Func( unique_words[i2] )
        while @indexAckWait != nil && ( @indexAckWait[ wordHash ] == 1 || @indexAckWait[ wordHash ] == 2 )
        end
        @indexAckWait[ wordHash ] = 1
        indexMesg = { :type => "INDEX", :target_id => wordHash, :sender_id => @guid , :keyword => unique_words[i2],
                      :link => url }.to_json
        nh, m, n = nextHop( wordHash )
        if wordHash == @guid
          indexMesg = JSON.parse( indexMesg )
          respond( indexMesg )
          return
        end
        @s.send indexMesg, 0, nh.ip, nh.port
        t = Time.now.sec
        t2 = t + 20
        while t < t2
          if @indexAckWait[ wordHash ] == 2
            break
          end
          k = Time.now.sec
          if k != t
            t += 1
          end
        end
        puts name, "EXITING", t, @indexAckWait
        if @indexAckWait[ wordHash ] != 2
          puts "THHH"
          routeChecker( wordHash )
        else
          puts "We are NOT calling routeChecker"
        end
        @indexAckWait[ wordHash ] = 0
      }
    end
  end

  def search( unique_words )
    puts "AAAA"
    Thread.new{
      puts "BBBB"
      wordHash = []
      tempResults = {}
      list = {}
      y = unique_words.length - 1
      for i in 0..y
        puts "CCCC"
        Thread.new(i){ |i2|
          puts "DDDD"
          wordHash[i2] = Hash_Func( unique_words[i2] )
          while @searchAckWait != nil && ( @searchAckWait[ wordHash[i2] ] == 1 || @searchAckWait[ wordHash[i2] ].kind_of?(Array) )
          end
          puts "EEEE"
          @searchAckWait[ wordHash[i2] ] = 1
          puts "HJKL:"
          #puts unique_words[i]
          searchMesg = { :type => "SEARCH", :word => unique_words[i2], :node_id => wordHash[i2], :sender_id => @guid }.to_json
          nh, m, n = nextHop( wordHash[i2] )
          puts "FFFF"
          puts searchMesg, nh
          @s.send searchMesg, 0, nh.ip, nh.port
          puts "GGGG"
          t = Time.now.sec
          t2 = t + 10
          #puts @searchAckWait
          #puts @searchAckWait[ wordHash[i2] ]
          if @searchAckWait[ wordHash[i2] ].kind_of?(Array)
            puts "Yarp"
          else
            puts "Narp"
          end
          puts "EndCap"
          while t < t2
            #puts "HHHH"
            if @searchAckWait[ wordHash[i2] ].kind_of?(Array)
              puts "IIII"
              tempResults[ wordHash[i2] ] = @searchAckWait[ wordHash[i2] ]
              break
            end
            t = Time.now.sec
            if t < t2 - 10
              t = t + 60
            end
          end
          if !@searchAckWait[ wordHash[i2] ].kind_of?(Array)
            puts "The Search has failed time to check the route"
            routeChecker( wordHash[i2] )
          end
          @searchAckWait[ wordHash[i2] ] = 0
        }
      end
      t3 = Time.now.sec
      t4 = t3 + 3
      while t3 < t4
        t3 = Time.now.sec
        if t3 < t4 - 3
          t3 = t3 + 60
        end
      end
      puts "JJJJ"
      list = tempResults[ wordHash[0] ]
      puts wordHash
      for j in 1..wordHash.length-1
        puts "KKKK"
        nList = tempResults[ wordHash[j] ]
        list.each { |h|
          nLish.any? { |nH|
            if nH[:url] == h[:url]
              if nH[:rank] < h[:rank]
                h[:rank] = nH[:rank]
              end
            else
              list.pop[h]
            end
          }
        }
      end
      puts "Now all you have to do is figure out how to returna  search results class woo hoo!"
      # SEARCH ALGORITHM
    }
  end

  def routeChecker( target_id )
    Thread.new{
      pingMesg = { :type => "PING", :target_id => target_id, :sender_id => @guid, :ip_address => @localInetAddr.ip }.to_json
      nh = nextCheckHop( target_id )
      @s.send pingMesg, 0, nh.ip, nh.port
      t = now.seconds
      @checkAckWait[ wordHash ] = 0
      while t < t + 10
        if @checkAckWait[ wordHash ] == 2
          break
        end
      end
      removeAddr( nh.guid )
    }
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
    #puts "respond"
    if message["type"] == "JOINING_NETWORK_SIMPLIFIED"
      #puts "h1"
      tnh, tm, tn = nextHop( message["node_id"] )
      #puts "h2"
      @gateway_table[message["node_id"]] =  { :ip_address => message["ip_address"], :port => message["port"] }
      #puts "h3"
      if @routing_table.has_key?([0,tm,tn]) == false # || diff( joining_guid ) < diff( @routing_table[[0,jm,jn]]["node_id"] )
        #puts "h6"
        @routing_table[[0,tm,tn]] = { :node_id => message["node_id"], :ip_address => message["ip_address"], \
         :port => message["port"] }
      end
      #puts"h7"
      if tnh.ip != nil
        #puts "C"
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :target_id => message["target_id"], :gateway_id => @guid, :ip_address => message["ip_address"], \
         :port => message["port"] }.to_json
        #puts "CD"
        @s.send joinMesgRelay, 0, tnh.ip, tnh.port
      end
      #puts "F"
      #puts @guid, message["node_id"], @localInetAddr.ip, @localInetAddr.port, @routing_table
      tempRouteTable = []
      @routing_table.each_value { |addr|
        tempRouteTable.push( addr )
      }
      #puts "LLLL", message, tempRouteTable
      routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => @guid, :node_id => message["node_id"], \
       :ip_address => @localInetAddr.ip, :port => @localInetAddr.port, :route_table => tempRouteTable }.to_json
      #puts "G"
      #puts routingInfoMesg, message["ip_address"], message["port"]
      @s.send routingInfoMesg, 0, message["ip_address"], message["port"]
      #puts "H"
    end

=begin
    def respond( message )
      if message["type"] == "JOINING_NETWORK_SIMPLIFIED"
        puts "h1"
        tnh, tm, tn = nextHop( message["target_guid"] )
        jm, jn = getMnN( message["joining_guid"] )
        @gateway_table[message["node_id"]] =  { :ip_address => message["ip_address"], :port => message["port"] }
        if @routing_table.has_key?([0,jm,jn]) == false # || diff( joining_guid ) < diff( @routing_table[[0,jm,jn]]["node_id"] )
                                                       #puts "h6"
          @routing_table[[0,jm,jn]] = { :node_id => message["node_id"], :ip_address => message["ip_address"], \
         :port => message["port"] }
        end
        #puts"h7", tm
        if tm < 32
          puts "C"
          joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :target_id => message["target_id"], :gateway_id => @guid }.to_json
          #puts "CD"
          @s.send joinMesgRelay, 0, tnh.ip, tnh.port
        elsif tm == 32
          puts "F"
          #puts @guid, message["node_id"], @localInetAddr.ip, @localInetAddr.port, @routing_table
          tempRouteTable = []
          @routing_table.each_value { |addr|
            tempRouteTable.push( addr )
          }
          #puts "LLLL", message, tempRouteTable
          routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => @guid, :node_id => message["node_id"], \
         :ip_address => @localInetAddr.ip, :port => @localInetAddr.port, :route_table => tempRouteTable }.to_json
          puts "G"
          puts routingInfoMesg, message["ip_address"], message["port"]
          @s.send routingInfoMesg, 0, message["ip_address"], message["port"]
          puts "H"
        else
          puts "M is bigger than 32 ERROR!"
        end
      end
=end


    if message["type"] == "JOINING_NETWORK_RELAY_SIMPLIFIED"
      #puts "RELAY"
      tnh, tm, tn = nextHop( message["node_id"] )
      #puts "II"
      nh, gm, gn = nextHop( message["gateway_id"] )
      #puts "JJ"
      #puts tnh
      if @routing_table.has_key?([0,tm,tn]) == false # || diff( joining_guid ) < diff( @routing_table[[0,jm,jn]]["node_id"] )
                                                     #puts "h6"
        @routing_table[[0,tm,tn]] = { :node_id => message["node_id"], :ip_address => message["ip_address"], \
         :port => message["port"] }
      end
      if tnh.ip != nil
        #puts "R4"
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :target_id => message["target_id"], :gateway_id => message["gateway_id"], \
          :ip_address => message["ip_address"], :port => message["port"] }.to_json
        @s.send joinMesgRelay, 0, tnh.ip, tnh.port
      end
      #puts "R5"
      tempRouteTable = []
      @routing_table.each_value { |addr|
        tempRouteTable.push( addr )
      }
      #puts "RRRRRRRRRRRRR", nh, @guid, message["node_id"], @localInetAddr.ip, @localInetAddr.port#, @routing_table
      routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => message["gateway_id"], :node_id => message["node_id"], \
       :ip_address => @localInetAddr.ip, :port => @localInetAddr.port, :route_table => tempRouteTable }.to_json
      #puts "R7", nh, routingInfoMesg
      @s.send routingInfoMesg, 0, nh.ip, nh.port
      #puts "R8"
    end

    if message["type"] == "ROUTING_INFO"
      #puts "HHHHHHHDDDDDDDDDGGGGGGGGGGGGGG"
      #addAddr( message["sending_id"], message["node_id"], message["node_id"] )
      useRouteInfo( message["route_table"] )
      #puts "Y"
      #puts "YYY", @guid, message["gateway_id"], message["node_id"], @gateway_table
      if message["node_id"] == @guid
        #puts "SSSSSSSSSSAAAAAAAAAAAAA"
        return
      elsif message["gateway_id"] == @guid
        #puts "x"
        if @gateway_table.has_key?( message["node_id"] )
          #puts "y"
          p @s.send message.to_json, 0, @gateway_table[message["node_id"]][:ip_address].to_s, @gateway_table[message["node_id"]][:port]
          #puts "yy"
        else
          puts "Routing_Info message receave error not key in gatewayTable!"
        end
      else
        #puts "z"
        nh, gm, gn = nextHop( message["node_id"] )
        #puts "l", nh
        message = message.to_json
        #puts "?"
        @s.send message, 0, nh.ip, nh.port
        #@s.send message, 0, "127.0.0.1", 8777
        #puts "j"
      end
      #puts "AAAAAAAAAAAAAAASSSSSSSSSSSSS"
    end

    if message["type"] == "LEAVING_NETWORK"
      removeAddr( message["node_id"])
    end

    if message["type"] == "INDEX"
      #puts "INDEX IN"
      if message["target_id"] == @guid
        #puts "i"
        flag = true
        for i in 0..@linkHash.length-1
          #puts "w"
          if @linkHash[i][:url] == message["link"]
            #puts "e"
            @linkHash[i][:rank] += 1
            flag = false
          end
        end
        if flag
          #puts "6t"
          @linkHash << { :url => message["link"], :rank => 0 }
          #puts "6tc"
        end
        #puts "ie"
        #puts "i1b"
        ackIndexMesg = { :type => "ACK_INDEX", :node_id => message["sender_id"], :keyword => message["keyword"] }.to_json
        #puts "uhb"
        if message["sender_id"] == @guid
          puts "OWN INDEXING returning"
          return
        end
        nh, sm, sn = nextHop( message["sender_id"] )
        puts "hjg", nh
        @s.send ackIndexMesg, 0, nh.ip, nh.port
        #puts "loo"
      else
        puts "i2"
        nh, tm, tn = nextHop( message["target_id"] )
        puts "HUYI", nh
        @s.send message.to_json, 0, nh.ip, nh.port
        puts "i2f"
      end
    end

    if message["type"] == "ACK_INDEX"
      #puts "YOLO"
      if message["node_id"] == @guid
        #puts "Y"
        wordHash = Hash_Func( message["keyword"] )
        @indexAckWait[ wordHash ] = 2
        #puts "HELLO", name, @indexAckWait
      else
        #puts "Hop"
        nh = nextHop( message["node_id"] )
        @s.send message.to_json, 0, nh.ip, nh.port
      end
    end

    if message["type"] == "SEARCH"
      puts "Sa"
      if message["node_id"] == @guid
        puts "Sb"
        puts @linkHash
        puts "Scccc"
        searchResponceMesg = { :type => "SEARCH_RESPONSE", :word => message["word"], :node_id => message["sender_id"],
                               :sender_id => @guid, :response => @linkHash }.to_json
        puts "Sb.4"
        nh, sm, sn = nextHop( message["sender_id"] )
        puts "Sb.5", nh
        @s.send searchResponceMesg, 0, nh.ip, nh.port
        puts "Sbb"
      else
        puts "Sc"
        nh, tm, tn = nextHop( message["node_id"] )
        puts "Sc2"
        puts nh
        message = message.to_json
        @s.send message, 0, nh.ip, nh.port
        puts "Sc3"
      end
    end

    if message["type"] == "SEARCH_RESPONSE"
      if message["node_id"] == @guid
        @searchAckWait["node_id"] = message["response"]
      else
        nh, tm, tn = nextHop( message["node_id"] )
        @s.send message.to_json, 0, nh.ip, nh.port
      end
    end

    if message["type"] == "ACK"
      if message["node_id"] == @guid
        @checkAckWait[ node_id ] = 2
      else
        nh = nextHop( message["node_id"] )
        @s.send message.to_json, 0, nh.ip, nh.port
      end
    end


  end
end

