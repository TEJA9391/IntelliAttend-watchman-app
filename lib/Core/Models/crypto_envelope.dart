/// Tamper-evident cryptographic payload envelope.
///
/// Wraps a hardware-backed signature, public key, and monotonic timestamp
/// into a single JSON-serializable object. Used by SecurityController's
/// scorched-earth execution and by attendance submission for anti-replay.
class CryptoEnvelope {
  final String signature;
  final String publicKey;
  final int monotonicTimestamp;

  CryptoEnvelope({
    required this.signature,
    required this.publicKey,
    required this.monotonicTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'signature': signature,
    'public_key': publicKey,
    'monotonic_timestamp': monotonicTimestamp,
  };

  factory CryptoEnvelope.fromJson(Map<String, dynamic> json) {
    return CryptoEnvelope(
      signature: json['signature'] as String,
      publicKey: json['public_key'] as String,
      monotonicTimestamp: json['monotonic_timestamp'] as int,
    );
  }

  String get signingPayload => '$monotonicTimestamp|$publicKey';
}
