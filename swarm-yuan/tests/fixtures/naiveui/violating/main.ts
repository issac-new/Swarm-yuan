import naive from 'naive-ui';
import { createApp } from 'vue';
import App from './Form.vue';

const app = createApp(App);
app.use(naive);
app.mount('#app');
