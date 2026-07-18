package com.example.dubbo;

import org.apache.dubbo.config.annotation.DubboService;

/**
 * compliant fixture:
 *  - @DubboService 显式 version + timeout（幂等读接口 retries=0 显式声明为 0，不触发重试告警）
 *  - qos 仅本机（默认），注册中心地址已配 → 全 pass
 *
 * 期望：bash run-framework-fixture.sh dubbo → compliant 退出码 == 0（PASS）
 */
@DubboService(version = "1.0.0", timeout = 3000)
public class OrderServiceImpl {
    public String createOrder(String sku, int count) {
        return "ok";
    }
}
