/// How often a deed recurs.
enum FrequencyType {
  daily('daily'),
  weekdays('weekdays'),
  timesPerWeek('times_per_week'),
  timesPerMonth('times_per_month');

  const FrequencyType(this.dbValue);

  final String dbValue;

  static FrequencyType fromDb(String value) => FrequencyType.values.firstWhere(
        (type) => type.dbValue == value,
        orElse: () => FrequencyType.daily,
      );

  String get label => switch (this) {
        FrequencyType.daily => 'Every day',
        FrequencyType.weekdays => 'Specific weekdays',
        FrequencyType.timesPerWeek => 'Times per week',
        FrequencyType.timesPerMonth => 'Times per month',
      };

  bool get isCountBased =>
      this == FrequencyType.timesPerWeek ||
      this == FrequencyType.timesPerMonth;
}

/// Outcome of a logged deed.
enum LogStatus {
  done('done'),
  late('late'),
  skipped('skipped');

  const LogStatus(this.dbValue);

  final String dbValue;

  static LogStatus fromDb(String value) => LogStatus.values.firstWhere(
        (status) => status.dbValue == value,
        orElse: () => LogStatus.done,
      );

  String get label => switch (this) {
        LogStatus.done => 'Done',
        LogStatus.late => 'Done late',
        LogStatus.skipped => 'Skipped',
      };
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);