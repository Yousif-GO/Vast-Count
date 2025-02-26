const fs = require('fs');

// Get API key from environment variable or .env file
let apiKey = process.env.GEMINI_API_KEY;

// If not found in environment, try to read from .env file
if (!apiKey) {
  try {
    const envFile = fs.readFileSync('./assets/.env', 'utf8');
    const match = envFile.match(/GEMINI_API_KEY=([^\r\n]+)/);
    if (match && match[1]) {
      apiKey = match[1];
    }
  } catch (e) {
    console.error('Error reading .env file:', e);
  }
}

if (!apiKey) {
  console.error('GEMINI_API_KEY not found in environment or .env file');
  process.exit(1);
}

const envJs = `
window.ENV = {
  GEMINI_API_KEY: "${apiKey}"
};
`;

// Create the directory if it doesn't exist
if (!fs.existsSync('./web')) {
  fs.mkdirSync('./web', { recursive: true });
}

// Write the environment variables to a JS file
fs.writeFileSync('./web/env.js', envJs);
console.log('Environment variables written to web/env.js'); 