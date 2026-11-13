# Local ComfyUI render worker

This Windows tool renders review PNGs with the FLUX.2 Klein 4B base image-edit API export. It polls one GitHub repository over HTTPS and sends requests only to ComfyUI on `127.0.0.1:8188`. It is a separate preview tool alongside SpriteKiln.

## Set up on the render PC

1. Open PowerShell 7.4 or later in the repository checkout on `claude/godot-port`. Start your usual ComfyUI installation with its listener set to `127.0.0.1` and port `8188`. For a command-line installation use `--listen 127.0.0.1 --port 8188`. Keep the listener local.
2. In the ComfyUI model search paths, make these exact filenames available:

   | Folder | File |
   | --- | --- |
   | `models/diffusion_models` | `flux-2-klein-base-4b-fp8.safetensors` |
   | `models/text_encoders` | `qwen_3_4b.safetensors` |
   | `models/vae` | `full_encoder_small_decoder.safetensors` |

3. Run the preflight. It checks the Windows listener, reported CUDA device, registered workflow nodes, and three model filenames.

   ```powershell
   ./godot/tools/comfyui/worker.ps1 -Check
   ```

4. Create the local reference folder. Place only images approved for local rendering here. A reference alias resolves to one PNG in this folder. Use lowercase letters, digits, underscores or hyphens, beginning with a letter. Files must be at most 12 MiB, 64–4096 pixels per side, and at most 8:1 in aspect ratio.

   ```powershell
   $renderData = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Hollowmark\ComfyUI'
   New-Item -ItemType Directory -Force (Join-Path $renderData 'references') | Out-Null
   ```

   To use a different local folder, pass the same `-DataDirectory` to each invocation.

## One-image Lyla smoke test

Copy Lyla's approved reference to `references/lyla.png` under the data folder. Run:

```powershell
./godot/tools/comfyui/worker.ps1 -Smoke
```

This uses the bundled [Lyla job](lyla-smoke.json), with fixed seed 424242. It requires only local ComfyUI and saves one `lyla-smoke-<id>.png` in `results`. Open the file to check identity, pose, and framing. The output is a review image and requires a separate approval and conversion before game use.

## Enable the GitHub queue

1. In [JoelsCodes/Tactics-game Issues](https://github.com/JoelsCodes/Tactics-game/issues), create the label `comfy-render-queued` if needed.
2. Create a short-lived [fine-grained GitHub token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) for **only** `JoelsCodes/Tactics-game`. Set **Issues: Read and write** and leave the automatic metadata permission. The worker uses Issues for polling and status comments. It requires no write access to files, Actions, or other repositories.
3. Enter the token in the worker's PowerShell window. The hidden input keeps it out of the typed command and the variable lasts for this process. Run the worker in the foreground and stop it with Ctrl+C. Clear the variable after use.

   ```powershell
   $env:HOLLOWMARK_GITHUB_TOKEN = Read-Host 'GitHub render token' -MaskInput
   try {
       ./godot/tools/comfyui/worker.ps1
   } finally {
       Remove-Item Env:HOLLOWMARK_GITHUB_TOKEN
   }
   ```

   Add `-Once` for a single queue pass. Keep one worker on one PC with the same data folder. A local lock prevents two processes using that folder concurrently.

4. As `JoelsCodes`, open an issue whose entire body is the raw JSON from [lyla-smoke.json](lyla-smoke.json), without Markdown fences. Apply `comfy-render-queued` when ready. The worker only accepts open issues created by the fixed numeric owner ID, with this label and the exact four job fields. The fields choose the approved workflow profile, a local reference alias, a prompt of up to 1,500 characters, and an integer seed from 0 to 2,147,483,647. Remove the label or close the issue to take it out of the queue before submission.
5. The worker checks about once per minute when idle. On completion it downloads the PNG to `results/issue-<number>.png` and comments on the issue with its status and SHA-256. Inspect the PNG locally and attach it to the issue if the repository's audience may see it. Treat issue prompts and comments as visible to anyone with issue access. Local references and generated image bytes stay on the PC until you share them.

The `state` folder records submissions and reporting across restarts. Keep it intact. After a lost submission response the worker reports uncertainty and holds that issue. Check ComfyUI's local history before making a fresh issue for a retry. A 30-minute wait limit leaves the ComfyUI job alone. If an issue fails validation or is missing its local reference, correct it and the worker will pick it up on a later pass. ComfyUI also retains uploaded copies and generated output in its normal input/output directories.

## Workflow reviewed

The bundled API JSON is the original export, pinned by SHA-256 with normalized line endings. The worker removes disconnected example loader `81` and substitutes the uploaded reference at `76.inputs.image`, prompt at `75:74.inputs.text`, seed at `75:73.inputs.noise_seed`, and a worker-owned output prefix at `9.inputs.filename_prefix`. Loader `76` flows through 1-megapixel scaling, VAE encoding and both ReferenceLatent nodes. The scaled image also supplies the scheduler and latent dimensions. The export uses Euler, 20 steps, CFG 5, an empty negative prompt, and batch size one. GitHub issue data cannot supply nodes, model filenames, paths, URLs, or output destinations.

[ComfyUI API routes](https://docs.comfy.org/development/comfyui-server/comms_routes) · [GitHub issue comments API](https://docs.github.com/en/rest/issues/comments)

