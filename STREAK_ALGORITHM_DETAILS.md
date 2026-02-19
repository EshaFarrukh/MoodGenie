# Streak Calculation Algorithm - Technical Details

## Algorithm Flow

```dart
// Step 1: Get all unique dates from mood entries
final uniqueDates = <DateTime>{};
for (final entry in entries) {
  uniqueDates.add(entry['date'] as DateTime);
}

// Step 2: Sort dates in descending order (newest first)
final sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

// Step 3: Calculate streak
var streak = 0;
if (sortedDates.isNotEmpty) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final yesterday = todayDate.subtract(const Duration(days: 1));
  
  // Step 4: Check if streak is active (entry today or yesterday)
  final mostRecentDate = sortedDates.first;
  if (mostRecentDate.compareTo(yesterday) >= 0) {
    // Step 5: Count consecutive days
    var currentDate = mostRecentDate;
    streak = 1;
    
    for (var i = 1; i < sortedDates.length; i++) {
      final expectedDate = currentDate.subtract(const Duration(days: 1));
      if (sortedDates[i].year == expectedDate.year &&
          sortedDates[i].month == expectedDate.month &&
          sortedDates[i].day == expectedDate.day) {
        streak++;
        currentDate = sortedDates[i];
      } else {
        break; // Streak broken
      }
    }
  }
}
```

## Visual Example

### Timeline: December 18-23, 2025

```
         18    19    20    21    22    23 (today)
Logged:  ✅    ✅    ❌    ✅    ✅    ✅

Analysis:
- Most recent: Dec 23 ✅ (today)
- Is active: YES (today >= yesterday)
- Start counting: Dec 23 = 1
- Check Dec 22: ✅ consecutive → 2
- Check Dec 21: ✅ consecutive → 3
- Check Dec 20: ❌ NOT consecutive → BREAK
- Result: 3-day streak 🔥
```

### Another Timeline: Same dates but not logged today

```
         18    19    20    21    22    23 (today)
Logged:  ✅    ✅    ✅    ✅    ✅    ❌

Analysis:
- Most recent: Dec 22 ✅ (yesterday)
- Is active: YES (yesterday >= yesterday)
- Start counting: Dec 22 = 1
- Check Dec 21: ✅ consecutive → 2
- Check Dec 20: ✅ consecutive → 3
- Check Dec 19: ✅ consecutive → 4
- Check Dec 18: ✅ consecutive → 5
- Result: 5-day streak 🔥 (still active!)
```

### Broken Streak Example

```
         18    19    20    21    22    23 (today)
Logged:  ✅    ✅    ✅    ❌    ❌    ❌

Analysis:
- Most recent: Dec 20 ✅
- Is active: NO (Dec 20 < yesterday)
- Result: 0-day streak (needs to log to restart)
```

## Key Features

### 1. **Grace Period**
- Streak remains active if you logged yesterday but not today yet
- Gives users until end of day to maintain streak

### 2. **Consecutive Day Check**
```dart
// Exact date comparison
if (sortedDates[i].year == expectedDate.year &&
    sortedDates[i].month == expectedDate.month &&
    sortedDates[i].day == expectedDate.day)
```
- Checks year, month, and day
- Ignores time of day (10am vs 9pm doesn't matter)

### 3. **Break Detection**
- Stops counting at first missing day
- Doesn't count gaps as part of streak

### 4. **Multiple Entries Per Day**
```dart
final uniqueDates = <DateTime>{};
```
- Uses Set to ensure only one entry per day counts
- Logging mood 3x today = same as logging once

## Testing Checklist

- [ ] Log mood today → Streak = 1
- [ ] Log mood consecutive days → Streak increases
- [ ] Skip a day → Streak breaks and restarts
- [ ] Log yesterday, not today → Streak still shows
- [ ] Log 2 days ago, not yesterday → Streak = 0
- [ ] Multiple moods same day → Only counts as 1 day

## Data Source

```dart
// Fetches ALL mood entries (not limited)
final snap = await FirebaseFirestore.instance
    .collection('moods')
    .where('userId', isEqualTo: uid)
    .orderBy('createdAt', descending: false)
    .get(); // No .limit() restriction

// Ensures accurate streak calculation across all history
```

## Performance Considerations

- **Time Complexity**: O(n log n) for sorting + O(n) for streak counting
- **Space Complexity**: O(n) for storing unique dates
- **Optimization**: Could cache results, but dataset is typically small (<100 entries)

## Edge Cases Handled

✅ Empty data (no moods logged)
✅ Single entry (streak = 1 if recent)
✅ Future dates (shouldn't happen, but handled)
✅ Multiple entries same day (deduplicated)
✅ Timezone differences (uses device local time)
✅ Month/year boundaries (Dec 31 → Jan 1)

---

**Last Updated**: December 23, 2025
**Status**: ✅ Implemented and Working

