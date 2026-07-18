// violating fixture: middleware 无 matcher 配置
// → fw_nextjs_middleware_matcher(fail)
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  // 无 matcher：默认拦截全站（含静态资源），性能差
  return NextResponse.next();
}
