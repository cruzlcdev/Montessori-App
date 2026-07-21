import 'connectivity_probe_stub.dart'
    if (dart.library.io) 'connectivity_probe_io.dart';

Future<bool> hasInternetReachability() => probeInternetReachability();
