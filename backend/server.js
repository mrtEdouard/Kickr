'use strict';
const express = require('express');
const cors = require('cors');
const path = require('path');
const authRoutes   = require('./routes/auth');
const eventsRoutes = require('./routes/events');
const notifRoutes  = require('./routes/notifications');
const { initDb } = require('./db/database');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors({
  origin: /^http:\/\/localhost(:\d+)?$/,
  credentials: true,
}));
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

initDb();

app.use('/auth', authRoutes);
app.use('/events', eventsRoutes);
app.use('/notifications', notifRoutes);


app.listen(PORT, () => {
  console.log(`Kickr backend running on http://localhost:${PORT}`);
});
