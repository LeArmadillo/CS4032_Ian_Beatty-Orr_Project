require 'json'
require 'socket'
#require_relative 'search_result'
require_relative 'peerSearchInterface'

ip = "127.0.0.1"
id = "NILID"

alpha = PeerSearchInterface.new("ALPHA")
=begin
puts alpha.Hash_Func( "Alpha" )
puts alpha.Hash_Func( "Bravo" )
puts alpha.Hash_Func( "Charlie" )
puts alpha.Hash_Func( "Delta" )
puts alpha.Hash_Func( "Echo" )
puts alpha.Hash_Func( "Foxtrot" )
puts alpha.Hash_Func( "Golf" )
puts alpha.Hash_Func( "Hotel" )
puts alpha.Hash_Func( "India" )
puts alpha.Hash_Func( "Juliett" )
puts alpha.Hash_Func( "Kilo" )
puts alpha.Hash_Func( "Lime" )
puts alpha.Hash_Func( "Mike" )
puts alpha.Hash_Func( "November" )
puts alpha.Hash_Func( "Oscar" )
puts alpha.Hash_Func( "Papa" )
=end
sA = UDPSocket.new
sA.bind(ip, 8777)
alpha.init( sA, InetAddr.new( "127.0.0.1", "8777" ) )
nid = alpha.joinNetwork( InetAddr.new( nil, nil ), "Alpha", nil )
#puts "Alpha joining", nid

sleep 1

beta = PeerSearchInterface.new("BETA")
sB = UDPSocket.new
sB.bind(ip, 8778)
beta.init( sB, InetAddr.new( "127.0.0.1", "8778" ) )
nid = beta.joinNetwork( InetAddr.new("127.0.0.1", "8777"), "Beta", "Alpha" )
#puts "Beta joining", nid


sleep 1
puts "**************************"
puts "**************************"
puts "**************************"


charlie = PeerSearchInterface.new("CHARLIE")
sC = UDPSocket.new
sC.bind(ip, 8779)
charlie.init( sC, InetAddr.new( "127.0.0.1", "8779" ) )
nid = charlie.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Charlie", "Alpha" )
#puts "Charlie joining", nid



sleep 1

delta = PeerSearchInterface.new("DELTA")
sD = UDPSocket.new
sD.bind(ip, 8780)
delta.init( sD, InetAddr.new( "127.0.0.1", "8780" ) )
nid = delta.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Delta", "Charlie" )
#puts "Charlie joining", nid

sleep 1

#alpha.indexPage( "www.1.url", ["Alpha"] )
#alpha.indexPage( "www.2.url", ["Beta"] )

#sleep 3
puts "~~~~~~~~~~~~~~~~~"
puts "~~~~~~~~~~~~~~~~~"
puts "~~~~~~~~~~~~~~~~~"
charlie.indexPage( "www.5.url", ["Alpha", "Beta"] )

sleep 14
puts "###########################"
puts "###########################"
puts "###########################"
puts "###########################"
charlie.search( ["Alpha"] )


puts 'Type "LEAVE" to leave '
input = ""
while input != 'LEAVE'
  input = gets.chomp()
end

