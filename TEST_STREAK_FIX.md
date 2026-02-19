# Testing Guide: Streak Fix & Data Refresh

## ✅ Changes Successfully Implemented

### 1. **Fixed Streak Calculation Algorithm**
- Now properly counts consecutive days
- Allows 24-hour grace period (yesterday counts as active)
- Fetches all mood entries (not limited to 30)

### 2. **Implemented Auto-Refresh**
- Home dashboard refreshes after logging mood
- Analytics screen updates in real-time
- All navigation properly awaits and triggers setState()

---

## 🧪 Testing Procedures

### **Test 1: Basic Streak Functionality**

#### Steps:
1. Open the app
2. Navigate to Mood Analytics (from home screen "View Report" button)
3. Check current streak value
4. Note the streak number

**Expected Result:**
- Streak displays correctly based on consecutive days
- Shows "0 Day Streak" if no recent entries
- Shows actual count if you've logged moods consecutively

---

### **Test 2: Logging New Mood Updates Streak**

#### Steps:
1. From home screen, tap "Log Mood" button
2. Select a mood and intensity
3. Add optional note
4. Tap "Save Mood"
5. Wait for success notification
6. Navigate to Mood Analytics

**Expected Result:**
- ✅ Streak increments by 1 if logged yesterday
- ✅ Streak shows 1 if this is first consecutive day
- ✅ All data reflects the new mood entry
- ✅ Weekly average updates
- ✅ Mood distribution updates

---

### **Test 3: Home Screen Auto-Refresh**

#### Steps:
1. From home screen, note "Mood Summary" section data
2. Tap "Log Mood" button or Mood nav item
3. Log a new mood
4. Return to home screen (back button)

**Expected Result:**
- ✅ Mood Summary updates immediately
- ✅ Weekly trend chart reflects new entry
- ✅ Average mood recalculates
- ✅ No need to restart app

---

### **Test 4: Grace Period (Yesterday Entry)**

#### Scenario Setup:
- Have a mood logged yesterday
- Don't log anything today yet

#### Steps:
1. Open Mood Analytics
2. Check streak value

**Expected Result:**
- ✅ Streak remains active (not 0)
- ✅ Shows actual consecutive days
- ✅ Message encourages logging today

---

### **Test 5: Broken Streak Detection**

#### Scenario Setup:
- Log mood on Dec 20
- Skip Dec 21
- Log mood on Dec 22 and 23

#### Steps:
1. Open Mood Analytics
2. Check streak value

**Expected Result:**
- ✅ Streak = 2 days (Dec 22-23)
- ✅ Previous entries before gap don't count
- ✅ Streak started fresh after the gap

---

### **Test 6: Multiple Moods Same Day**

#### Steps:
1. Log a mood entry
2. Immediately log another mood (same day)
3. Check analytics

**Expected Result:**
- ✅ Only counts as 1 day for streak
- ✅ Most recent entry used for data
- ✅ No duplicate day counting

---

## 🎯 Success Criteria Checklist

- [ ] Streak calculation is accurate
- [ ] Streak updates immediately after logging mood
- [ ] Yesterday's entry keeps streak active
- [ ] Gaps in logging properly break streak
- [ ] Home screen data refreshes without restart
- [ ] Analytics screen data refreshes without restart
- [ ] Multiple entries same day = 1 streak day
- [ ] Weekly averages calculate correctly
- [ ] No errors in console/terminal
- [ ] UI remains smooth and responsive

---

## 🐛 Known Edge Cases (Handled)

### ✅ Empty Data
- Shows "No mood data yet" message
- Streak = 0
- Encourages first entry

### ✅ Single Entry
- Streak = 1 if entry is today or yesterday
- Streak = 0 if entry is older

### ✅ Month/Year Boundaries
- Dec 31 → Jan 1 properly counted as consecutive
- Algorithm handles date rollovers

### ✅ Timezone Considerations
- Uses device local time
- Consistent across app sessions

---

## 🚀 How to Run Tests

### Command Line:
```bash
cd /Users/eshafarrukh/StudioProjects/MoodGenie

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Run on device/simulator
flutter run
```

### Manual Testing Flow:
1. **Day 1**: Log mood → Check streak = 1
2. **Day 2**: Log mood → Check streak = 2
3. **Day 3**: Skip logging
4. **Day 4**: Log mood → Check streak = 1 (restarted)
5. **Day 5**: Log mood → Check streak = 2
6. Navigate around app → Verify data updates

---

## 📊 Example Test Scenarios

### Scenario A: New User
```
Day 1: Log mood ✅ → Streak = 1 🔥
Day 2: Log mood ✅ → Streak = 2 🔥
Day 3: Log mood ✅ → Streak = 3 🔥
```

### Scenario B: Casual User
```
Day 1: Log mood ✅ → Streak = 1 🔥
Day 2: Skip ❌
Day 3: Log mood ✅ → Streak = 1 🔥 (restarted)
```

### Scenario C: Active User
```
Day 1-7: Log daily ✅ → Streak = 7 🔥
Day 8: Haven't logged yet (still morning)
Check analytics → Streak = 7 🔥 (still active from yesterday)
```

---

## 🔍 Debugging Tips

### If streak seems wrong:
1. Check Firestore console for actual mood entries
2. Verify dates are stored correctly
3. Check device date/time settings
4. Look for console errors

### If data doesn't refresh:
1. Verify setState() is being called
2. Check navigation flow (await is used)
3. Ensure StatefulWidget is used
4. Restart app as last resort

### Console Commands for Debug:
```bash
# Check for errors
flutter doctor

# View logs
flutter logs

# Hot restart (preserves state)
Press 'R' in terminal

# Full restart
Press 'r' in terminal
```

---

## ✨ Expected User Experience

### Before Fix:
- ❌ Streak broke every day you didn't log immediately
- ❌ Had to restart app to see new data
- ❌ Confusing and demotivating

### After Fix:
- ✅ Streak feels fair and achievable
- ✅ Data updates instantly
- ✅ Encouraging and accurate
- ✅ Professional app experience

---

## 📝 Test Results Log

Date: __________
Tester: __________

| Test # | Description | Pass/Fail | Notes |
|--------|-------------|-----------|-------|
| 1 | Basic streak display | ⬜ | |
| 2 | Logging updates streak | ⬜ | |
| 3 | Home screen refresh | ⬜ | |
| 4 | Grace period works | ⬜ | |
| 5 | Broken streak detection | ⬜ | |
| 6 | Multiple same-day entries | ⬜ | |

---

**Status**: ✅ Ready for Testing
**Version**: 1.0
**Date**: December 23, 2025

