# Chronicle FS

Chronicle is designed to be your personal filesystem that you keep for years.  The actual files can be read/write from any of your personal devices and you can share views/slices of it with friends and family.

## Getting Started

To get started


## Listeners

Nodes in the network listen for messages on the UDP multicast bus

browser based nodes (such as websites used by mobile device UIs) can talk to the bus via a well-known address and websockets ws://chronicle-bus.local/

## Events

Every message is signed by the public key of the sender and includes the full ed25519 key.

Broadcast messages to know who's online and what they can do

- HELLO (name, services, ttl) - announce to the network you're online and your abilities
  - a node must resend it's hello on an interval (less than ttl) or others will assume it died.
- GOODBYE (name) - broadcast when going offline so others can cleanup their tables immediately

All bulk data is addressed using SHA256 content hashes. Broadcast messages are used to announce hashes that you want or hashes you have

- WANT (hash) - tell the network you want a hash
- HAVE (hash) - tell the network you have a hash

For actual transfer of bulk data, don't use multicast, but send unicast messages via UDP or TCP depending on the use case.

Note that we can encrypt these P2P transfers since we always know the sender and receiver know each other's public keys.

- PUSH (hash, data) - Send a chunk (use UDP for small payloads, TCP for large ones)
- PULL (hash) - Ask a node to send you a chunk







