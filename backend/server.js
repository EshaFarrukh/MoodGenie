require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

const apiKey = process.env.GEMINI_API_KEY;

let genAI;
let model;

if (apiKey && apiKey !== 'YOUR_API_KEY_HERE') {
  genAI = new GoogleGenerativeAI(apiKey);
  model = genAI.getGenerativeModel({
    model: "gemini-1.5-flash",
    systemInstruction: "You are MoodGenie, an empathetic and supportive AI wellness companion. You provide emotional support and general wellness guidance. You are NOT a licensed therapist or medical professional. Always be kind, supportive, and concise.",
  });
}

app.post('/api/chat', async (req, res) => {
  try {
    const { message, history } = req.body;
    
    if (!message) {
      return res.status(400).json({ error: "Message is required" });
    }

    if (!model) {
      // Fallback response if API key isn't provided or valid
      console.warn("API Key not configured. Using fallback.");
      return res.json({ text: "I'm sorry, my AI brain isn't connected right now. Please add your Gemini API key to the backend .env file!" });
    }

    // Convert history to Gemini format (role: user/model)
    const formattedHistory = (history || []).map(msg => ({
      role: msg.isUser ? "user" : "model",
      parts: [{ text: msg.text }]
    }));

    const chat = model.startChat({
      history: formattedHistory
    });

    const result = await chat.sendMessage(message);
    const response = await result.response;
    const text = response.text();

    res.json({ text });
  } catch (error) {
    console.error("Error calling Gemini API:", error);
    res.status(500).json({ error: "Failed to generate AI response" });
  }
});

app.listen(port, () => {
  console.log(`MoodGenie backend listening at http://localhost:${port}`);
});
