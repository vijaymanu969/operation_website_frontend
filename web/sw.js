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
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      // Focus existing tab if open, otherwise open a new one.
      for (const c of list) {
        if (c.url.startsWith(self.location.origin) && 'focus' in c) {
          return c.focus();
        }
      }
      return clients.openWindow('/');
    })
  );
});
