require 'json'
require 'socket'
require_relative 'search_result'

hostname = 'localhost'
port = 8767
if ARGV[0] == "--port"
  port = ARGV[1]
end
ip = "127.0.0.1"
socket = UDPSocket.new
socket.bind(ip, port)
bootstrap_ip = "NILIP"

if ARGV[2] == "--bootstrap" && ARGV[4] == "--id"
  bootstrap_ip = ARGV[3]
  id = ARGV[5]
elsif ARGV[2] == "--boot"
  id = ARGV[3]
else
  puts 'NO COMMAND LINE ARGUMENTS - THIS WILL NEVER JOIN A NETWORK'
end
ARGV.clear

g6ps = PeerSearchInterface
g6ps.init( socket, id, ip, bootstrap_ip )
nid = g6ps.joinNetwork( nil )
puts 'Connected to Network: ', nid
puts 'Type "LEAVE" to leave '
input = ""
while input != 'LEAVE'
  input = gets.chomp()
end
g6ps.leaveNetwork( nid )