/// Rotating motivational line shown on the Today screen.
/// Deterministic per day so it feels fresh but stable.
const List<String> quotes = [
  'Small steps every day.',
  'Discipline is choosing what you want most over what you want now.',
  'You don\'t have to be extreme, just consistent.',
  'Future you is watching.',
  'Progress, not perfection.',
  'One tick at a time.',
  'Habits are the compound interest of self-improvement.',
  'Start where you are. Use what you have.',
  'Motivation gets you started. Habit keeps you going.',
  'Do it today. Future you says thanks.',
  'Consistency beats intensity.',
  'A little better every day.',
  'Show up. That\'s the hard part.',
  'What gets scheduled gets done.',
  'Fall in love with the process.',
  'Energy and persistence conquer all things.',
  'The secret of getting ahead is getting started.',
  'Focus on being productive instead of busy.',
  'Your only limit is you.',
  'Win the morning, win the day.',
];

String quoteForDay(DateTime day) {
  final dayOfYear = day.difference(DateTime(day.year, 1, 1)).inDays;
  return quotes[dayOfYear % quotes.length];
}

String greetingForHour(int hour) {
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 22) return 'Good evening';
  return 'Burning the midnight oil?';
}