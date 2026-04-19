const path = require('node:path');
const fs = require('node:fs/promises');
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  deleteDoc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'moodgenie-firestore-rules';
const rulesPath = path.resolve(__dirname, '../firestore.rules');

let testEnv;

test.before(async () => {
  const rules = await fs.readFile(rulesPath, 'utf8');
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
});

test.after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

test.beforeEach(async () => {
  if (testEnv) {
    await testEnv.clearFirestore();
  }
});

async function seed(seedFn) {
  await testEnv.withSecurityRulesDisabled(seedFn);
}

test('owner can create a mood entry', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await assertSucceeds(
    setDoc(doc(alice.firestore(), 'moods/mood-1'), {
      userId: 'alice',
      mood: 'Calm',
      intensity: 7,
      createdAt: new Date(),
    }),
  );
});

test('approved therapist with consent can read patient mood data', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), {
      role: 'user',
      consentedTherapists: ['therapist-1'],
    });
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: true,
      credentialVerificationStatus: 'verified',
    });
    await setDoc(doc(db, 'moods/mood-1'), {
      userId: 'alice',
      mood: 'Good',
      intensity: 8,
      createdAt: new Date(),
    });
  });

  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertSucceeds(getDoc(doc(therapist.firestore(), 'moods/mood-1')));
});

test('unapproved therapist cannot read patient mood data', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), {
      role: 'user',
      consentedTherapists: ['therapist-1'],
    });
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: false,
    });
    await setDoc(doc(db, 'moods/mood-1'), {
      userId: 'alice',
      mood: 'Good',
      intensity: 8,
      createdAt: new Date(),
    });
  });

  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertFails(getDoc(doc(therapist.firestore(), 'moods/mood-1')));
});

test('therapist cannot self-approve profile through client write', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: false,
      specialty: 'CBT',
    });
  });

  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertFails(
    updateDoc(doc(therapist.firestore(), 'therapists/therapist-1'), {
      isApproved: true,
    }),
  );
});

test('appointment outsider cannot read private appointment', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'appointments/apt-1'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      status: 'requested',
      scheduledAt: new Date(),
    });
  });

  const outsider = testEnv.authenticatedContext('mallory');
  await assertFails(getDoc(doc(outsider.firestore(), 'appointments/apt-1')));
});

test('client cannot create an appointment directly even for an approved therapist', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: true,
      credentialVerificationStatus: 'verified',
      acceptingNewPatients: true,
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  await assertFails(
    setDoc(doc(alice.firestore(), 'appointments/apt-2'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      status: 'requested',
      scheduledAt: new Date(),
    }),
  );
});

test('user cannot request an appointment with an unapproved therapist', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: false,
      acceptingNewPatients: true,
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  await assertFails(
    setDoc(doc(alice.firestore(), 'appointments/apt-3'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      status: 'requested',
      scheduledAt: new Date(),
    }),
  );
});

test('appointment participants cannot change appointment status directly', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'appointments/apt-4'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      status: 'requested',
      scheduledAt: new Date(),
    });
  });

  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertFails(
    updateDoc(doc(therapist.firestore(), 'appointments/apt-4'), {
      status: 'confirmed',
    }),
  );
});

test('appointment participants cannot delete appointment history directly', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'appointments/apt-4b'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      status: 'requested',
      scheduledAt: new Date(),
    });
  });

  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertFails(deleteDoc(doc(therapist.firestore(), 'appointments/apt-4b')));
});

test('signed-in user cannot read therapist private user document', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/therapist-1'), {
      role: 'therapist',
      email: 'therapist@example.com',
      consentAccepted: true,
      consentedTherapists: [],
    });
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: true,
      credentialVerificationStatus: 'verified',
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  await assertFails(getDoc(doc(alice.firestore(), 'users/therapist-1')));
});

test('signed-in user can read public therapist directory profile', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: true,
      credentialVerificationStatus: 'verified',
    });
    await setDoc(doc(db, 'public_therapists/therapist-1'), {
      therapistId: 'therapist-1',
      userId: 'therapist-1',
      displayName: 'Dr. Noor',
      professionalTitle: 'Licensed Clinical Psychologist',
      specialty: 'CBT',
      acceptingNewPatients: true,
      isApproved: true,
      credentialVerificationStatus: 'verified',
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  await assertSucceeds(
    getDoc(doc(alice.firestore(), 'public_therapists/therapist-1')),
  );
});

test('therapist cannot publish a public directory profile before approval', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: false,
      credentialVerificationStatus: 'pending_review',
    });
  });

  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertFails(
    setDoc(doc(therapist.firestore(), 'public_therapists/therapist-1'), {
      therapistId: 'therapist-1',
      userId: 'therapist-1',
      displayName: 'Dr. Noor',
      professionalTitle: 'Clinical Psychologist',
      specialty: 'CBT',
      acceptingNewPatients: true,
      isApproved: true,
      credentialVerificationStatus: 'verified',
    }),
  );
});

test('approved therapist can update only safe public directory fields', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapists/therapist-1'), {
      userId: 'therapist-1',
      isApproved: true,
      credentialVerificationStatus: 'verified',
    });
    await setDoc(doc(db, 'public_therapists/therapist-1'), {
      therapistId: 'therapist-1',
      userId: 'therapist-1',
      displayName: 'Dr. Noor',
      professionalTitle: 'Clinical Psychologist',
      specialty: 'CBT',
      acceptingNewPatients: true,
      isApproved: true,
      credentialVerificationStatus: 'verified',
    });
  });

  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertSucceeds(
    updateDoc(doc(therapist.firestore(), 'public_therapists/therapist-1'), {
      bio: 'Trauma-informed CBT therapist.',
      acceptingNewPatients: false,
    }),
  );
  await assertFails(
    updateDoc(doc(therapist.firestore(), 'public_therapists/therapist-1'), {
      credentialVerificationStatus: 'pending_review',
    }),
  );
});

test('client cannot create therapist chat rooms directly', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await assertFails(
    setDoc(doc(alice.firestore(), 'therapist_chats/room-1'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      relationshipType: 'prospect',
      canCall: false,
      participants: ['alice', 'therapist-1'],
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );
});

test('participants cannot rewrite therapist chat room identities', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapist_chats/room-2'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      relationshipType: 'appointment',
      appointmentId: 'apt-5',
      canCall: true,
      participants: ['alice', 'therapist-1'],
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  await assertFails(
    updateDoc(doc(alice.firestore(), 'therapist_chats/room-2'), {
      participants: ['alice', 'mallory'],
    }),
  );
});

test('client cannot create call rooms directly', async () => {
  const therapist = testEnv.authenticatedContext('therapist-1');
  await assertFails(
    setDoc(doc(therapist.firestore(), 'calls/call-1'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      appointmentId: 'apt-6',
      participants: ['alice', 'therapist-1'],
      status: 'ready',
      createdAt: new Date(),
      updatedAt: new Date(),
    }),
  );
});

test('signed-in user can read app config but cannot write it', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'app_config/mobile'), {
      backendUrl: 'https://api.example.com',
    });
  });

  const user = testEnv.authenticatedContext('alice');
  await assertSucceeds(getDoc(doc(user.firestore(), 'app_config/mobile')));
  await assertFails(
    setDoc(doc(user.firestore(), 'app_config/mobile'), {
      backendUrl: 'https://evil.example.com',
    }),
  );
});

test('user can manage their own notification preference and device docs', async () => {
  const alice = testEnv.authenticatedContext('alice');
  await assertSucceeds(
    setDoc(doc(alice.firestore(), 'users/alice/preferences/notifications'), {
      pushEnabled: true,
      emailEnabled: false,
      inAppEnabled: true,
      timezone: 'Asia/Karachi',
    }),
  );
  await assertSucceeds(
    setDoc(doc(alice.firestore(), 'users/alice/devices/device-1'), {
      fcmToken: 'abc123',
      platform: 'ios',
      pushPermissionStatus: 'authorized',
      tokenStatus: 'active',
    }),
  );
});

test('user can mark their notification as read but cannot change immutable fields', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice/notifications/note-1'), {
      type: 'appointment_confirmed',
      title: 'Appointment confirmed',
      body: 'Your appointment is confirmed.',
      previewTitle: 'MoodGenie appointment update',
      previewBody: 'You have a new appointment notification.',
      channel: 'in_app',
      deepLink: 'moodgenie://appointments/apt-1?role=user',
      metadata: { appointmentId: 'apt-1' },
      createdAt: new Date(),
      sentAt: new Date(),
      read: false,
      status: 'sent',
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  await assertSucceeds(
    updateDoc(doc(alice.firestore(), 'users/alice/notifications/note-1'), {
      read: true,
      status: 'read',
      readAt: new Date(),
    }),
  );
  await assertFails(
    updateDoc(doc(alice.firestore(), 'users/alice/notifications/note-1'), {
      title: 'Tampered title',
    }),
  );
});

test('non-owner cannot read another users notification artifacts', async () => {
  await seed(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice/notifications/note-2'), {
      type: 'mood_quote',
      title: 'Quote',
      body: 'Take a breath.',
      previewTitle: 'MoodGenie check-in',
      previewBody: 'You have a new wellness notification.',
      channel: 'in_app',
      deepLink: 'moodgenie://mood/history',
      metadata: {},
      createdAt: new Date(),
      sentAt: new Date(),
      read: false,
      status: 'sent',
    });
    await setDoc(doc(db, 'users/alice/mood_forecasts/2026-04-13'), {
      forecastDate: '2026-04-13',
      predictedMoodBand: 'neutral',
      confidence: 0.71,
    });
  });

  const mallory = testEnv.authenticatedContext('mallory');
  await assertFails(
    getDoc(doc(mallory.firestore(), 'users/alice/notifications/note-2')),
  );
  await assertFails(
    getDoc(doc(mallory.firestore(), 'users/alice/mood_forecasts/2026-04-13')),
  );
});
