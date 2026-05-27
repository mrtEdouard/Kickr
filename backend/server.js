'use strict';
const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const eventsRoutes = require('./routes/events');
const { initDb } = require('./db/database');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: /^http:\/\/localhost(:\d+)?$/,
  credentials: true,
}));
app.use(express.json());

initDb();

app.use('/auth', authRoutes);
app.use('/events', eventsRoutes);


app.listen(PORT, () => {
  console.log(`Kickr backend running on http://localhost:${PORT}`);
});
