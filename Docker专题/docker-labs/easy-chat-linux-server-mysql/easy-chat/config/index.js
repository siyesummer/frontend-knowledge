const LISTENING_PORT = process.env.LISTENING_PORT || '3030';
const SERVER_HOST = process.env.SERVER_HOST || 'YOUR_SERVER_IP';

module.exports = {
  LISTENING_PORT,
  CONNECT_URL: `http://${SERVER_HOST}:${LISTENING_PORT}`,
  SOCKET_ORIGIN: `http://${SERVER_HOST}:8080`,
};
