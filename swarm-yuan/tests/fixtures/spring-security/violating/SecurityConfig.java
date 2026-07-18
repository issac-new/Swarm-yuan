package com.example.sec;

import org.springframework.context.annotation.Bean;
import org.springframework.security.config.annotation.authentication.builders.AuthenticationManagerBuilder;
import org.springframework.security.config.annotation.web.configuration.WebSecurityConfigurerAdapter;
import org.springframework.security.crypto.password.NoOpPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * violating fixture:
 *  - extends WebSecurityConfigurerAdapter（6.x 起移除）→ fw_ssec_adapter(fail)
 *  - NoOpPasswordEncoder 弱哈希 → fw_ssec_password_encoder(fail)
 *  - .password("plaintext123") 明文密码 → fw_ssec_plaintext_password(fail)
 *
 * 期望：bash run-framework-fixture.sh spring-security → violating 退出码 != 0（FAIL）
 */
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return NoOpPasswordEncoder.getInstance();
    }

    @Override
    protected void configure(AuthenticationManagerBuilder auth) throws Exception {
        auth.inMemoryAuthentication()
            .withUser("admin").password("plaintext123").roles("ADMIN");
    }
}
