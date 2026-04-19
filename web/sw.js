// Celume Ops — Push Notification Service Worker

self.addEventListener('push', (e) => {
  if (!e.data) return;
  const { title, body, data } = e.data.json();
  e.waitUntil(
    self.registration.showNotification(title, {
      body,
      data,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
    })
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();

  const data = e.notification.data || {};
  let path = '/';

  if (data.type === 'new_message' && data.conversation_id) {
    path = '/chat?conv=' + data.conversation_id;
  } else if (data.task_id) {
    path = '/tasks?task=' + data.task_id;
  }

  const targetUrl = self.location.origin + path;

  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if (c.url.startsWith(self.location.origin) && 'focus' in c) {
          c.focus();
          return c.navigate(targetUrl);
        }
      }
      return clients.openWindow(targetUrl);
    })
  );
});
