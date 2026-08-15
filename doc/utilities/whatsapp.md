# Whatsapp

Use `Whatsapp` to open a chat with an optional pre-filled message.

```dart
final launched = await Whatsapp().launchChat(
  number: '+55 (11) 98888-7777',
  message: 'Hello! I would like more information.',
);
```

On mobile, the utility first tries the native WhatsApp URI and falls back to
`wa.me` when the application is unavailable. On web, it uses `wa.me` directly.
It returns whether the platform accepted the launch.

Always include the country code. Formatting characters are removed, but the
utility does not infer a country code or verify that the number exists. A value
without any digits throws `ArgumentError`.
