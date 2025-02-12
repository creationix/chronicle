local is_luvit = false
local ok, uv = pcall(require, 'luv')
if not ok then
    uv = require 'uv'
    is_luvit = true
end

local name = string.format("%s@%s", os.getenv("USER") or "unknown", os.getenv("HOSTNAME") or "unknown")

-- You can use netcat to send test messages to this service
-- echo "this is a test" | nc -u -w0 239.255.13.7 31896
local multicast_addr = {
    family = "inet",
    ip = "239.255.13.7",
    port = 31896,
}

-- Create a TCP server so other nodes can connect directly to us.
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
local address2 = assert(udp_sender:getsockname())
print(string.format("UDP Server listening on %s:%s", address2.ip, address2.port))
assert(address2.ip == address.ip)
assert(address2.port == address.port)


-- Create a UDP socket for receiving multicast messages
local multi = assert(uv.new_udp(multicast_addr.family))
-- Bind to 239.255.13.7:31896, allow port re-use so that multiple instances
-- of this program can all subscribe to the UDP broadcasts
assert(multi:bind("0.0.0.0", multicast_addr.port, { reuseaddr = true }))
-- Join the multicast group on 239.255.13.7
assert(multi:set_membership(multicast_addr.ip, "0.0.0.0", "join"))
local address3 = assert(multi:getsockname())
print(string.format("Multicast receiver listening on %s:%s (interface %s)\n",
    multicast_addr.ip, address3.port, address3.ip));

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

local function log_error(err)
    if err then error(err) end
end

local function send(socket, message)
    local addr = assert(socket:getsockname())
    print(string.format("Sending to multicast network %s:%s...", multicast_addr.ip, multicast_addr.port))
    assert(socket:send(message, multicast_addr.ip, multicast_addr.port, log_error))
end

local timer = assert(uv.new_timer())
timer:start(2000, 2000, function()
    send(udp_sender, string.format("%s: sending from udp_sender %s", name, uv.hrtime()))
end)

if not is_luvit then
    uv.run()
end
