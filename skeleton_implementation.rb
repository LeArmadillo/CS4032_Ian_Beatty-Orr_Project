require 'json'
require 'socket'
#require_relative 'peerSearchInterface'
require_relative 'peerSearchInterfaceCommented'

ip = "127.0.0.1"
id = "NILID"

puts "**********************"
puts "**********************"
puts "This will take a few minutes to execute if you want to just sit back and watch the messages go by"
puts "Type LEAVE once execution is finished to exit"
puts "**********************"
puts "**********************"
puts "Add a lot of nodes"
puts "**********************"
puts "**********************"

alpha = PeerSearchInterface.new("ALPHA")
sA = UDPSocket.new
sA.bind(ip, 8777)
alpha.init( sA, InetAddr.new( "127.0.0.1", "8777" ) )
anid = alpha.joinNetwork( InetAddr.new( nil, nil ), "Alpha" )

sleep 1

beta = PeerSearchInterface.new("BETA")
sB = UDPSocket.new
sB.bind(ip, 8778)
beta.init( sB, InetAddr.new( "127.0.0.1", "8778" ) )
nid = beta.joinNetwork( InetAddr.new("127.0.0.1", "8777"), "Beta" )

sleep 1

charlie = PeerSearchInterface.new("CHARLIE")
sC = UDPSocket.new
sC.bind(ip, 8779)
charlie.init( sC, InetAddr.new( "127.0.0.1", "8779" ) )
nid = charlie.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Charlie" )

sleep 1

delta = PeerSearchInterface.new("DELTA")
sD = UDPSocket.new
sD.bind(ip, 8780)
delta.init( sD, InetAddr.new( "127.0.0.1", "8780" ) )
nid = delta.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Delta" )

echo = PeerSearchInterface.new("ECHO")
sE = UDPSocket.new
sE.bind(ip, 8781)
echo.init( sE, InetAddr.new( "127.0.0.1", "8781" ) )
nid = echo.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Echo" )

sleep 1

foxtrot = PeerSearchInterface.new("FOXTROT")
sF = UDPSocket.new
sF.bind(ip, 8782)
foxtrot.init( sF, InetAddr.new( "127.0.0.1", "8782" ) )
nid = foxtrot.joinNetwork( InetAddr.new("127.0.0.1", "8777"), "Foxtrot" )

sleep 1

golf = PeerSearchInterface.new("GOLF")
sG = UDPSocket.new
sG.bind(ip, 8783)
golf.init( sG, InetAddr.new( "127.0.0.1", "8783" ) )
nid = golf.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Golf" )

sleep 1

hotel = PeerSearchInterface.new("HOTEL")
sH = UDPSocket.new
sH.bind(ip, 8784)
hotel.init( sH, InetAddr.new( "127.0.0.1", "8784" ) )
nid = hotel.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Hotel" )

india = PeerSearchInterface.new("INDIA")
sI = UDPSocket.new
sI.bind(ip, 8785)
india.init( sI, InetAddr.new( "127.0.0.1", "8785" ) )
nid = india.joinNetwork( InetAddr.new("127.0.0.1", "8784"), "India" )

sleep 1

juliett = PeerSearchInterface.new("JULIETT")
sJ = UDPSocket.new
sJ.bind(ip, 8786)
juliett.init( sJ, InetAddr.new( "127.0.0.1", "8786" ) )
nid = juliett.joinNetwork( InetAddr.new("127.0.0.1", "8777"), "Juliett" )

sleep 1

kilo = PeerSearchInterface.new("KILO")
sK = UDPSocket.new
sK.bind(ip, 8787)
kilo.init( sK, InetAddr.new( "127.0.0.1", "8787" ) )
nid = kilo.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Kilo" )

sleep 1

lima = PeerSearchInterface.new("LIMA")
sL = UDPSocket.new
sL.bind(ip, 8788)
lima.init( sL, InetAddr.new( "127.0.0.1", "8788" ) )
nid = lima.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Lima" )

sleep 1

mike = PeerSearchInterface.new("MIKE")
sM = UDPSocket.new
sM.bind(ip, 8789)
mike.init( sM, InetAddr.new( "127.0.0.1", "8789" ) )
nid = mike.joinNetwork( InetAddr.new("127.0.0.1", "8784"), "Mike" )

sleep 1

november = PeerSearchInterface.new("NOVEMBER")
sN = UDPSocket.new
sN.bind(ip, 8790)
november.init( sN, InetAddr.new( "127.0.0.1", "8790" ) )
nid = november.joinNetwork( InetAddr.new("127.0.0.1", "8787"), "November" )

sleep 1

oscar = PeerSearchInterface.new("OSCAR")
sO = UDPSocket.new
sO.bind(ip, 8791)
oscar.init( sO, InetAddr.new( "127.0.0.1", "8791" ) )
nid = oscar.joinNetwork( InetAddr.new( "127.0.0.1", "8788" ), "Oscar" )

sleep 1

papa = PeerSearchInterface.new("PAPA")
sP = UDPSocket.new
sP.bind(ip, 8792)
papa.init( sP, InetAddr.new( "127.0.0.1", "8792" ) )
nid = papa.joinNetwork( InetAddr.new( "127.0.0.1", "8790" ), "Papa" )


sleep 3
puts "**********************"
puts "**********************"
puts "Index some information"
puts "**********************"
puts "**********************"

alpha.indexPage( "www.1.url", ["Alpha"] )
alpha.indexPage( "www.2.url", ["Beta"] )
alpha.indexPage( "www.3.url", ["Beta"] )

charlie.indexPage( "www.9.url", ["Beta", "Alpha"] )

sleep 10
delta.indexPage( "www.1.url", ["Beta", "Alpha", "Delta", "Charlie"] )

sleep 50
oscar.indexPage( "www.8.url", ["Papa", "November", "Juliett", "Foxtrot"] )
november.indexPage( "www.3.url", ["Alpha"] )

sleep 50
puts "**********************"
puts "**********************"
puts "Lets Search for some words"
puts "**********************"
puts "**********************"
charlie.search( ["Alpha", "Beta"] )
sleep 20
kilo.search( ["Paper", "November", "Foxtrot"] )
sleep 20
foxtrot.search( ["Charlie", "Delta"] )


sleep 30
puts "**********************"
puts "**********************"
puts "Lets look at indexing nodes that a) don't exist and b) have left the network"
puts "**********************"
puts "**********************"
alpha.leaveNetwork( anid )
sleep 1
charlie.indexPage( "www.5.url", ["Alpha", "Beta", "Zeta"] )

sleep 4
puts 'Type "LEAVE" to leave '
input = ""
while input != 'LEAVE'
  input = gets.chomp()
end

