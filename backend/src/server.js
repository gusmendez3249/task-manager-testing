'use strict';

const { app } = require('./app');
const { config } = require('./config');
const { migrate } = require('./db');

migrate()
  .then(() => {
    app.listen(config.port, () => {
      const mode = config.useMemoryDb ? 'in-memory database (demo only)' : 'PostgreSQL';
      console.log(`Task Manager API listening on http://localhost:${config.port} using ${mode}`);
    });
  })
  .catch((error) => {
    console.error('Could not start the API:', error.message);
    process.exitCode = 1;
  });
