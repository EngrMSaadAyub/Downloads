# Downloads

Free tools by Engr. Muhammad Saad Ayub. Pick a tool, download the file, and see its release notes (What's new).

| Tool | What it does | Latest | Download |
|---|---|---|---|
| **My PC Buddy** | A little hiker who lives on your desktop: walks on the taskbar and your windows, reminds you of things (with snooze), chats with you like a friend, and lets you chat with your friends (on your phone too, with Pocket Buddy). <br>*Windows 10 (1903+) / 11, nothing to install* | 1.5.0 <br>2026-10-15 | [MyPCBuddy-1.5.0.zip](https://github.com/EngrMSaadAyub/Downloads/releases/download/my-pc-buddy-v1.5.0/MyPCBuddy-1.5.0.zip) <br>[What's new](https://github.com/EngrMSaadAyub/Downloads/releases/tag/my-pc-buddy-v1.5.0) |

Older versions: [all releases](https://github.com/EngrMSaadAyub/Downloads/releases). Each release is tagged `<tool>-v<version>`.

Windows may warn about an unknown app the first time you run one: choose **More info** then **Run anyway**.

Android apps (`.apk`): download the file on your phone and open it; allow installing from your browser or files
app when Android asks, then tap **Install**.

## Publishing (for me)

Build the tool in its own repository, then from here:

```powershell
.\publish.ps1 -Tool <id> -Version <x.y.z> -File <path to zip> -Notes <notes.md>
```

A new tool also needs `-Name` and `-Description`. The script updates `tools.json`, keeps the notes in
`notes/<id>/<version>.md`, rebuilds this README, pushes, and creates the release. See `publish.ps1` for details.
