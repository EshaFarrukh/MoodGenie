const path = require('node:path');
const fs = require('node:fs/promises');
const test = require('node:test');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');
const { ref, uploadString } = require('firebase/storage');

const projectId = 'moodgenie-storage-rules';
const firestoreRulesPath = path.resolve(__dirname, '../firestore.rules');
const storageRulesPath = path.resolve(__dirname, '../storage.rules');

let testEnv;

test.before(async () => {
  const [firestoreRules, storageRules] = await Promise.all([
    fs.readFile(firestoreRulesPath, 'utf8'),
    fs.readFile(storageRulesPath, 'utf8'),
  ]);

  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
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
    await testEnv.clearStorage();
  }
});

test('chat participant can upload therapist chat media', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapist_chats/alice_therapist-1'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      participants: ['alice', 'therapist-1'],
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  const storage = alice.storage();
  await assertSucceeds(
    uploadString(
      ref(storage, 'therapist_chats/alice_therapist-1/alice/sample.txt'),
      'hello world',
    ),
  );
});

test('non-participant cannot upload therapist chat media', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapist_chats/alice_therapist-1'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      participants: ['alice', 'therapist-1'],
    });
  });

  const mallory = testEnv.authenticatedContext('mallory');
  const storage = mallory.storage();
  await assertFails(
    uploadString(
      ref(storage, 'therapist_chats/alice_therapist-1/mallory/sample.txt'),
      'unauthorized',
    ),
  );
});

test('participant cannot upload media into another participant folder', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'therapist_chats/alice_therapist-1'), {
      userId: 'alice',
      therapistId: 'therapist-1',
      participants: ['alice', 'therapist-1'],
    });
  });

  const alice = testEnv.authenticatedContext('alice');
  const storage = alice.storage();
  await assertFails(
    uploadString(
      ref(
        storage,
        'therapist_chats/alice_therapist-1/therapist-1/unauthorized.txt',
      ),
      'unauthorized',
    ),
  );
});
