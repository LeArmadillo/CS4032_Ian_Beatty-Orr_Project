CS4032_Ian_Beatty-Orr_Project
=============================

Ian Beatty-Orr 09485112 CS4032 Project

to run just navigate to directory containing files and enter "ruby skeleton_implementation.rb"

That file contains the test code, the actual implementation is contained in peerSearchInterfaceCommented.rb (take a look inside the uncommented one to see all the debug print outs)

Routing is based on the Pastry paper without the leaf or neighbour hood parts

My test function starts at port 8777 and increments upwards as I was testing on one machine

Nodes are named after the NATO phonetic alphabet

This project makes use of the simplified protocol specification with the following changes:

Search result returns an array of hashes known as :result instead of url[] and frequency[] to better integrate it with the way link and rank information is stored for index and search messages

Wherever IP address are sent in messages port address are also sent to enable testing of multiple nodes on one machine

IP/port is also included in JOIN_NETWORK_RELAY_SIMPLIFIED to ensure that the node with GUID closest to a joining node can send messages to it, otherwise the routing I used based directly on the pasty paper would not function as intended.  target_id has been removed from both the join and join relay messages as the routing had no need for it

I also found performance to be better with longer timeouts before checking for dead nodes
