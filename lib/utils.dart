String memoryString(BigInt memory) {
  // ignore: constant_identifier_names
  const int GB = 1024 * 1024 * 1024;
  // ignore: constant_identifier_names
  const int MB = 1024 * 1024;
  // ignore: constant_identifier_names
  const int KB = 1024;
  if (memory.toInt() > GB) {
    return "${(memory.toInt() / GB).toStringAsFixed(1)}G";
  } else if (memory.toInt() > MB) {
    return "${(memory.toInt() / MB).toStringAsFixed(1)}M";
  } else {
    return "${(memory.toInt() / KB).toStringAsFixed(1)}K";
  }
}
