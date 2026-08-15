# ViDot

The previous loopback WebSocket RPC implementation has been deliberately
removed so its transport and API are not mistaken for the ViDot contract. This
package path is reserved for the pending Godot-native Vitest adapter documented
in [`docs/vidot.md`](../../docs/vidot.md).

The Godot project assets under
[`examples/basic-vidot`](../../examples/basic-vidot) remain as the first generic
fixture. Its old Vitest lifecycle and RPC test are gone, so the fixture is not
currently runnable through ViDot. It will be reconnected only through the new
Godot-native adapter.
