// 合规模本：参数化查询（无字符串拼接），无 eval / new Function，密钥走环境变量
function findUser(req, db) {
  const sql = "SELECT * FROM users WHERE name = ?";
  return db.query(sql, [req.query.name]);
}

function loadConfig() {
  return { apiKey: process.env.API_KEY };
}

module.exports = { findUser, loadConfig };
