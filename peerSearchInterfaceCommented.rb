require 'json'
require 'socket'

# Class that returns search results
class SearchResult
  words = nil
  result = nil
end

InetAddr = Struct.new(:ip, :port)         # Struct for inetAddr
NodeAddr = Struct.new(:guid, :ip, :port)  # Same as above but including GUID

class PeerSearchInterface
  attr_accessor :name

  # Initialization of variables
  def initialize(name_in)
    @name = name_in                       # Stores the name of the node
    @s = nil                              # Socket
    @localInetAddr = nil                  # IP & port of node
    @id = "NILID"                         # plain text ID
    @guid = "NILGUID"                     # GUID has of ID
    @routing_table = Hash.new             # Stores all of the routing information as 3D hash [R,M,N]
                                          # R specifies the network hence a node could theoretically be a member
                                          # of several networks although that functionality has not been implemented
                                          # M specifies the height of the routing table, all IDs are 128 bits long
                                          # the GUIDs use hex digits hence each digit is 4 bits long
                                          # hence there are 32 digits in a GUID hence M = 32
                                          # N is the possible values of each digit as we are using hex N = 16
                                          # This routing table functions as the Pasty routing table does without
                                          # Leaf or neighbourhood sets
    @m_max = 32                           # log2b(L)
    @n_max = 16                           # 2^b
    @b = 4                                # hex
    @lc = 32
    @lb = 128                             # bit length of GUID
    @gateway_table = {}                   # Stores a newly joining node for which this node is the gateway node
                                          # while its routing information is initialised
    @next_nid = 0                         # the internally generated network ID
    @linkHash = []                        # Stores all URLs found to have a word with hash equal to our GUID
                                          # Stores as an array of hashes:
                                          # [ {:url => www.A.url, :rank => 1}, {:url => www.B.url, :rank => 5} ]
    @indexInProgress = false              # flag to ensure two index messages to the same node can not be sent
    @searchInProgress = false             # flag to ensure two search messages to the same node can not be sent
    @searchAckWait = {}                   # Hash to temporarily store search responce info
    @indexAckWait = {}                    # Hash to temporarily store index ACK info
    @checkAckWait = {}                    # Hash to temporarily store ping ACK info
    @netWorkMember = false                # flag to check if node is a member of network, resets to false when we leave
  end

  # Initialization of node
  def init( udp_socket, inetAddr_in )
    @s = udp_socket                       # Assign socket
    self.listenLoop()                     # Set up a new thread to listen for incoming messages
    @localInetAddr = inetAddr_in          # Store our local address
  end

  # Hash_Funct (below) creates variable length GUIDs, calls this function which pads them out to 32 hex digits
  # Adds extra "0"s to the start of the string
  def PaddGUID( guid_in )
    guid_in = guid_in.to_s(16)
    padd_amount = @lc - guid_in.length
    for i in 0..padd_amount-1
      guid_in = "0" + guid_in
    end
    return guid_in
  end

  # Takes in a string and converts it to a hex GUID, calls PaddGUID (above) to padd out to 32 hex bits
  def Hash_Func( str )
    hash = 0
    i = 0
    while i < str.length
      c = str[i]
      hash = hash * 31 + c.ord
      i = i + 1
    end
    hash = hash.abs
    return PaddGUID( hash )
  end

  # This find the next hop for a message and is based on the PASTRY paper
  # It reads through all characters in both GUIDs to find the first differing one and sets this digits location as M
  # N is the value of the target_id (actually a GUID) at this digit
  def nextHop( target_id )
    m = 0
    n = -1
    while @guid[m] == target_id[m] && m < @m_max
      m += 1
    end
    n = target_id[m]
    n = n.to_s
    n = n.hex
    # Once we have M and N we check the routing table at that location to see if we have an entry
    # This entry will be once digit closer than the current nodes GUID
    if @routing_table[[0,m,n]] != nil
      return InetAddr.new( @routing_table[[0,m,n]][:ip_address], @routing_table[[0,m,n]][:port] ), m, n
    # If not we search the entire routing table for the entry with the GUID closest to the target_id
    else
      shortestDistance = dist( target_id, @guid )       # distance between ourself and target
                                                        # we will only send message on if there is a closer address
      nh = InetAddr.new()
      @routing_table.each do |key, array|               # Access each element of routing table
                                                        # IF it is less than out distance to target set it as shortest
        if dist( target_id, array[:node_id] ) < shortestDistance && dist( target_id, array[:node_id] ) != 0
          shortestDistance = dist( target_id, array[:node_id] )
          nh.ip = array[:ip_address]
          nh.port = array[:port]
        end
      end
      return nh, m, n
      # Function returns an InetAddr struct as well as M and N
    end
  end

  # Identical to above function but also return the GUID of next hop node
  def nextCheckHop( target_id )
    nh, m, n = nextHop( target_id )
    return NodeAddr.new( @routing_table[[0,m,n]][:node_id], nh.ip, nh.port ), m, n
  end

  # Shortened version of nextHop for when we are only interested in getting M and N
  def getMnN( target_id )
    m = 0
    n = -1
    while @guid[m] == target_id[m] && m < @m_max
      m += 1
    end
    n = target_id[m]
    n = n.to_s
    n = n.hex
    return m, n
  end

  # The difference between our GUID and another GUID
  def diff( node_guid )
    iGuid = @guid.hex
    iNodeGuid = node_guid.hex
    t = iGuid - iNodeGuid
    return t.abs
  end

  # The difference between two different GUIDs that are not our own
  def dist( guid_1, guid_2 )
    guid_1 = guid_1.hex
    guid_2 = guid_2.hex
    t = guid_1 - guid_2
    return t.abs
  end

  # This function returns the difference between a nodes GUID and the GUID that would be half way between
  # our GUID and a GUID with the differing digit being one higher or lower depending on weather the target GUID is
  # higher or lower than this nodes GUID
  # For instance our GUID is 234862, node_id is 234438
  # Less hence the entry it lies in relates to GUIDs with 234400
  # GUID half we between 234400 and our 234862 is 234631
  # return the distance between 234631 and node_id
  # # If the GUID were larger than ours say 234978 we would have used 234a00 to find the half way distance
  # # a.k.a. 234981
  def halfDiff( node_id )
    half_id = node_id.dup # Need to hard copy
    m = 0
    while @guid[m] == node_id[m] && m < @m_max
      m += 1
    end
    if m > 30
      return -1
    end
    m += 1
    half_id[m] = "8"
    m += 1
    while m < @m_max
      half_id[m] = "0"
      m += 1
    end
    t = half_id.hex - node_id.hex
    return t.abs
  end

  # Converts a string to symbol for hashing purposes
  def strToSym( str )
    str = str.gsub('[', '')
    sym = sym.gsub(']', '')
    c = sym.split(', ')
    c0 = c[0].to_i
    c1 = c[1].to_i
    c2 = c[2].to_i
    return [c0,c1,c2]
  end

  # This function takes routing information from passing messages and sees if it can be used in our routing table
  # Uses to above halfDiff function to see if a new entry for [0,m,n] in routing table is better than present one
  # obviously if empty puts it in straight away
  def useRouteInfo( routeTable )
    for addr in routeTable
      addr2 = { :node_id => addr["node_id"], :ip_address => addr["ip_address"], :port => addr["port"] }
      m, n = getMnN(addr["node_id"])
      if @routing_table.has_value?(addr)
        if halfDiff( @routing_table[[0,m,n]]["node_id"] ) < halfDiff( @routing_table[[0,m,n]]["node_id"] )
          @routing_table[[0,m,n]] = addr2
        end
      else
        @routing_table[[0,m,n]] = addr2
      end
    end
  end

  # Removes an entry from the routing table if it has a node_id, used for trimming dead links
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

  # This function joins the network
  # Checks if we are a member of the network
  # Hashes the node ID
  # Initialises routing table with entries to itself in matching entries
  # If the first node in the network waits
  # Else forwards a join network simplified message onto the gateway node provided in function call
  # Note sending in a nil gateway node makes node assume it is first node in the network
  def joinNetwork( gateInetAddr_in, id_in )
    @netWorkMember = true
    @id = id_in
    @gateInetAddr = gateInetAddr_in
    @guid = Hash_Func( @id )
    for m in 0..@guid.length
      n = @guid[m].to_i
      @routing_table[[0,m,n]] = { :node_id => @guid, :ip_address => @localInetAddr.ip, \
       :port => @localInetAddr.port }
    end
    if gateInetAddr_in.ip == nil
      puts @id, "First Node in Network!  Waiting for peers ..."
      return @next_nid
    else
      joinMesg = { :type => "JOINING_NETWORK_SIMPLIFIED", :node_id => @guid, \
                   :ip_address => @localInetAddr.ip, :port => @localInetAddr.port }.to_json
      @s.send joinMesg, 0, @gateInetAddr.ip, @gateInetAddr.port
      return @next_nid
    end
    @next_nid += 1
  end

  # Leaves the network, as long as it is not empty, if not empty bradcases to all nodes
  def leaveNetwork( network_id )
    if @routing_table.empty?
      puts "You may not leave the network as you are the sole bootstrap node"
    else
      leaveMesg = { :type => "LEAVING_NETWORK", :node_id => @guid }.to_json
      sendBroadCast( nil, leaveMesg )
      @routing_table = Hash.new()
      @netWorkMember = false
    end

  end

  # Creates a new thread to check a route
  # Sends a ping message and waits 10 seconds for a responce from the next hop
  # If this responce is not received it calls remove on the address that failed
  # Uses a flag to avoid check same route while check already in progress
  # @checkAckWait = 0 for free flag
  # = 1 for check in progress and 2 for ack receaved
  def routeChecker( target_id )
    Thread.new{
      pingMesg = { :type => "PING", :target_id => target_id, :sender_id => @guid, :ip_address => @localInetAddr.ip, \
       :port => @localInetAddr.port }.to_json
      nh, m, n = nextCheckHop( target_id )
      if nh.ip != nil
        @s.send pingMesg, 0, nh.ip, nh.port
        t = Time.now.sec
        t2 = t + 10
        @checkAckWait[ nh.guid ] = 0
        while t < t2
          if @checkAckWait[ nh.guid ] == 2
            break
          end
          k = Time.now.sec
          if k != t
            t += 1
          end
        end
      end
      removeAddr( nh.guid )
    }
  end

  # Indexs a URL to the nodes with IDs matching the unique words
  # For every unique word creates a new thread
  # This thread will then send an INDEX message to the valid target
  # Thread will keep checking a temporary variable that stores the INDEX_ACK messages
  # If the message of interest appears in this variable terminates
  # Otherwise the thread calls route checker to find out why the message was not acknowledged
  def indexPage( url, unique_words )
    y = unique_words.length - 1
    for i in 0..y
      Thread.new(i){ |i2|
        wordHash = Hash_Func( unique_words[i2] )
        # Check flag guarding sending of messages to this node as we only want one INDEX message in progress between
        # two given nodes at any time, flag is 0 for available 1 for INDEX in progress and 2 for ACK received
        # Note you can still send INDEX messages to other nodes from this one and even to this node from the other node
        # IF the flag is not available we just wait until it is
        #
        # Flag turned off for better performance
        #
        while @indexAckWait != nil && @indexAckWait[ wordHash ] != nil && \
         ( @indexAckWait[ wordHash ] == 1 || @indexAckWait[ wordHash ] == 2 )
        end
        @indexAckWait[ wordHash ] = 1           # Set flag guarding index messages for this node to 1
        indexMesg = { :type => "INDEX", :target_id => wordHash, :sender_id => @guid , :keyword => unique_words[i2],
                      :link => url }.to_json
        nh, m, n = nextHop( wordHash )
        if wordHash == @guid                    # indexPage could well be called on our own node hence
                                                # just send the message to our own respond without actually sending
          indexMesg = JSON.parse( indexMesg )
          respond( indexMesg )
          @indexAckWait[ wordHash ] = 0
          return
        end
        @s.send indexMesg, 0, nh.ip, nh.port
        t = Time.now.sec                        # Wait 30 seconds for responce once message is sent
        t2 = t + 250
        while t < t2
          if @indexAckWait[ wordHash ] == 2     # If a flag indicates responce break
            break
          end
          k = Time.now.sec
          if k != t
            t += 1
          end
        end
        #puts Time.now, @indexAckWait
        if @indexAckWait[ wordHash ] != 2
          puts " "
          print @name, "No acknowledgment from INDEX message checking route"
          puts " "
          routeChecker( wordHash )
        else
          puts " "
          print @name, "Successful Index"
          puts " "
        end
        @indexAckWait[ wordHash ] = 0
      }
    end
  end

  # Creates search
  # Creates new thread for whole search
  # For each unique word creates it's own thread and sends off a search message and waits for a responce
  # Identical to INDEX function above if no responce received after 30 seconds checks route
  # All responces are stored temporarily once they are received and after 3 second the overall thread return available
  # results
  def search( unique_words )
    Thread.new{
      wordHash = []
      tempResults = {}
      list = {}
      y = unique_words.length - 1
      for i in 0..y
        Thread.new(i){ |i2|
          wordHash[i2] = Hash_Func( unique_words[i2] )
          while @searchAckWait != nil && ( @searchAckWait[ wordHash[i2] ] == 1 || @searchAckWait[ wordHash[i2] ].kind_of?(Array) )
          end
          @searchAckWait[ wordHash[i2] ] = 1
          searchMesg = { :type => "SEARCH", :word => unique_words[i2], :node_id => wordHash[i2], :sender_id => @guid }.to_json
          nh, m, n = nextHop( wordHash[i2] )
          @s.send searchMesg, 0, nh.ip, nh.port
          t = Time.now.sec
          t2 = t + 90
          while t < t2          # Waits 30 seconds before checking route
            if @searchAckWait[ wordHash[i2] ].kind_of?(Array)
              tempResults[ wordHash[i2] ] = @searchAckWait[ wordHash[i2] ]
              break
            end
            t = Time.now.sec
            if t < t2 - 30
              t = t + 60
            end
          end
          if @searchAckWait[ wordHash[i2] ].kind_of?(Array)
            puts "correct search result"
          else
            puts "The Search has failed time to check the route"
            #puts @searchAckWait, wordHash[i2]
            routeChecker( wordHash[i2] )
          end
          @searchAckWait[ wordHash[i2] ] = 0
        }
      end
      t3 = Time.now.sec           # returns results after 3 seconds
      t4 = t3 + 3
      while t3 < t4
        t3 = Time.now.sec
        if t3 < t4 - 3
          t3 = t3 + 60
        end
      end
      # Search algorithm return the minimum rank for each URL that is present for each word
      list = tempResults[ wordHash[0] ]
      removeList = []
      for j in 1..wordHash.length-1
        nList = tempResults[ wordHash[j] ]
        list.each { |h|
          removeFlag = true
          nList.any? { |nH|
            if nH[:url] == h[:url]
              removeFlag = false
              if nH[:rank] < h[:rank]
                h[:rank] = nH[:rank]
              end
            end
          }
          if removeFlag
            removeList << h
          end
        }
        for k in removeList
          list.delete(k)
        end
      end
      r = SearchResult.new()                # Holds results
      r.words = unique_words
      r.resutls = list
      return r
    }
  end

  # This function creates a new thread that listens to incoming messages
  # Checks this node is still a member of a network and then calls respond to handle the messages
  def listenLoop()
    x = Thread.new{
      i = 0
      while true
        i = i + 1
        puts " "
        print @name, " Listen Loop Round: ", i
        puts " "
        jsonIN = @s.recv(65536)
        puts " "
        print @name, " ", Time.now, " has receaved a Message:     ", jsonIN
        puts " "
        parsed = JSON.parse(jsonIN)
        if @netWorkMember
          self.respond( parsed )
        else
          puts "Not a member of a Network hence I will not respond"
        end
      end
    }
  end

  # This function handles incomming messages, it checks type and matches it against one of the following
  def respond( message )


    # If a joining message adds address to routing table and gateway table before sending a routing info message
    # to it and a joining relay message to a node with a GUID closer to the joining node
    if message["type"] == "JOINING_NETWORK_SIMPLIFIED"
      tnh, tm, tn = nextHop( message["node_id"] )
      @gateway_table[message["node_id"]] =  { :ip_address => message["ip_address"], :port => message["port"] }
      if @routing_table.has_key?([0,tm,tn]) == false # || diff( joining_guid ) < diff( @routing_table[[0,jm,jn]]["node_id"] )
        @routing_table[[0,tm,tn]] = { :node_id => message["node_id"], :ip_address => message["ip_address"], \
         :port => message["port"] }
      end
      if tnh.ip != nil
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :gateway_id => @guid, :ip_address => message["ip_address"], \
         :port => message["port"] }.to_json
        @s.send joinMesgRelay, 0, tnh.ip, tnh.port
      end
      tempRouteTable = []
      @routing_table.each_value { |addr|
        tempRouteTable.push( addr )
      }
      routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => @guid, :node_id => message["node_id"], \
       :ip_address => @localInetAddr.ip, :port => @localInetAddr.port, :route_table => tempRouteTable }.to_json
      @s.send routingInfoMesg, 0, message["ip_address"], message["port"]
    end


    # Behalves identically to above except responce to the gateway node instead of the joining node
    if message["type"] == "JOINING_NETWORK_RELAY_SIMPLIFIED"
      tnh, tm, tn = nextHop( message["node_id"] )
      nh, gm, gn = nextHop( message["gateway_id"] )
      if @routing_table.has_key?([0,tm,tn]) == false # || diff( joining_guid ) < diff( @routing_table[[0,jm,jn]]["node_id"] )
                                                     #puts "h6"
        @routing_table[[0,tm,tn]] = { :node_id => message["node_id"], :ip_address => message["ip_address"], \
         :port => message["port"] }
      end
      if tnh.ip != nil
        joinMesgRelay = { :type => "JOINING_NETWORK_RELAY_SIMPLIFIED", :node_id => message["node_id"], \
         :gateway_id => message["gateway_id"], \
          :ip_address => message["ip_address"], :port => message["port"] }.to_json
        @s.send joinMesgRelay, 0, tnh.ip, tnh.port
      end
      tempRouteTable = []
      @routing_table.each_value { |addr|
        tempRouteTable.push( addr )
      }
      routingInfoMesg = { :type => "ROUTING_INFO", :gateway_id => message["gateway_id"], :node_id => message["node_id"], \
       :ip_address => @localInetAddr.ip, :port => @localInetAddr.port, :route_table => tempRouteTable }.to_json
      if nh.ip != nil
        @s.send routingInfoMesg, 0, nh.ip, nh.port
      end
    end


    # When we get a routing info message extract as much useful information out of it as we can and forward it onto the
    # intended target node unless it was intended for our node
    if message["type"] == "ROUTING_INFO"
      useRouteInfo( message["route_table"] )
      if message["node_id"] == @guid
        return
      elsif message["gateway_id"] == @guid
        if @gateway_table.has_key?( message["node_id"] )
          p @s.send message.to_json, 0, @gateway_table[message["node_id"]][:ip_address].to_s, @gateway_table[message["node_id"]][:port]
        else
          puts "Routing_Info message receave error not key in gatewayTable!"
        end
      else
        nh, gm, gn = nextHop( message["node_id"] )
        message = message.to_json
        if nh.ip != nil
          @s.send message, 0, nh.ip, nh.port
        end
      end
    end

    # If we get a leaving message remove the node from the network
    if message["type"] == "LEAVING_NETWORK"
      removeAddr( message["node_id"])
    end

    # When we receave an index message check it is intended for us and if not forward to next hop otherwise process
    # increase the rank of urls in @linkHash or create a new entry if
    # We have not seen that URL before
    if message["type"] == "INDEX"
      if message["target_id"] == @guid
        flag = true
        for i in 0..@linkHash.length-1
          if @linkHash[i][:url] == message["link"]
            @linkHash[i][:rank] += 1
            flag = false
          end
        end
        if flag
          @linkHash << { :url => message["link"], :rank => 1 }
        end
        ackIndexMesg = { :type => "ACK_INDEX", :node_id => message["sender_id"], :keyword => message["keyword"] }.to_json
        if message["sender_id"] == @guid
          puts " "
          print @name, " INDEXING myself"     # If we are processing our own indexing message no need to send an ACK
          puts " "
          return
        end
        nh, sm, sn = nextHop( message["sender_id"] )
        @s.send ackIndexMesg, 0, nh.ip, nh.port
      else
        nh, tm, tn = nextHop( message["target_id"] )
        if nh.ip != nil
          @s.send message.to_json, 0, nh.ip, nh.port
        end
      end
    end


    # Keept forwarding until this ACK_INDEX message reaches its destination, when it does set the appropriate flag
    if message["type"] == "ACK_INDEX"
      if message["node_id"] == @guid
        wordHash = Hash_Func( message["keyword"] )
        @indexAckWait[ wordHash ] = 2
      else
        nh, m, n = nextHop( message["node_id"] )
        if nh.ip != nil
          @s.send message.to_json, 0, nh.ip, nh.port
        end
      end
    end


    # Keep forwarding search message until it reaches correct location in which case we append @linkHash to a search
    # responce message and send it to the sending ID
    if message["type"] == "SEARCH"
      if message["node_id"] == @guid
        searchResponceMesg = { :type => "SEARCH_RESPONSE", :word => message["word"], :node_id => message["sender_id"],
                               :sender_id => @guid, :response => @linkHash }.to_json
        nh, sm, sn = nextHop( message["sender_id"] )
        @s.send searchResponceMesg, 0, nh.ip, nh.port
      else
        nh, tm, tn = nextHop( message["node_id"] )
        message = message.to_json
        if nh.ip != nil
          @s.send message, 0, nh.ip, nh.port
        end
      end
    end

    # Keep forwarding responce until we reach intended recipient and then put results in flag so origional
    # search thread can process the results
    if message["type"] == "SEARCH_RESPONSE"
      if message["node_id"] == @guid
        @searchAckWait[ message["sender_id"] ] = message["response"]
      else
        nh, tm, tn = nextHop( message["node_id"] )
        if nh.ip != nil
          @s.send message.to_json, 0, nh.ip, nh.port
        end
      end
    end

    # Upon receaving a PING send onto next hop and generate ACK
    if message["type"] == "PING"
      ackMesg = { :type => "ACK", :node_id => @guid, :ip_address => @localInetAddr.ip, \
       :port => @localInetAddr.port }.to_json
      @s.send ackMesg, 0, message["ip_address"], message["port"]
      if message["target_id"] != @guid
        #puts @name, "PNH", message["target_id"], Time.now
        nh, m, n = nextHop( message["target_id"] )
        if nh.ip != nil
          message["ip_address"] = @localInetAddr.ip
          message["port"] = @localInetAddr.port
          @s.send message.to_json, 0, nh.ip, nh.port
        end
      end
    end

    # Upon receiving an ACK message we know this node is still alive
    if message["type"] == "ACK"
        @checkAckWait[ message["node_id"] ] = 2
    end
  end
end

