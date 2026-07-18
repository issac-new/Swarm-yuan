-- violating: max(id)+1 应用层取号 + 双侧通配 LIKE 无 pg_trgm
SELECT max(id)+1 FROM users;
SELECT id, name FROM users WHERE name LIKE '%张%';
