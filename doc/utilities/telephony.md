# Telephony

Use `Telephony` when an application should ask the platform to start a phone
call.

```dart
final launched = await Telephony().call(
  number: '+55 (11) 98888-7777',
);
```

The utility preserves a leading `+`, removes other formatting characters, and
passes a `tel:` URI to the platform. It returns whether the platform accepted
the launch.

Always include the country code. `Telephony` sanitizes URI input but does not
infer a country code or verify that a phone number exists. A value without any
digits throws `ArgumentError`.
