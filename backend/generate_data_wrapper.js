const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

// Change this to the user ID you want to insert the data for
const userId = "l0UZvAHo9nVXkEyvIQoJmdj2wI23"; // Replace if needed

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

    // Generate data for the past 30 days
    for (let i = 0; i < 30; i++) {
        const date = new Date();
        date.setDate(date.getDate() - i);

        // Randomly select a mood
        const randomConfig = moods[Math.floor(Math.random() * moods.length)];

        const data = {
            userId: userId,
            mood: randomConfig.mood,
            intensity: randomConfig.intensity,
            note: randomConfig.note,
            selectedDate: admin.firestore.Timestamp.fromDate(date),
            createdAt: admin.firestore.Timestamp.now(), // Keep creation time as now but selected date in the past
        };

        try {
            await db.collection('moods').add(data);
            count++;
            console.log(`Added data for ${date.toISOString().split('T')[0]}`);
        } catch (error) {
            console.error(`Error adding data:`, error);
        }
    }
    console.log(`Successfully generated ${count} mood entries.`);
    process.exit(0);
}

generateData();
