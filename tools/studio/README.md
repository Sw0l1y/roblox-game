# Studio on the PC, driven from the cloud

`rbx-worker.ps1` runs on the Windows PC (in `C:\Users\david\Adamantium\.roblox5\`, started once by hand; it quits
after 72 h idle). The cloud session writes task files into its `inbox\` with the device folder tools and reads
results from `outbox\<task>\` (log.txt, results.json, screenshots). Task kinds are listed at the top of the script.
`mcp-call.ps1` is the stdio client for Studio's MCP server (`StudioMCP.exe`), used by `mcp` tasks.

- `apply_ids.py <results.json>...`: copies generated MaterialVariant maps and mesh/texture ids into the games.
- `playtest_task.py <game> <seq> <dir>`: writes "open the place, play, screenshot, run debug commands" tasks.

Built places go to `.roblox5\places\` (only files there can be opened).
