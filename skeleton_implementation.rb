require 'json'
require 'socket'
require_relative 'search_result'

ip = "127.0.0.1"
id = "NILID"

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

alpha = PeerSearchInterface.new
sA = UDPSocket.new
sA.bind(ip, 8777)
alpha.init( sA )
nid = alpha.joinNetwork( "127.0.0.1", 8777, "Alpha", nil)
puts "Alpha joining", nid

beta = PeerSearchInterface.new
sB = UDPSocket.new
sB.bind(ip, 8778)
beta.init( sB )
nid = beta.joinNetwork( "127.0.0.1", 8778, "Beta", "Alpha")
puts "Beta joining", nid

charlie = PeerSearchInterface.new
sC = UDPSocket.new
sC.bind(ip, 8779)
charlie.init( sC )
nid = charlie.joinNetwork( "127.0.0.1", 8779, "Charlie", "Alpha")
puts "Charlie joining", nid

puts 'Type "LEAVE" to leave '
input = ""
while input != 'LEAVE'
  input = gets.chomp()
end
g6ps.leaveNetwork( nid )