# consult-circe

Consult bindings for managing Circe buffers.

A port of [helm-circe](https://github.com/lesharris/helm-circe) by [Les Harris](https://github.com/lesharris) to the [consult](https://github.com/minad/consult).

A call to `consult-circe` will show a grouped list of server, channel, and query buffers currently open. From the list you can switch to any buffer, or use `consult-circe-kill-buffer` to part/disconnect/close one.

# Setup

```elisp
(require 'consult-circe)
(global-set-key (kbd "C-c c i") 'consult-circe)
(global-set-key (kbd "C-c c n") 'consult-circe-new-activity)
(global-set-key (kbd "C-c c k") 'consult-circe-kill-buffer)
```

# Commands

`consult-circe`
Main command. Displays channels, queries, and servers in grouped sections.

`consult-circe-new-activity`
Displays buffers that have had activity since last viewed, mirroring what
tracking-mode shows in the mode line.

`consult-circe-by-server`
Displays channels grouped by the server they belong to.

`consult-circe-channels`
Displays all channels in a single candidate list regardless of server.

`consult-circe-servers`
Displays all circe server buffers.

`consult-circe-queries`
Displays all circe query buffers.

`consult-circe-kill-buffer`
Prompts for a circe buffer to kill. Closing a channel buffer will /part
you from that channel; closing a server buffer will disconnect.
