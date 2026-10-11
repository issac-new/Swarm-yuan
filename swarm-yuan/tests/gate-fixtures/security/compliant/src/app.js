// 合规模本：参数化查询（无字符串拼接），无 eval / new Function，密钥走环境变量
function findUser(req, db) {
  const sql = "SELECT * FROM users WHERE name = ?";
  return db.query(sql, [req.query.name]);
}

// R106-D13 豁免形态锁：拼接只发生在 ? 绑定值实参位（SQL 字面量本身是常量）——
// GORM Where("... LIKE ?", "%"+name+"%") 同款写法，曾被子查询关键字误判注入
function searchOrders(db, name) {
  return db.query("SELECT * FROM orders WHERE title LIKE ?", ["%" + name + "%"]);
}

function loadConfig() {
  return { apiKey: process.env.API_KEY };
}

module.exports = { findUser, searchOrders, loadConfig };
