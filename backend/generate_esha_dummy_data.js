require('dotenv').config();
const admin = require('firebase-admin');

try {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.log("Using GOOGLE_APPLICATION_CREDENTIALS path:", process.env.GOOGLE_APPLICATION_CREDENTIALS);
    admin.initializeApp({
      projectId,
      credential: admin.credential.applicationDefault()
    });
  } else if (projectId) {
    console.log("Initializing with projectId:", projectId);
    admin.initializeApp({
      projectId,
      credential: admin.credential.applicationDefault()
    });
  } else {
    console.log("Falling back to application default credentials...");
    admin.initializeApp();
  }
} catch (e) {
  console.error("Failed to initialize Firebase Admin:", e.message);
  process.exit(1);
}

const db = admin.firestore();
const userId = "nbHfMfxB1Ic2x0au88Fiaf9vnZn2"; // User: eshafarrukh729@gmail.com

const moodPool = [
  { mood: 'Great', intensity: 9, note: 'Had an amazing day today, got a lot of work done!' },
  { mood: 'Good', intensity: 7, note: 'Pretty good day, finished my studies and went for a run.' },
  { mood: 'Okay', intensity: 5, note: 'Standard day. Nothing special but feeling fine.' },
  { mood: 'Calm', intensity: 6, note: 'A very peaceful day, spent some time reading and relaxing.' },
  { mood: 'Anxious', intensity: 4, note: 'Felt a bit anxious about the upcoming projects today.' },
  { mood: 'Sad', intensity: 3, note: 'Felt a little down and tired today. Rested in the evening.' },
  { mood: 'Excited', intensity: 8, note: 'Very excited about the upcoming weekend and meeting friends!' },
  { mood: 'Grateful', intensity: 8, note: 'Grateful for the support from my family and friends.' },
  { mood: 'Confident', intensity: 8, note: 'Felt confident in my presentations and code review today.' },
  { mood: 'Loved', intensity: 9, note: 'Spent quality time with family, feeling loved and supported.' },
];

async function generateData() {
  console.log(`Checking existing mood entries for user: ${userId}`);
  
  try {
    const snapshot = await db.collection('moods').where('userId', '==', userId).get();
    if (!snapshot.empty) {
      console.log(`Deleting ${snapshot.size} existing mood entries to avoid duplicates...`);
      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log("Deleted old entries successfully.");
    }
  } catch (error) {
    console.error("Error during clean up of old entries:", error.message);
  }

  console.log(`Generating 30 days of dummy data for user: ${userId}`);
  let count = 0;

  // Generate data for the past 30 days (from 29 days ago up to today)
  for (let i = 29; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    // Distribute time slightly to look natural (e.g. afternoon around 12:00 - 16:00)
    const hour = 10 + Math.floor(Math.random() * 8);
    const minute = Math.floor(Math.random() * 60);
    date.setHours(hour, minute, 0, 0);

    const randomConfig = moodPool[Math.floor(Math.random() * moodPool.length)];

    const data = {
      userId: userId,
      mood: randomConfig.mood,
      intensity: randomConfig.intensity,
      note: randomConfig.note,
      selectedDate: admin.firestore.Timestamp.fromDate(date),
      createdAt: admin.firestore.Timestamp.fromDate(date),
    };

    try {
      await db.collection('moods').add(data);
      count++;
      console.log(`Added mood entry for ${date.toISOString().split('T')[0]} at ${hour}:${minute.toString().padStart(2, '0')}`);
    } catch (error) {
      console.error(`Error adding data for index ${i}:`, error.message);
    }
  }

  console.log(`Successfully generated ${count} mood entries.`);
  process.exit(0);
}

generateData();
