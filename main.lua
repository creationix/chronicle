local uv = require 'luv'

-- Multicast UDP example
-- listens on 224.0.0.1 (all machines on subnet) on port 31896

-- You can run this on any node on your local network,
-- each instance will receive UDPs sent to the multicast address

-- You can run multiple instances of this program, all listening
-- for the same UDP broadcast on the same port.

-- test this by doing this from any machine on the network
-- echo "this is a test" | nc -u -w0 224.0.0.1 31896

-- Create a TCP server so other nodes can connect directly to us and have reliable
-- RPC conversations
local server = assert(uv.new_tcp("inet"))
-- Pick a random open port on the local machine.
assert(server:bind("0.0.0.0", 0, { reuseaddr = false }))
-- Save the address, we'll reuse us for our UDP sender so that
-- other nodes can connect to us on either protocol with the same address.
local address = assert(server:getsockname())
print(string.format("TCP Server listening on %s:%s", address.ip, address.port))

-- Make a UDP handle that matches the TCP one for sending UDP messages
local udp_sender = assert(uv.new_udp(address.family))
assert(udp_sender:bind(address.ip, address.port, { reuseaddr = false }))

local multi_address = {
    family = "inet",
    port = 31896,
    ip = "224.0.0.1"
}
-- Create a UDP socket for receiving multicast messages
local multi = assert(uv.new_udp(multi_address.family))
-- Bind to 224.0.0.1:31896, allow port re-use so that multiple instances
-- of this program can all subscribe to the UDP broadcasts
assert(multi:bind(multi_address.ip, multi_address.port, { reuseaddr = true }))
-- Join the multicast group on 224.0.0.1
assert(multi:set_membership(multi_address.ip, "0.0.0.0", "join"))
print(string.format("Multicast receiver listening on %s:%s\n",
    multi_address.ip, multi_address.port));

-- Listen for multicast events
multi:recv_start(function(err, data, addr)
    if err then
        print("Error reading multicast messages: " .. tostring(err))
        return
    elseif data == nil then
        return
    end
    print(string.format("%s:%s - %s", addr.ip, addr.port, tostring(data)))
end)


local timer = assert(uv.new_timer())
timer:start(1000, 1000, function()
    print(string.format("sending from %s:%s", udp_sender:getsockname().ip, udp_sender:getsockname().port))
    assert(multi:send("coming from multi", multi_address.ip, multi_address.port, function(err)
        if err then
            print("send error: " .. tostring(err))
        end
    end))
    assert(udp_sender:send(tostring(uv.hrtime()), multi_address.ip, multi_address.port, function(err)
        if err then
            print("send error: " .. tostring(err))
        end
    end))
end)

uv.run()
