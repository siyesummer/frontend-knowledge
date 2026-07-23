SET @client_ip_column_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_message'
      AND COLUMN_NAME = 'client_ip'
);

SET @add_client_ip_column_sql = IF(
    @client_ip_column_exists = 0,
    'ALTER TABLE chat_message ADD COLUMN client_ip VARCHAR(45) DEFAULT NULL AFTER sender_id',
    'SELECT ''client_ip column already exists'' AS migration_status'
);

PREPARE add_client_ip_column_statement FROM @add_client_ip_column_sql;
EXECUTE add_client_ip_column_statement;
DEALLOCATE PREPARE add_client_ip_column_statement;

SET @client_ip_index_exists = (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'chat_message'
      AND INDEX_NAME = 'idx_chat_message_client_ip'
);

SET @add_client_ip_index_sql = IF(
    @client_ip_index_exists = 0,
    'CREATE INDEX idx_chat_message_client_ip ON chat_message (client_ip)',
    'SELECT ''client_ip index already exists'' AS migration_status'
);

PREPARE add_client_ip_index_statement FROM @add_client_ip_index_sql;
EXECUTE add_client_ip_index_statement;
DEALLOCATE PREPARE add_client_ip_index_statement;
