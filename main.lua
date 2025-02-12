local uv = require 'uv'

local name = string.format("%s@%s", os.getenv("USER") or "unknown", os.getenv("HOSTNAME") or "unknown")

-- You can use netcat to send test messages to this service
-- echo "this is a test" | nc -u -w0 239.255.13.7 31896
local multicast_addr = {
    family = "inet",
    ip = "239.255.13.7",
    port = 31896,
}

-- Find our local LAN IPv4 address
local function get_lan_ipv4()
    local interfaces = uv.interface_addresses()
    for _, interface in pairs(interfaces) do
        for _, address in ipairs(interface) do
            if not address.internal and address.family == "inet" then
                return address.ip
            end
        end
    end
    return nil
end
local lan_ipv4 = assert(get_lan_ipv4(), "Cannot find local IPv4 Lan Address")

-- Create a TCP server so other nodes can connect directly to us.
local server = assert(uv.new_tcp("inet"))
-- Pick a random open port on the local machine.
assert(server:bind(lan_ipv4, 0, { reuseaddr = false }))
-- Save the address, we'll reuse us for our UDP sender so that
-- other nodes can connect to us on either protocol with the same address.
local address = assert(server:getsockname())
print(string.format("TCP Server listening on %s:%s", address.ip, address.port))


-- Create a UDP socket for receiving multicast messages
local multi = assert(uv.new_udp(multicast_addr.family))
-- Bind to 239.255.13.7:31896, allow port re-use so that multiple instances
-- of this program can all subscribe to the UDP broadcasts
assert(multi:bind(lan_ipv4, multicast_addr.port, { reuseaddr = true }))
-- Join the multicast group on 239.255.13.7
assert(multi:set_membership(multicast_addr.ip, lan_ipv4, "join"))
local address3 = assert(multi:getsockname())
print(string.format("Multicast receiver listening on %s:%s (interface %s)\n",
    multicast_addr.ip, address3.port, address3.ip));
assert(multi:set_multicast_ttl(10))

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

local clock = 0
local function send(message, cb)
    clock = clock + 1
    local out = string.format("%s: %d %s", name, clock, message)
    print("-> " .. out)
    assert(multi:send(out, multicast_addr.ip, multicast_addr.port,
        cb or log_error))
end

local peers = {}

local function show_peers()
    print("Current peers:")
    local peer_count = 0
    for k, v in pairs(peers) do
        print(string.format("  %s -> %s", k, v))
        peer_count = peer_count + 1
    end
    if peer_count == 0 then
        print("  No peers found.")
    end
    print()
end

local function add_peer(name, addr)
    local key = string.format("%s:%s", addr.ip, addr.port)
    if peers[key] then
        return false
    end
    peers[key] = name
    return true
end
local function remove_peer(name, addr)
    local key = string.format("%s:%s", addr.ip, addr.port)
    peers[key] = nil
end

multi:recv_start(function(err, data, addr)
    if err then
        print("Error reading multicast messages: " .. tostring(err))
        return
    elseif data == nil then
        return
    end
    local sender, nclock, message = data:match("(%S+):%s*(%d+)%s*(.*)")
    local newclock = tonumber(nclock)
    if sender and newclock and message then
        print("<- " .. tostring(data))
        if sender == name then
            -- print(string.format("Received my own message: %s", message))
        else
            if message == "HELLO" then
                if newclock < clock then
                    send("HELLO")
                end
                if add_peer(sender, addr) then
                    show_peers()
                end
            elseif message == "GOODBYE" then
                remove_peer(sender, addr)
                show_peers()
            end
        end
        if newclock > clock then
            clock = newclock
        end
    else
        print(string.format("Received malformed message: %s", tostring(data)))
    end
end)

send("HELLO")

-- Send goodbye on sigint
local sig = assert(uv.new_signal())
uv.signal_start(sig, "sigint", function()
    print("Received SIGINT, shutting down...")
    server:close()
    sig:close()
    multi:recv_stop()
    send("GOODBYE", function(err)
        if err then
            print("Error sending goodbye message: " .. tostring(err))
        else
            print("Goodbye message sent.")
        end
        multi:close()
        uv.stop()
    end)
end)
