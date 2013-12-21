require 'json'
require 'socket'
require_relative 'search_result'

ip = "127.0.0.1"
id = "NILID"
#InetAddr = Struct.new(:ip, :port)

=begin
port = 8767
if ARGV[0] == "--port"
  port = ARGV[1]
end
if ARGV[2] == "--bootstrap" && ARGV[4] == "--id"
  bootstrap_ip = ARGV[3]
  id = ARGV[5]
elsif ARGV[2] == "--boot"
  id = ARGV[3]
else
  puts 'NO COMMAND LINE ARGUMENTS - THIS WILL NEVER JOIN A NETWORK'
end
ARGV.clear
=end

alpha = PeerSearchInterface.new("ALPHA")
sA = UDPSocket.new
sA.bind(ip, 8777)
alpha.init( sA, InetAddr.new( "127.0.0.1", "8777" ) )
nid = alpha.joinNetwork( InetAddr.new( nil, nil ), "Alpha", nil )
#puts "Alpha joining", nid

beta = PeerSearchInterface.new("BETA")
sB = UDPSocket.new
sB.bind(ip, 8778)
beta.init( sB, InetAddr.new( "127.0.0.1", "8778" ) )
nid = beta.joinNetwork( InetAddr.new("127.0.0.1", "8777"), "Beta", "Alpha" )
#puts "Beta joining", nid


sleep 2
puts "**************************"
puts "**************************"
puts "**************************"


charlie = PeerSearchInterface.new("CHARLIE")
sC = UDPSocket.new
sC.bind(ip, 8779)
charlie.init( sC, InetAddr.new( "127.0.0.1", "8779" ) )
nid = charlie.joinNetwork( InetAddr.new( "127.0.0.1", "8778" ), "Charlie", "Alpha" )
#puts "Charlie joining", nid

#puts "Having a snooze ... zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
#sleep 5


#alpha.indexPage( "www.1.url", ["Alpha", "Beta", "Charlie"] )
#alpha.indexPage( "www.1.url", ["Alpha", "Beta", "Charlie"] )
#alpha.indexPage( "www.1.url", ["Alpha", "Beta", "Charlie"] )


puts 'Type "LEAVE" to leave '
input = ""
while input != 'LEAVE'
  input = gets.chomp()
end
g6ps.leaveNetwork( nid )
