so from next time when i create page i need to add here thats it ?
Yes — two places, both frontend-only:

lib/core/config/app_config.dart — add a constant: static const pageFoo = 'foo';
lib/features/users/user_management_screen.dart — add AppConfig.pageFoo to the _allPages list.
That makes it appear in the access picker. Then to actually wire the page itself you also need:

A route in app_router.dart (and add case '/foo': return AppConfig.pageFoo; in _pageNameForRoute so the route guard works).
A sidebar entry in celume_sidebar.dart gated by hasPageAccess(AppConfig.pageFoo).
No backend change needed — page_name is a freeform string, as your backend confirmed.