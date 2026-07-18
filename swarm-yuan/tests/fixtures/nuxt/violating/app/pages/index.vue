<script setup lang="ts">
// violating fixture:
//   - useAsyncData 无 key 参数 → fw_nuxt_fetch_key(fail)
//   - Date.now() 在 render 阶段（setup 顶层，非 onMounted）→ fw_nuxt_hydration(fail) 主触发
// 期望：bash run-framework-fixture.sh nuxt → violating 退出码 != 0（FAIL）
const { data } = await useAsyncData(() => $fetch('/api/now'));

// render 阶段调用 Date.now()：服务端渲染值 ≠ 客户端 hydration 值 → mismatch
const renderedAt = Date.now();
</script>

<template>
  <div>
    <p>data: {{ data }}</p>
    <p>rendered at: {{ renderedAt }}</p>
  </div>
</template>
