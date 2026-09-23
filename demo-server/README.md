# Demo backend (keys stay here, never in Flutter)

## Run

```bash
cd demo-server
npm install
AWS_PROFILE=chime-demo node server.mjs
# or: PORT=3000 CHIME_MEDIA_REGION=ap-southeast-1 AWS_PROFILE=chime-demo npm start
```

Health check:

```bash
curl http://localhost:3000/health
```

## Flow (matches the link-join example app)

1. Create (host): `POST /meetings {"externalMeetingId":"demo-1"}`
2. Share the link: `chimedemo://join?meetingId=<MeetingId>&server=http://<lan-ip>:3000`
3. Join (each viewer): `POST /join {"meetingId":"<id>","userId":"user-xxx"}`
4. App builds `JoinInfo.fromJson({meeting, attendee})` → `MeetingView`
5. Done: `DELETE /meetings/<id>` (stops billing for future joins)

## Env

| var | default | note |
|---|---|---|
| `AWS_PROFILE` | — | must be `chime-demo` (least-privilege IAM) |
| `AWS_REGION` | `us-east-1` | Chime control plane |
| `CHIME_MEDIA_REGION` | `ap-southeast-1` | media region near CN |
| `PORT` | `3000` | — |
