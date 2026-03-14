# consult-circe

Consult bindings for managing Circe buffers.

Based on [helm-circe](https://github.com/lesharris/helm-circe) by [Les Harris](https://github.com/lesharris), this package provides [consult](https://github.com/minad/consult) bindings for managing Circe buffers.

A call to `consult-circe` will show a grouped list of server, channel, and query buffers currently open. Each candidate is annotated with its type and parent server name.

## Embark integration

If [embark](https://github.com/oantolin/embark) is installed, additional actions are available on any candidate via `embark-act`:

| Key | Action |
|-----|--------|
| `s` | Switch to buffer |
| `k` | Kill/part buffer |

To kill multiple buffers at once — equivalent to ibuffer's mark-and-delete — use `embark-act` then `E` to run `embark-export`, which opens the candidates in an Ibuffer buffer where you can mark and kill with the usual ibuffer commands.

## Installation

### use-package
```elisp
(use-package consult-circe
  :vc (:url "https://github.com/sashaaaaaaaaa/consult-circe"
	  :rev :newest))
```

### Elpaca
```elisp
(elpaca (consult-circe :host github :repo "sashaaaaaaaaa/consult-circe"))
```

or 

```elisp
(use-package consult-circe
  :ensure (:host github :repo "sashaaaaaaaaa/consult-circe"))
```

### straight
```elisp
(straight-use-package
 '(consult-circe :type git :host github :repo "sashaaaaaaaaa/consult-circe"))
```

## Setup

```elisp
(require 'consult-circe)
(global-set-key (kbd "C-c c i") 'consult-circe)
(global-set-key (kbd "C-c c n") 'consult-circe-new-activity)
(global-set-key (kbd "C-c c k") 'consult-circe-kill-buffer)

;; Optional: bind embark-export for ibuffer-style bulk kill
(keymap-set minibuffer-local-map "C-c e" #'embark-export)
```

## Commands

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
