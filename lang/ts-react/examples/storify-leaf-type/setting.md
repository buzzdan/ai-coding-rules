`alignIpConfig`, in the device network-settings form's `useNetworkSettings` module,
must inspect the interface a device reported (`ReportedInterface`, whose `addresses`
carry `family` and `scope` as the API sent them), pick usable global-unicast
IPv4/IPv6 addresses, and reconcile the IP fields of the `Config` draft — the copy
the hook commits with `setConfig` afterwards — with what it found.
