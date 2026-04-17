import 'package:freezed_annotation/freezed_annotation.dart';

part 'settlement.freezed.dart';
part 'settlement.g.dart';

@freezed
class BalanceEntry with _$BalanceEntry {
  const factory BalanceEntry({
    required String userId,
    required String displayName,
    required double balance,
  }) = _BalanceEntry;

  factory BalanceEntry.fromJson(Map<String, dynamic> json) => _$BalanceEntryFromJson(json);
}

@freezed
class Settlement with _$Settlement {
  const factory Settlement({
    required String from,
    required String to,
    required double amount,
  }) = _Settlement;

  factory Settlement.fromJson(Map<String, dynamic> json) => _$SettlementFromJson(json);
}

@freezed
class SettlementResult with _$SettlementResult {
  const factory SettlementResult({
    @Default([]) List<BalanceEntry> balances,
    @Default([]) List<Settlement> settlements,
    @Default(0) double total,
  }) = _SettlementResult;

  factory SettlementResult.fromJson(Map<String, dynamic> json) => _$SettlementResultFromJson(json);
}
