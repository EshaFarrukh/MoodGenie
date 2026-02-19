# 🧠 Therapist Feature - Domain Layer

## ✅ **Domain Layer Complete**

A comprehensive domain layer for the Therapist feature has been implemented following clean architecture principles with robust validation and business logic.

## 📁 **Architecture Overview**

```
src/therapist/domain/
├── entities/
│   ├── therapist_entity.dart      # Core therapist data model
│   └── session_entity.dart        # Therapy session model
├── repositories/
│   ├── therapist_repository.dart  # Therapist data contracts
│   └── session_repository.dart    # Session data contracts
├── usecases/
│   ├── watch_my_therapist_usecase.dart
│   ├── upsert_therapist_profile_usecase.dart
│   ├── update_availability_usecase.dart
│   ├── watch_approved_therapists_usecase.dart
│   ├── watch_therapist_sessions_usecase.dart
│   ├── request_session_usecase.dart
│   ├── accept_session_usecase.dart
│   ├── reject_session_usecase.dart
│   ├── complete_session_usecase.dart
│   └── cancel_session_usecase.dart
└── domain.dart                    # Export barrel file
```

## 🏗️ **Entities**

### **TherapistEntity**
Core therapist profile with comprehensive validation:

```dart
TherapistEntity({
  required String therapistId,
  required String userId,
  required String name,
  required String specialization,
  required int experienceYears,
  required List<AvailabilitySlotEntity> availabilitySlots,
  required double rating,
  required bool isApproved,
  required DateTime createdAt,
})
```

**Features:**
- ✅ Firestore integration (fromFirestore/toFirestore)
- ✅ Validation for all fields
- ✅ Availability slot overlap detection
- ✅ Business rule validation (experience requirements)
- ✅ Immutable with copyWith support

### **AvailabilitySlotEntity**
Time slot management with business rules:

```dart
AvailabilitySlotEntity({
  required DateTime startAt,
  required DateTime endAt,
  bool isBooked = false,
})
```

**Validation Rules:**
- ✅ `startAt < endAt` validation
- ✅ Minimum 30-minute duration
- ✅ Maximum 4-hour duration
- ✅ No past scheduling
- ✅ Overlap detection between slots

### **SessionEntity**
Therapy session with status management:

```dart
SessionEntity({
  required String sessionId,
  required String userId,
  required String therapistId,
  required DateTime scheduledAt,
  required SessionStatus status,
  String? meetingRoomId,
  String? notes,
  required DateTime createdAt,
  DateTime? updatedAt,
})
```

**Status Flow:**
`requested` → `accepted`/`rejected` → `completed`/`cancelled`

**Business Logic:**
- ✅ Status transition validation
- ✅ Business hours enforcement (9 AM - 6 PM)
- ✅ Weekday-only scheduling
- ✅ Overdue session detection
- ✅ Cancellation timing rules

## 🔄 **Repository Contracts**

### **TherapistRepository**
```dart
// Core operations
Stream<TherapistEntity?> watchMyTherapist(String uid);
Future<void> upsertProfile(TherapistEntity entity);
Future<void> updateAvailability(String uid, List<AvailabilitySlotEntity> slots);

// Query operations
Stream<List<TherapistEntity>> watchApprovedTherapists({
  String? specialization,
  double? minRating,
  int? maxExperienceYears,
  int? minExperienceYears,
  bool availableOnly = false,
});

// Session management
Stream<List<SessionEntity>> watchTherapistSessions(String therapistId);

// Admin operations
Future<void> approveTherapist(String therapistId);
```

### **SessionRepository**
```dart
// Session lifecycle
Future<String> requestSession({required String userId, required String therapistId, required DateTime scheduledAt, String? notes});
Future<void> acceptSession(String sessionId, {String? meetingRoomId});
Future<void> rejectSession(String sessionId, {String? reason});
Future<void> completeSession(String sessionId, {String? notes});
Future<void> cancelSession(String sessionId, {String? reason});

// Query operations
Stream<List<SessionEntity>> watchUserSessions(String userId);
Stream<List<SessionEntity>> watchTherapistSessions(String therapistId);
Future<bool> isTimeSlotAvailable(String therapistId, DateTime scheduledAt);
Future<List<SessionEntity>> getConflictingSessions(String therapistId, DateTime startTime, DateTime endTime);
```

## 🎯 **Use Cases**

### **Therapist Management**

**WatchMyTherapistUseCase**
- Streams therapist profile updates
- Validates UID input

**UpsertTherapistProfileUseCase**
- Creates/updates therapist profiles
- Comprehensive validation including:
  - Business rule validation
  - Overlap detection in availability
  - Specialization experience requirements
  - Daily working hour limits

**UpdateAvailabilityUseCase**
- Manages therapist availability slots
- Validates scheduling rules:
  - No overlapping slots
  - Maximum 8 slots/day
  - 8-hour daily limit
  - 15-minute breaks between slots
  - Business hours only
  - Weekdays only

**WatchApprovedTherapistsUseCase**
- Filters and streams approved therapists
- Multiple filtering options with convenience methods
- Parameter validation

### **Session Management**

**RequestSessionUseCase**
- Creates new session requests
- Validates scheduling constraints:
  - 1-hour minimum advance notice
  - Business hours (9 AM - 6 PM)
  - Weekdays only
  - Hour/half-hour scheduling
  - 30-day maximum advance
  - Availability checking

**AcceptSessionUseCase**
- Therapist accepts session requests
- Validates state transitions
- Conflict detection
- Meeting room URL validation

**RejectSessionUseCase**
- Therapist rejects session requests
- Predefined rejection reasons
- Content validation for custom reasons

**CompleteSessionUseCase**
- Marks sessions as completed
- Professional notes validation
- Timing validation
- Structured notes support

**CancelSessionUseCase**
- Cancels sessions with proper validation
- 24-hour notice period tracking
- Emergency cancellation support
- Predefined cancellation reasons

## 🔒 **Validation Features**

### **Input Validation**
- ✅ Empty string checking
- ✅ Length limits on text fields
- ✅ Format validation (emails, URLs)
- ✅ Range validation (ratings, experience)

### **Business Rule Validation**
- ✅ Time slot constraints
- ✅ Working hour enforcement
- ✅ Experience requirements by specialization
- ✅ Scheduling conflict prevention
- ✅ Status transition rules

### **Content Validation**
- ✅ Professional notes structure
- ✅ Inappropriate content detection
- ✅ Meaningful content requirements
- ✅ Character limits with context

## 🚀 **Usage Examples**

### **Therapist Profile Management**
```dart
// Watch therapist profile
final useCase = WatchMyTherapistUseCase(repository);
useCase.call(userId).listen((therapist) {
  // Handle profile updates
});

// Update availability
final updateUseCase = UpdateAvailabilityUseCase(repository);
await updateUseCase.call(userId, availabilitySlots);
```

### **Session Management**
```dart
// Request session
final requestUseCase = RequestSessionUseCase(repository);
final sessionId = await requestUseCase.call(RequestSessionParams(
  userId: 'user123',
  therapistId: 'therapist456',
  scheduledAt: DateTime.now().add(Duration(days: 1)),
  notes: 'First therapy session',
));

// Accept session
final acceptUseCase = AcceptSessionUseCase(repository);
await acceptUseCase.acceptWithZoom(sessionId, 'https://zoom.us/j/123456789');
```

### **Filtering Therapists**
```dart
final watchUseCase = WatchApprovedTherapistsUseCase(repository);

// By specialization
watchUseCase.bySpecialization('Anxiety Therapy').listen((therapists) {
  // Handle filtered results
});

// Highly rated
watchUseCase.highlyRated(minRating: 4.5).listen((therapists) {
  // Handle highly rated therapists
});

// Available only
watchUseCase.availableOnly().listen((therapists) {
  // Handle available therapists
});
```

## ⚡ **Key Features**

### **Robust Validation**
- Multi-layer validation (input, business rules, content)
- Descriptive error messages
- Edge case handling

### **Flexible Querying**
- Stream-based reactive programming
- Multiple filtering options
- Convenience methods for common use cases

### **Professional Standards**
- Healthcare scheduling compliance
- Professional note requirements
- Appropriate cancellation policies

### **Developer Experience**
- Clean separation of concerns
- Comprehensive documentation
- Type-safe operations
- Immutable entities

## 🔧 **Next Steps for Implementation**

1. **Data Layer**: Implement repository concrete classes with Firebase
2. **Presentation Layer**: Create ViewModels and UI components
3. **Testing**: Add comprehensive unit tests for all use cases
4. **Integration**: Connect with existing auth system
5. **Security**: Add Firestore security rules
6. **Monitoring**: Add analytics and error tracking

The domain layer provides a solid foundation for building a professional therapy booking and management system! 🎉
