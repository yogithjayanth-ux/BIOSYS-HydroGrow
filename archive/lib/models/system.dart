class HydroSystem {
  HydroSystem({
    required this.name,
    required this.batchId,
    this.isFavorite = false,
  });

  final String name;
  final String batchId;
  bool isFavorite;
}

