import { defineConfig } from 'vitest/config';

// violating fixture: 无覆盖率阈值 + globals:true + 无 environment + 残留 jest.fn
export default defineConfig({
  test: {
    globals: true,
    include: ['src/**/*.{test,spec}.ts', 'tests/**/*.test.ts'],
  },
});
