`alignIpConfig`, in the `useNetworkSettings` hook, must inspect the interface a device
reported (`ReportedInterface`), pick usable global-unicast IPv4/IPv6 addresses, and
reconcile the IP fields of the `Config` draft with what it found.
