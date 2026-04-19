require('dotenv').config();
const admin = require('firebase-admin');

// Trying multiple approaches to initialize admin
try {
  // If GOOGLE_APPLICATION_CREDENTIALS is in .env or environment
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.log("Using GOOGLE_APPLICATION_CREDENTIALS path:", process.env.GOOGLE_APPLICATION_CREDENTIALS);
    admin.initializeApp({
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

const userId = "l0UZvAHo9nVXkEyvIQoJmdj2wI23";

const moods = [
    { mood: 'Great', intensity: 8, note: 'Had a fantastic day!' },
    { mood: 'Good', intensity: 7, note: 'Productive and feeling good.' },
    { mood: 'Okay', intensity: 5, note: 'Just a regular day.' },
    { mood: 'Bad', intensity: 4, note: 'Felt a bit down today.' },
    { mood: 'Terrible', intensity: 2, note: 'Everything went wrong.' },
    { mood: 'Anxious', intensity: 6, note: 'Worried about upcoming deadlines.' },
    { mood: 'Calm', intensity: 8, note: 'Relaxed and peaceful evening.' },
    { mood: 'Excited', intensity: 9, note: 'Looking forward to the weekend!' },
];

async function generateData() {
    console.log(`Generating 30 days of dummy data for user: ${userId}`);
    let count = 0;

    for (let i = 0; i < 30; i++) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        date.setHours(12, 0, 0, 0);

        const randomConfig = moods[Math.floor(Math.random() * moods.length)];

        const data = {
            userId: userId,
            mood: randomConfig.mood,
            intensity: randomConfig.intensity,
            note: randomConfig.note,
            selectedDate: admin.firestore.Timestamp.fromDate(date),
            createdAt: admin.firestore.Timestamp.now(),
        };

        try {
            await db.collection('moods').add(data);
            count++;
            console.log(`Add data for ${date.toISOString().split('T')[0]}`);
        } catch (error) {
            console.error(`Error adding data:`, error.message);
        }
    }
    console.log(`Successfully generated ${count} mood entries.`);
    process.exit(0);
}

generateData();
