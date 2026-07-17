class CadGenerationRequest {
  const CadGenerationRequest({
    required this.payload,
    required this.fileName,
    this.skipBatRun = 'no',
  });

  final Map<String, dynamic> payload;
  final String fileName;
  final String skipBatRun;

  Map<String, dynamic> toQueryParameters() {
    return <String, dynamic>{'fileName': fileName, 'skipBatRun': skipBatRun};
  }
}
