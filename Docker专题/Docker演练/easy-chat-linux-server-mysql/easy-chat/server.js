const app = require('express')();
const http = require('http').createServer(app);
const socketIo = require('socket.io');
const logger = require('siye-core/src/utils/logger');
const {
  LISTENING_PORT,
  CONNECT_URL,
} = require('./config');

const SERVICE_NAME = 'socket';
const CHINA_TIME_FORMATTER = new Intl.DateTimeFormat('zh-CN', {
  timeZone: 'Asia/Shanghai',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false,
});

function stringifyExtra(extra = {}) {
  const entries = Object.entries(extra).filter(([, value]) => value !== undefined && value !== null && value !== '');
  if (!entries.length) {
    return '';
  }
  return ` ${JSON.stringify(Object.fromEntries(entries))}`;
}

function formatTimestamp() {
  const now = new Date();
  const parts = Object.fromEntries(CHINA_TIME_FORMATTER.formatToParts(now)
    .filter(part => part.type !== 'literal')
    .map(part => [part.type, part.value]));
  const milliseconds = String(now.getMilliseconds()).padStart(3, '0');
  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute}:${parts.second}.${milliseconds}`;
}

function writeLog(level, event, message, extra) {
  const text = `[${formatTimestamp()}] [${level}] [${SERVICE_NAME}] [${event}] ${message}${stringifyExtra(extra)}`;
  switch (level) {
    case 'ERROR':
      logger.error(text);
      break;
    case 'WARN':
      logger.warn(text);
      break;
    default:
      logger.info(text);
      break;
  }
}

function resolveClientIp(socket) {
  const forwardedFor = socket.handshake.headers['x-forwarded-for'];
  if (forwardedFor) {
    return forwardedFor.split(',')[0].trim();
  }
  return socket.handshake.address || '';
}

app.get('/health', (req, res) => {
  res.json({
    code: 0,
    service: SERVICE_NAME,
    status: 'ok',
    timestamp: formatTimestamp(),
  });
});

const io = socketIo(http, {
  cors: {
    origin: '*',
  }
});

io.on('connection', socket => {
  writeLog('INFO', 'connect', 'socket.io client connected', {
    socketId: socket.id,
    clientIp: resolveClientIp(socket),
    transport: socket.conn.transport.name,
  });

  socket.on('linkStart', msg => {
    writeLog('INFO', 'linkStart', 'received linkStart event', {
      socketId: socket.id,
      payload: msg,
    });
    io.emit('linkSuccess', msg);
  });

  socket.on('clientMsg', msg => {
    writeLog('INFO', 'clientMsg', 'received client message', {
      socketId: socket.id,
      payload: msg,
    });
    io.emit('backClientMsg', msg);
  });

  socket.on('disconnect', reason => {
    writeLog('WARN', 'disconnect', 'socket disconnected', {
      socketId: socket.id,
      reason,
    });
  });

  socket.on('error', error => {
    writeLog('ERROR', 'socketError', error && error.message ? error.message : String(error), {
      socketId: socket.id,
    });
  });
});

http.listen(LISTENING_PORT, () => {
  writeLog('INFO', 'startup', `listening on *:${LISTENING_PORT}`, {
    connectUrl: CONNECT_URL,
  });
});

process.on('uncaughtException', error => {
  writeLog('ERROR', 'uncaughtException', error && error.stack ? error.stack : String(error));
});

process.on('unhandledRejection', reason => {
  writeLog('ERROR', 'unhandledRejection', reason && reason.stack ? reason.stack : String(reason));
});
