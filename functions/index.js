// functions/index.js
const functions = require('firebase-functions');

exports.getGeminiApiKey = functions.https.onCall(async (data, context) => {
  const apiKey = functions.config().gemini.apikey;
  return { apiKey: apiKey };
});