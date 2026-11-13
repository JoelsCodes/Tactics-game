#Requires -Version 7.4
[CmdletBinding(DefaultParameterSetName = 'Queue')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Check')][switch]$Check,
    [Parameter(Mandatory, ParameterSetName = 'Smoke')][switch]$Smoke,
    [Parameter(ParameterSetName = 'Queue')][switch]$Once,
    [string]$DataDirectory = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Hollowmark\ComfyUI')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$comfy = 'http://127.0.0.1:8188'
$github = 'https://api.github.com/repos/JoelsCodes/Tactics-game'
$ownerId = 103986644
$label = 'comfy-render-queued'
$profileName = 'flux2-klein-4b-v1'
$workflowPath = Join-Path $PSScriptRoot 'flux2-klein-4b.api.json'
# Pin the exact exported bytes (Git can convert the line endings on checkout).
$workflowText = [IO.File]::ReadAllText($workflowPath).Replace("`r`n", "`n")
$workflowHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($workflowText)))
if ($workflowHash -ne '033976DF70E8105B121C31B38AEFF12DB27EBCA94F7724506803BDC87910108D') { throw 'The bundled ComfyUI workflow failed its integrity check.' }

function Invoke-Comfy([string]$Route, [hashtable]$Options = @{}) {
    Invoke-RestMethod -Uri ($comfy + $Route) -NoProxy -MaximumRedirection 0 -TimeoutSec 45 @Options
}

function Assert-Loopback {
    $listeners = @(Get-NetTCPConnection -LocalPort 8188 -State Listen -ErrorAction SilentlyContinue)
    if (@($listeners | ForEach-Object LocalAddress) -notcontains '127.0.0.1' -or
        @($listeners | Where-Object LocalAddress -NotIn '127.0.0.1', '::1').Count) {
        throw 'Start ComfyUI bound only to loopback on port 8188.'
    }
}

function Test-Comfy {
    Assert-Loopback
    $stats = Invoke-Comfy '/system_stats'
    $devices = @($stats.devices | Where-Object type -EQ 'cuda')
    if (!$devices.Count) { throw 'ComfyUI did not report a CUDA device.' }
    $workflow = ConvertFrom-Json -AsHashtable -InputObject $workflowText
    $workflow.Remove('81')
    $info = Invoke-WebRequest -Uri "$comfy/object_info" -NoProxy -MaximumRedirection 0 -TimeoutSec 45
    $catalog = ConvertFrom-Json -AsHashtable -InputObject $info.Content -Depth 100
    foreach ($node in $workflow.Values) {
        if (!$catalog.Contains($node.class_type)) { throw "Missing node $($node.class_type)." }
    }
    foreach ($loader in @(@('75:70', 'unet_name'), @('75:71', 'clip_name'), @('75:72', 'vae_name'))) {
        $node = $workflow[$loader[0]]
        $inputName = $loader[1]
        $choices = $catalog[$node.class_type].input.required[$inputName][0]
        if ($choices -notcontains $node.inputs[$inputName]) { throw "Missing model $($node.inputs[$inputName])." }
    }
    Write-Host "ComfyUI preflight passed. CUDA device $($devices[0].name)."
}

function Read-Job([string]$Body) {
    if ($Body.Length -gt 4500) { throw 'Job body exceeds the size limit.' }
    $job = ConvertFrom-Json -InputObject $Body -AsHashtable -Depth 4
    if ($job -isnot [System.Collections.IDictionary] -or $job.Count -ne 4 -or
        $job['workflow'] -cne $profileName -or
        $job['reference'] -isnot [string] -or $job['reference'] -cnotmatch '^[a-z][a-z0-9_-]{0,63}$' -or
        $job['prompt'] -isnot [string] -or [string]::IsNullOrWhiteSpace($job['prompt']) -or $job['prompt'].Length -gt 1500 -or
        $job['seed'] -isnot [long] -or $job['seed'] -lt 0 -or $job['seed'] -gt 2147483647) {
        throw 'Expected workflow, reference, prompt and seed in the documented job format.'
    }
    return $job
}

function Read-Reference([string]$Alias) {
    $path = Join-Path $referenceDir "$Alias.png"
    $entry = Get-Item -LiteralPath $path -ErrorAction SilentlyContinue
    if (!$entry -or $entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        $entry.Length -lt 24 -or $entry.Length -gt 12MB) {
        throw "Stage a regular PNG under references/$Alias.png (up to 12 MiB)."
    }
    $bytes = [IO.File]::ReadAllBytes($entry.FullName)
    Assert-Png $bytes
    $width = [Buffers.Binary.BinaryPrimitives]::ReadUInt32BigEndian([byte[]]$bytes[16..19])
    $height = [Buffers.Binary.BinaryPrimitives]::ReadUInt32BigEndian([byte[]]$bytes[20..23])
    if ($width -lt 64 -or $height -lt 64 -or $width -gt 4096 -or $height -gt 4096 -or
        [Math]::Max($width, $height) / [Math]::Min($width, $height) -gt 8) {
        throw 'Reference dimensions must be 64 to 4096 pixels per side, with aspect ratio at most 8:1.'
    }
    return $entry
}

function Assert-Png([byte[]]$Bytes) {
    if ($Bytes.Length -lt 24 -or [Convert]::ToHexString($Bytes[0..7]) -ne '89504E470D0A1A0A' -or
        [Text.Encoding]::ASCII.GetString($Bytes, 12, 4) -cne 'IHDR') { throw 'Expected a PNG image.' }
}

function Write-Receipt([string]$Path, [hashtable]$Receipt) {
    $temp = "$Path.tmp"
    [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $Receipt))
    [IO.File]::Move($temp, $Path, $true)
}

function Start-Render([hashtable]$Job, [IO.FileInfo]$Reference, [string]$Key, [string]$ReceiptPath) {
    Assert-Loopback
    $uploadName = "$Key-$([guid]::NewGuid().ToString('N')).png"
    $form = [Net.Http.MultipartFormDataContent]::new()
    try {
        $image = [Net.Http.StreamContent]::new($Reference.OpenRead())
        $image.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new('image/png')
        $form.Add($image, 'image', $uploadName)
        $form.Add([Net.Http.StringContent]::new('input'), 'type')
        $uploaded = Invoke-Comfy '/upload/image' @{ Method = 'Post'; Body = $form }
    } finally { $form.Dispose() }
    if ($uploaded.name -cne $uploadName -or $uploaded.type -cne 'input' -or $uploaded.subfolder -ne '') {
        throw 'Unexpected response from ComfyUI image upload.'
    }

    $graph = ConvertFrom-Json -InputObject $workflowText -AsHashtable
    $graph.Remove('81')
    $graph['76'].inputs.image = $uploadName
    $graph['75:74'].inputs.text = $Job.prompt
    $graph['75:73'].inputs.noise_seed = $Job.seed
    $graph['9'].inputs.filename_prefix = "hollowmark/$Key"
    $body = ConvertTo-Json -InputObject @{ prompt = $graph } -Depth 12 -Compress

    # A lost POST response is ambiguous. Persist the attempt before submitting.
    $receipt = @{ phase = 'submitting'; prompt_id = ''; started = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    Write-Receipt $ReceiptPath $receipt
    $submitted = Invoke-Comfy '/prompt' @{ Method = 'Post'; ContentType = 'application/json; charset=utf-8'; Body = $body }
    if ($submitted.prompt_id -notmatch '^[a-f0-9-]{36}$') { throw 'ComfyUI returned no usable prompt ID.' }
    $receipt.phase = 'submitted'
    $receipt.prompt_id = $submitted.prompt_id
    Write-Receipt $ReceiptPath $receipt
    return $receipt
}

function Wait-Render([hashtable]$Receipt, [string]$Key, [string]$ReceiptPath) {
    $output = Join-Path $outputDir "$Key.png"
    while ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt ($Receipt.started + 1800)) {
        $id = $Receipt.prompt_id
        $result = Invoke-Comfy "/history/$id"
        $history = $result.PSObject.Properties[$id]
        if (!$history) { Start-Sleep -Seconds 3; continue }
        $run = $history.Value
        if ($run.status.status_str -ne 'success' -or !$run.status.completed) {
            $Receipt.phase = 'failed'
            Write-Receipt $ReceiptPath $Receipt
            return
        }
        $images = @($run.outputs.'9'.images)
        if ($images.Count -ne 1 -or $images[0].type -cne 'output' -or $images[0].subfolder -cne 'hollowmark' -or
            $images[0].filename -cnotmatch ('^' + [regex]::Escape($Key) + '_[0-9]+_\.png$')) {
            throw 'ComfyUI returned an unexpected output.'
        }
        $name = [uri]::EscapeDataString($images[0].filename)
        $png = Invoke-WebRequest -Uri "$comfy/view?filename=$name&subfolder=hollowmark&type=output" -NoProxy -MaximumRedirection 0 -TimeoutSec 45
        Assert-Png $png.Content
        [IO.File]::WriteAllBytes("$output.tmp", $png.Content)
        [IO.File]::Move("$output.tmp", $output, $true)
        $Receipt.phase = 'complete'
        $Receipt.sha256 = (Get-FileHash -LiteralPath $output).Hash
        Write-Receipt $ReceiptPath $Receipt
        Write-Host "Saved $output"
        return
    }
    $Receipt.phase = 'timed-out'
    Write-Receipt $ReceiptPath $Receipt
}

function Invoke-GitHub([string]$Route, [hashtable]$Options = @{}) {
    Invoke-RestMethod -Uri ($github + $Route) -Headers $headers -MaximumRedirection 0 -TimeoutSec 30 @Options
}

function Publish-Result([long]$Number, [hashtable]$Receipt, [string]$Key) {
    $marker = "<!-- hollowmark-comfy:$Key -->"
    $message = switch ($Receipt.phase) {
        'complete' { "Rendered one PNG for review: **$Key.png** (SHA-256: $($Receipt.sha256)). The PNG is on the render PC. Attach it here after local review if it can be shared with this repository." }
        'failed' { 'ComfyUI reported a render failure. Inspect its local history before queueing a new issue.' }
        'timed-out' { 'The worker stopped waiting after 30 minutes. Check the local ComfyUI queue/history before queueing a new issue.' }
        'submitting' { 'Submission is uncertain. Check the local ComfyUI queue/history before queueing a new issue.' }
    }
    for ($page = 1; ; $page++) {
        $comments = @(Invoke-GitHub "/issues/$Number/comments?per_page=100&page=$page" | ForEach-Object { $_ })
        if ($comments | Where-Object { $_.user.id -eq $reporterId -and $_.body.StartsWith($marker) }) { return }
        if ($comments.Count -lt 100) { break }
    }
    $body = ConvertTo-Json -InputObject @{ body = "$marker`n`n$message" } -Compress
    $null = Invoke-GitHub "/issues/$Number/comments" @{ Method = 'Post'; ContentType = 'application/json; charset=utf-8'; Body = $body }
}

Test-Comfy
if ($Check) { return }

$DataDirectory = [IO.Path]::GetFullPath($DataDirectory)
$referenceDir = Join-Path $DataDirectory 'references'
$outputDir = Join-Path $DataDirectory 'results'
$stateDir = Join-Path $DataDirectory 'state'
foreach ($dir in $DataDirectory, $referenceDir, $outputDir, $stateDir) {
    $entry = [IO.Directory]::CreateDirectory($dir)
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Use ordinary local data directories.' }
}
$lock = [IO.File]::Open((Join-Path $stateDir 'worker.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    if ($Smoke) {
        $job = Read-Job ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'lyla-smoke.json')))
        $reference = Read-Reference $job.reference
        $key = "lyla-smoke-$([guid]::NewGuid().ToString('N'))"
        $receiptPath = Join-Path $stateDir "$key.json"
        $receipt = Start-Render $job $reference $key $receiptPath
        Wait-Render $receipt $key $receiptPath
        if ($receipt.phase -ne 'complete') { throw "Smoke test ended in state $($receipt.phase)." }
        return
    }

    if (!$env:HOLLOWMARK_GITHUB_TOKEN) { throw 'Set HOLLOWMARK_GITHUB_TOKEN in this PowerShell session.' }
    $headers = @{
        Authorization = "Bearer $env:HOLLOWMARK_GITHUB_TOKEN"
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $reporter = Invoke-RestMethod 'https://api.github.com/user' -Headers $headers -MaximumRedirection 0 -TimeoutSec 30
    $reporterId = $reporter.id
    do {
        try {
            for ($page = 1; ; $page++) {
                $issues = @(Invoke-GitHub "/issues?state=open&labels=$label&sort=created&direction=asc&per_page=100&page=$page" | ForEach-Object { $_ })
                foreach ($issue in $issues) {
                    if ($issue.PSObject.Properties['pull_request'] -or $issue.user.id -ne $ownerId) { continue }
                    $key = "issue-$($issue.number)"
                    $receiptPath = Join-Path $stateDir "$key.json"
                    try {
                        if (Test-Path -LiteralPath $receiptPath) {
                            $receipt = ConvertFrom-Json -AsHashtable -InputObject ([IO.File]::ReadAllText($receiptPath))
                            if ($receipt.phase -eq 'reported') { continue }
                        } else {
                            $current = Invoke-GitHub "/issues/$($issue.number)"
                            if ($current.state -ne 'open' -or $current.user.id -ne $ownerId -or
                                @($current.labels | ForEach-Object name) -cnotcontains $label) { continue }
                            $job = Read-Job $current.body
                            $reference = Read-Reference $job.reference
                            $receipt = Start-Render $job $reference $key $receiptPath
                        }
                        if ($receipt.phase -eq 'submitted') { Wait-Render $receipt $key $receiptPath }
                        Publish-Result $issue.number $receipt $key
                        $receipt.phase = 'reported'
                        Write-Receipt $receiptPath $receipt
                    } catch {
                        Write-Warning "Issue $($issue.number) could not be processed. $($_.Exception.Message)"
                        if ($Once) { throw }
                    }
                }
                if ($issues.Count -lt 100) { break }
            }
        } catch {
            if ($Once) { throw }
            Write-Warning "Queue polling failed. $($_.Exception.Message)"
        }
        if (!$Once) { Start-Sleep -Seconds 60 }
    } until ($Once)
} finally { $lock.Dispose() }

