// compliant fixture 服务：
//  - where 用 Object 条件/参数绑定（防注入）
//  - 分页走 findAndCount take/skip（非 offset/limit）
//  - 软删除实体走 softDelete
import { AppDataSource } from '../data-source';
import { User } from '../entity/User';

export class UserService {
  async findByName(name: string, page = 1, pageSize = 20) {
    return AppDataSource.getRepository(User)
      .findAndCount({
        where: { name },
        relations: ['posts'],
        take: pageSize,
        skip: (page - 1) * pageSize,
      });
  }

  async removeUser(id: number) {
    await AppDataSource.getRepository(User).softDelete(id);
  }
}
