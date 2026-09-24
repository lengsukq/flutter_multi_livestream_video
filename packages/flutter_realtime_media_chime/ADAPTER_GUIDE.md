# AWS Chime adapter guide

`flutter_realtime_media_chime` wraps the existing `flutter_aws_chime`
v3 Dart/native bridge instead of rewriting the stable iOS/Android layer.

The adapter deliberately registers only `MediaRole.participant`. The current
Chime implementation is a symmetric meeting client and does not yet have a
backend-enforced host/viewer broadcast permission split, so those roles are
rejected rather than falsely advertised.

Legacy Chime backends remain compatible: missing `provider`, `role`, and
`participantId` are resolved from the request and `attendee.AttendeeId`.

Existing apps may keep using `flutter_aws_chime` directly; the new adapter is
optional and depends on the old package, not the reverse.

Local development:

```bash
cd demo-server
npm start
```

Then open `http://127.0.0.1:3000/` and select AWS Chime.

The helper uses `AWS_PROFILE=chime-demo` by default unless overridden.
