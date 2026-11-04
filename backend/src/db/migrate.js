'use strict';

const { migrate, pool } = require('./index');

migrate()
  .then(() => {
    console.log('Schema applied.');
    return pool.end();
  })
  .catch((error) => {
    console.error('Migration failed:', error.message);
    process.exitCode = 1;
  });
