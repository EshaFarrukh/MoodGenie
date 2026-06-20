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

const email = 'eshafarrukh729@gmail.com';

async function findUser() {
  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`Found user! Email: ${email}, UID: ${userRecord.uid}`);
  } catch (error) {
    console.error(`Error fetching user:`, error.message);
  }
  process.exit(0);
}

findUser();
