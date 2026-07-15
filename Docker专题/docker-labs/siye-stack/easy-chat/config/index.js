const LISTENING_PORT = process.env.LISTENING_PORT || '3030';
const SERVER_HOST = process.env.SERVER_HOST || '127.0.0.1';

module.exports = {
  LISTENING_PORT,
  CONNECT_URL: `http://${SERVER_HOST}:${LISTENING_PORT}`,
};
