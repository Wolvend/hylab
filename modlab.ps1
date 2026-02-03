param(
  [Parameter(Position=0)]
  [ValidateSet('help','scan','plan','boot','join','report','proofcheck','bisect','repro','scenario','deps','tune-memory')]
  [string]$Command = 'help',
  [Alias('config')]
  [string]$ConfigPath = "${PSScriptRoot}\config\hylab.json",
  [int]$Parallel,
  [string]$Xmx,
  [string]$Xms,
  [Alias('group-size')]
  [int]$GroupSize,
  [int]$Seed,
  [int]$Limit,
  [int]$StartIndex,
  [int]$Count,
  [Alias('run-id')]
  [string]$RunId,
  [Alias('test-id')]
  [int]$TestId,
  [Alias('bisect-status')]
  [string]$BisectStatus,
  [Alias('scenario')]
  [string]$ScenarioPath,
  [Alias('include-mods')]
  [switch]$IncludeMods,
  [string]$Out,
  [switch]$Json,
  [switch]$Csv,
  [switch]$Junit,
  [switch]$Strict,
  [string]$Lane
)

$ErrorActionPreference = 'Stop'
$script:AffinityCursor = 0
$script:ResourceStats = $null
$script:ResourceLogLast = [datetime]::MinValue
$script:ResourceLogIntervalSec = 0
$script:ResourceLogPath = $null
$script:TraceLogPath = $null
$script:TraceLogLevel = 'info'
$script:TraceRunId = ''
$script:CpuSamples = $null
$script:MemSamples = $null
$script:SampleWindow = 0
$script:SpikeUntil = [datetime]::MinValue
$script:BootTimeSamples = $null

function Apply-EnvOverrides {
  param($cfg)
  function Convert-ToBool {
    param([string]$Value, [bool]$Default)
    if ($null -eq $Value) { return $Default }
    $v = $Value.ToString().Trim().ToLower()
    if ($v -in @('1','true','yes','y','on')) { return $true }
    if ($v -in @('0','false','no','n','off')) { return $false }
    return $Default
  }
  $map = @{
    ServerRoot = $env:HYLAB_SERVER_ROOT
    AssetsZip = $env:HYLAB_ASSETS_ZIP
    ModsSource = $env:HYLAB_MODS_SOURCE
    WorkDir = $env:HYLAB_WORK_DIR
    TemplateDir = $env:HYLAB_TEMPLATE_DIR
    RunsDir = $env:HYLAB_RUNS_DIR
    ReportsDir = $env:HYLAB_REPORTS_DIR
    ReprosDir = $env:HYLAB_REPROS_DIR
    LogsDir = $env:HYLAB_LOGS_DIR
    CacheDir = $env:HYLAB_CACHE_DIR
    UseAOTCache = $env:HYLAB_USE_AOT
    PortStart = $env:HYLAB_PORT_START
    PortEnd = $env:HYLAB_PORT_END
    MaxParallel = $env:HYLAB_MAX_PARALLEL
    Xmx = $env:HYLAB_XMX
    Xms = $env:HYLAB_XMS
    BootTimeoutSeconds = $env:HYLAB_BOOT_TIMEOUT_SECONDS
    JoinCommand = $env:HYLAB_JOIN_COMMAND
    JoinTimeoutSeconds = $env:HYLAB_JOIN_TIMEOUT_SECONDS
    JoinAuthMode = $env:HYLAB_JOIN_AUTH_MODE
    ThinCloneEnabled = $env:HYLAB_THIN_CLONE
    ThinCloneWritableDirs = $env:HYLAB_THIN_CLONE_WRITABLE_DIRS
    ThinCloneWritableFiles = $env:HYLAB_THIN_CLONE_WRITABLE_FILES
    RunRetentionCount = $env:HYLAB_RUN_RETENTION_COUNT
    RunRetentionDays = $env:HYLAB_RUN_RETENTION_DAYS
    StageAheadCount = $env:HYLAB_STAGE_AHEAD_COUNT
    LogMaxBytes = $env:HYLAB_LOG_MAX_BYTES
    BootTimeAdaptiveEnabled = $env:HYLAB_BOOT_TIME_ADAPTIVE
    BootTimeSampleWindow = $env:HYLAB_BOOT_TIME_WINDOW
    BootTimeHighSec = $env:HYLAB_BOOT_TIME_HIGH
    BootTimeLowSec = $env:HYLAB_BOOT_TIME_LOW
    PrunePassArtifacts = $env:HYLAB_PRUNE_PASS
    PruneSkipArtifacts = $env:HYLAB_PRUNE_SKIP
    DepOverridesPath = $env:HYLAB_DEP_OVERRIDES
    ExcludesPath = $env:HYLAB_EXCLUDES
    ResourceSampleIntervalSec = $env:HYLAB_RESOURCE_SAMPLE_INTERVAL_SEC
    TraceLogLevel = $env:HYLAB_TRACE_LEVEL
    DebugTailLines = $env:HYLAB_DEBUG_TAIL_LINES
    ErrorIgnorePatterns = $env:HYLAB_ERROR_IGNORE
    ThrottleCpuPct = $env:HYLAB_THROTTLE_CPU_PCT
    ThrottleMemPct = $env:HYLAB_THROTTLE_MEM_PCT
    ThrottleCheckIntervalMs = $env:HYLAB_THROTTLE_INTERVAL_MS
    ResourceLogIntervalSec = $env:HYLAB_RESOURCE_LOG_INTERVAL_SEC
    ProcessPriority = $env:HYLAB_PROCESS_PRIORITY
    CpuAffinityMode = $env:HYLAB_CPU_AFFINITY
    AdaptiveThrottleEnabled = $env:HYLAB_ADAPTIVE_ENABLED
    AdaptiveMinParallel = $env:HYLAB_ADAPTIVE_MIN_PARALLEL
    AdaptiveMaxParallel = $env:HYLAB_ADAPTIVE_MAX_PARALLEL
    AdaptiveSampleWindow = $env:HYLAB_ADAPTIVE_SAMPLE_WINDOW
    AdaptiveSpikePct = $env:HYLAB_ADAPTIVE_SPIKE_PCT
    AdaptiveSpikeHoldSec = $env:HYLAB_ADAPTIVE_SPIKE_HOLD_SEC
    AdaptiveCpuHighPct = $env:HYLAB_ADAPTIVE_CPU_HIGH
    AdaptiveCpuLowPct = $env:HYLAB_ADAPTIVE_CPU_LOW
    AdaptiveMemHighPct = $env:HYLAB_ADAPTIVE_MEM_HIGH
    AdaptiveMemLowPct = $env:HYLAB_ADAPTIVE_MEM_LOW
    AdaptiveStepUp = $env:HYLAB_ADAPTIVE_STEP_UP
    AdaptiveStepDown = $env:HYLAB_ADAPTIVE_STEP_DOWN
    AdaptiveCooldownSec = $env:HYLAB_ADAPTIVE_COOLDOWN_SEC
    PairwiseGroupSize = $env:HYLAB_GROUP_SIZE
    PairwiseTriesPerGroup = $env:HYLAB_TRIES_PER_GROUP
    PairwiseSeed = $env:HYLAB_SEED
  }

  foreach ($k in $map.Keys) {
    $v = $map[$k]
    if ($null -ne $v -and ($v.ToString().Trim().Length -gt 0)) {
      if ($k -in @('PortStart','PortEnd','MaxParallel','BootTimeoutSeconds','JoinTimeoutSeconds','PairwiseGroupSize','PairwiseTriesPerGroup','PairwiseSeed','ThrottleCpuPct','ThrottleMemPct','ThrottleCheckIntervalMs','ResourceLogIntervalSec','ResourceSampleIntervalSec','AdaptiveMinParallel','AdaptiveMaxParallel','AdaptiveSampleWindow','AdaptiveSpikePct','AdaptiveSpikeHoldSec','AdaptiveCpuHighPct','AdaptiveCpuLowPct','AdaptiveMemHighPct','AdaptiveMemLowPct','AdaptiveStepUp','AdaptiveStepDown','AdaptiveCooldownSec','RunRetentionCount','RunRetentionDays','StageAheadCount','LogMaxBytes','BootTimeSampleWindow','BootTimeHighSec','BootTimeLowSec')) {
        $cfg.$k = [int]$v
      } elseif ($k -eq 'ErrorIgnorePatterns') {
        $parts = $v.ToString().Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $cfg.$k = $parts
      } elseif ($k -in @('ThinCloneWritableDirs','ThinCloneWritableFiles')) {
        $parts = $v.ToString().Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $cfg.$k = $parts
      } elseif ($k -eq 'AdaptiveThrottleEnabled') {
        $cfg.$k = Convert-ToBool -Value $v -Default $cfg.AdaptiveThrottleEnabled
      } elseif ($k -eq 'UseAOTCache') {
        $cfg.$k = Convert-ToBool -Value $v -Default $cfg.UseAOTCache
      } elseif ($k -eq 'ThinCloneEnabled') {
        $cfg.$k = Convert-ToBool -Value $v -Default $cfg.ThinCloneEnabled
      } elseif ($k -eq 'BootTimeAdaptiveEnabled') {
        $cfg.$k = Convert-ToBool -Value $v -Default $cfg.BootTimeAdaptiveEnabled
      } elseif ($k -in @('PrunePassArtifacts','PruneSkipArtifacts')) {
        $cfg.$k = Convert-ToBool -Value $v -Default $cfg.$k
      } else {
        $cfg.$k = $v
      }
    }
  }
}

function Load-Config {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Config not found: $Path"
  }
  $cfg = Get-Content -Raw -Path $Path | ConvertFrom-Json
  if (-not $cfg.SchemaVersion) { $cfg.SchemaVersion = '1.0.0' }
  if ($cfg.SchemaVersion -ne '1.0.0') { throw "Unsupported SchemaVersion: $($cfg.SchemaVersion)" }
  if (-not $cfg.CacheDir -and $cfg.WorkDir) { $cfg.CacheDir = (Join-Path $cfg.WorkDir 'cache') }
  $cfgDir = Split-Path -Parent $Path
  if (-not $cfg.DepOverridesPath) { $cfg.DepOverridesPath = (Join-Path $cfgDir 'dep-overrides.json') }
  if (-not $cfg.ExcludesPath) { $cfg.ExcludesPath = (Join-Path $cfgDir 'excludes.txt') }
  if ($null -eq $cfg.UseAOTCache) { $cfg.UseAOTCache = $true }
  if ($null -eq $cfg.ResourceSampleIntervalSec) { $cfg.ResourceSampleIntervalSec = 2 }
  if ($null -eq $cfg.ErrorIgnorePatterns) { $cfg.ErrorIgnorePatterns = @('UNUSED LOG ARGUMENTS','Error in scheduler task') }
  if (-not $cfg.TraceLogLevel) { $cfg.TraceLogLevel = 'info' }
  if ($null -eq $cfg.DebugTailLines) { $cfg.DebugTailLines = 50 }
  if ($null -eq $cfg.ThrottleCpuPct) { $cfg.ThrottleCpuPct = 85 }
  if ($null -eq $cfg.ThrottleMemPct) { $cfg.ThrottleMemPct = 80 }
  if ($null -eq $cfg.ThrottleCheckIntervalMs) { $cfg.ThrottleCheckIntervalMs = 1000 }
  if ($null -eq $cfg.ResourceLogIntervalSec) { $cfg.ResourceLogIntervalSec = 5 }
  if (-not $cfg.ProcessPriority) { $cfg.ProcessPriority = 'BelowNormal' }
  if (-not $cfg.CpuAffinityMode) { $cfg.CpuAffinityMode = 'all' }
  if ($null -eq $cfg.AdaptiveThrottleEnabled) { $cfg.AdaptiveThrottleEnabled = $true }
  if ($null -eq $cfg.AdaptiveMinParallel) { $cfg.AdaptiveMinParallel = 1 }
  if ($null -eq $cfg.AdaptiveMaxParallel) { $cfg.AdaptiveMaxParallel = $cfg.MaxParallel }
  if ($null -eq $cfg.AdaptiveSampleWindow) { $cfg.AdaptiveSampleWindow = 5 }
  if ($null -eq $cfg.AdaptiveSpikePct) { $cfg.AdaptiveSpikePct = 92 }
  if ($null -eq $cfg.AdaptiveSpikeHoldSec) { $cfg.AdaptiveSpikeHoldSec = 8 }
  if ($null -eq $cfg.AdaptiveCpuHighPct) { $cfg.AdaptiveCpuHighPct = 80 }
  if ($null -eq $cfg.AdaptiveCpuLowPct) { $cfg.AdaptiveCpuLowPct = 60 }
  if ($null -eq $cfg.AdaptiveMemHighPct) { $cfg.AdaptiveMemHighPct = 75 }
  if ($null -eq $cfg.AdaptiveMemLowPct) { $cfg.AdaptiveMemLowPct = 60 }
  if ($null -eq $cfg.AdaptiveStepUp) { $cfg.AdaptiveStepUp = 1 }
  if ($null -eq $cfg.AdaptiveStepDown) { $cfg.AdaptiveStepDown = 1 }
  if ($null -eq $cfg.AdaptiveCooldownSec) { $cfg.AdaptiveCooldownSec = 10 }
  if ($null -eq $cfg.JoinTimeoutSeconds) { $cfg.JoinTimeoutSeconds = 60 }
  if (-not $cfg.JoinAuthMode) { $cfg.JoinAuthMode = 'authenticated' }
  if ($null -eq $cfg.ThinCloneEnabled) { $cfg.ThinCloneEnabled = $false }
  if (-not $cfg.ThinCloneWritableDirs) { $cfg.ThinCloneWritableDirs = @('mods','logs','universe','.cache') }
  if (-not $cfg.ThinCloneWritableFiles) { $cfg.ThinCloneWritableFiles = @('config.json','permissions.json','whitelist.json','bans.json') }
  if ($null -eq $cfg.RunRetentionCount) { $cfg.RunRetentionCount = 0 }
  if ($null -eq $cfg.RunRetentionDays) { $cfg.RunRetentionDays = 0 }
  if ($null -eq $cfg.StageAheadCount) { $cfg.StageAheadCount = $cfg.MaxParallel }
  if ($null -eq $cfg.LogMaxBytes) { $cfg.LogMaxBytes = 10485760 }
  if ($null -eq $cfg.BootTimeAdaptiveEnabled) { $cfg.BootTimeAdaptiveEnabled = $true }
  if ($null -eq $cfg.BootTimeSampleWindow) { $cfg.BootTimeSampleWindow = 6 }
  if ($null -eq $cfg.BootTimeHighSec) { $cfg.BootTimeHighSec = [int][math]::Max(30, [math]::Round($cfg.BootTimeoutSeconds * 0.6)) }
  if ($null -eq $cfg.BootTimeLowSec) { $cfg.BootTimeLowSec = [int][math]::Max(10, [math]::Round($cfg.BootTimeoutSeconds * 0.3)) }
  if ($null -eq $cfg.PrunePassArtifacts) { $cfg.PrunePassArtifacts = $false }
  if ($null -eq $cfg.PruneSkipArtifacts) { $cfg.PruneSkipArtifacts = $false }
  Apply-EnvOverrides -cfg $cfg
  if ($Parallel) { $cfg.MaxParallel = $Parallel }
  if ($Xmx) { $cfg.Xmx = $Xmx }
  if ($Xms) { $cfg.Xms = $Xms }
  if ($GroupSize) { $cfg.PairwiseGroupSize = $GroupSize }
  if ($Seed) { $cfg.PairwiseSeed = $Seed }
  Validate-Config -cfg $cfg
  return $cfg
}

function Validate-Config {
  param($cfg)
  $required = @(
    'SchemaVersion','ServerRoot','AssetsZip','ModsSource','WorkDir','TemplateDir','RunsDir','ReportsDir',
    'ReprosDir','LogsDir','CacheDir','PortStart','PortEnd','MaxParallel','Xmx','Xms',
    'BootTimeoutSeconds','ReadyPatterns','ErrorPatterns','PairwiseGroupSize',
    'PairwiseTriesPerGroup','PairwiseSeed'
  )
  $allowed = @(
    'SchemaVersion','ServerRoot','AssetsZip','ModsSource','WorkDir','TemplateDir','RunsDir','ReportsDir',
    'ReprosDir','LogsDir','CacheDir','UseAOTCache','PortStart','PortEnd','MaxParallel','Xmx','Xms',
    'DepOverridesPath','ExcludesPath','ErrorIgnorePatterns','ResourceSampleIntervalSec','TraceLogLevel','DebugTailLines','ThrottleCpuPct','ThrottleMemPct','ThrottleCheckIntervalMs','ResourceLogIntervalSec','ProcessPriority','CpuAffinityMode',
    'AdaptiveThrottleEnabled','AdaptiveMinParallel','AdaptiveMaxParallel','AdaptiveSampleWindow','AdaptiveSpikePct','AdaptiveSpikeHoldSec','AdaptiveCpuHighPct','AdaptiveCpuLowPct','AdaptiveMemHighPct','AdaptiveMemLowPct','AdaptiveStepUp','AdaptiveStepDown','AdaptiveCooldownSec',
    'BootTimeoutSeconds','JoinCommand','JoinTimeoutSeconds','JoinAuthMode','ThinCloneEnabled','ThinCloneWritableDirs','ThinCloneWritableFiles','RunRetentionCount','RunRetentionDays','StageAheadCount','LogMaxBytes','BootTimeAdaptiveEnabled','BootTimeSampleWindow','BootTimeHighSec','BootTimeLowSec','PrunePassArtifacts','PruneSkipArtifacts','ReadyPatterns','ErrorPatterns','PairwiseGroupSize',
    'PairwiseTriesPerGroup','PairwiseSeed'
  )
  $unknown = $cfg.PSObject.Properties.Name | Where-Object { $allowed -notcontains $_ }
  if ($unknown.Count -gt 0) {
    throw "Unknown config keys: $($unknown -join ', ')"
  }
  foreach ($k in $required) {
    if (-not ($cfg.PSObject.Properties.Name -contains $k)) {
      throw "Missing config key: $k"
    }
  }
  foreach ($k in @('ServerRoot','AssetsZip','ModsSource','WorkDir','TemplateDir','RunsDir','ReportsDir','ReprosDir','LogsDir','CacheDir')) {
    if (-not [System.IO.Path]::IsPathRooted($cfg.$k)) { throw "$k must be an absolute path." }
  }
  foreach ($k in @('DepOverridesPath','ExcludesPath')) {
    if ($cfg.PSObject.Properties.Name -contains $k) {
      $v = $cfg.$k
      if ($v -and -not [System.IO.Path]::IsPathRooted($v)) { throw "$k must be an absolute path when set." }
    }
  }
  if ($null -ne $cfg.UseAOTCache -and -not ($cfg.UseAOTCache -is [bool])) { throw "UseAOTCache must be boolean." }
  if ($cfg.PortEnd -lt $cfg.PortStart) { throw "PortEnd must be >= PortStart." }
  if ($cfg.MaxParallel -lt 1) { throw "MaxParallel must be >= 1." }
  if ($cfg.ResourceSampleIntervalSec -lt 0) { throw "ResourceSampleIntervalSec must be >= 0." }
  if ($cfg.DebugTailLines -lt 0) { throw "DebugTailLines must be >= 0." }
  if (-not (Resolve-TraceLevel -Value $cfg.TraceLogLevel)) { throw "TraceLogLevel invalid: $($cfg.TraceLogLevel)" }
  if ($cfg.AdaptiveSampleWindow -lt 1) { throw "AdaptiveSampleWindow must be >= 1." }
  if ($cfg.AdaptiveSpikePct -lt 0 -or $cfg.AdaptiveSpikePct -gt 100) { throw "AdaptiveSpikePct must be 0..100." }
  if ($cfg.AdaptiveSpikeHoldSec -lt 0) { throw "AdaptiveSpikeHoldSec must be >= 0." }
  if ($cfg.ThrottleCpuPct -lt 0 -or $cfg.ThrottleCpuPct -gt 100) { throw "ThrottleCpuPct must be 0..100." }
  if ($cfg.ThrottleMemPct -lt 0 -or $cfg.ThrottleMemPct -gt 100) { throw "ThrottleMemPct must be 0..100." }
  if ($cfg.ThrottleCheckIntervalMs -lt 0) { throw "ThrottleCheckIntervalMs must be >= 0." }
  if ($cfg.ResourceLogIntervalSec -lt 0) { throw "ResourceLogIntervalSec must be >= 0." }
  if ($cfg.AdaptiveMinParallel -lt 1) { throw "AdaptiveMinParallel must be >= 1." }
  if ($cfg.AdaptiveMaxParallel -lt $cfg.AdaptiveMinParallel) { throw "AdaptiveMaxParallel must be >= AdaptiveMinParallel." }
  if ($cfg.AdaptiveCpuHighPct -lt 0 -or $cfg.AdaptiveCpuHighPct -gt 100) { throw "AdaptiveCpuHighPct must be 0..100." }
  if ($cfg.AdaptiveCpuLowPct -lt 0 -or $cfg.AdaptiveCpuLowPct -gt 100) { throw "AdaptiveCpuLowPct must be 0..100." }
  if ($cfg.AdaptiveMemHighPct -lt 0 -or $cfg.AdaptiveMemHighPct -gt 100) { throw "AdaptiveMemHighPct must be 0..100." }
  if ($cfg.AdaptiveMemLowPct -lt 0 -or $cfg.AdaptiveMemLowPct -gt 100) { throw "AdaptiveMemLowPct must be 0..100." }
  if ($cfg.AdaptiveStepUp -lt 0) { throw "AdaptiveStepUp must be >= 0." }
  if ($cfg.AdaptiveStepDown -lt 0) { throw "AdaptiveStepDown must be >= 0." }
  if ($cfg.AdaptiveCooldownSec -lt 0) { throw "AdaptiveCooldownSec must be >= 0." }
  if ($cfg.PairwiseGroupSize -lt 2) { throw "PairwiseGroupSize must be >= 2." }
  if ($cfg.PairwiseTriesPerGroup -lt 1) { throw "PairwiseTriesPerGroup must be >= 1." }
  if ($cfg.BootTimeoutSeconds -lt 0) { throw "BootTimeoutSeconds must be >= 0." }
  if ($cfg.JoinTimeoutSeconds -lt 0) { throw "JoinTimeoutSeconds must be >= 0." }
  if (-not ($cfg.Xmx -match '^\d+(K|M|G)$')) { throw "Xmx must match format like 2G, 512M." }
  if (-not ($cfg.Xms -match '^\d+(K|M|G)$')) { throw "Xms must match format like 256M." }
  if ($cfg.ProcessPriority -and -not (Resolve-ProcessPriority -Value $cfg.ProcessPriority)) { throw "ProcessPriority invalid: $($cfg.ProcessPriority)" }
  if ($cfg.CpuAffinityMode -and -not (Test-AffinityMode -Value $cfg.CpuAffinityMode)) { throw "CpuAffinityMode invalid: $($cfg.CpuAffinityMode)" }
  if ($cfg.JoinAuthMode -and ($cfg.JoinAuthMode -notin @('offline','authenticated'))) { throw "JoinAuthMode must be 'offline' or 'authenticated'." }
  if ($cfg.RunRetentionCount -lt 0) { throw "RunRetentionCount must be >= 0." }
  if ($cfg.RunRetentionDays -lt 0) { throw "RunRetentionDays must be >= 0." }
  if ($cfg.ThinCloneWritableDirs -and -not ($cfg.ThinCloneWritableDirs -is [System.Collections.IEnumerable])) { throw "ThinCloneWritableDirs must be an array." }
  if ($cfg.ThinCloneWritableFiles -and -not ($cfg.ThinCloneWritableFiles -is [System.Collections.IEnumerable])) { throw "ThinCloneWritableFiles must be an array." }
  if ($cfg.StageAheadCount -lt 1) { throw "StageAheadCount must be >= 1." }
  if ($cfg.LogMaxBytes -lt 0) { throw "LogMaxBytes must be >= 0." }
  if ($cfg.BootTimeSampleWindow -lt 1) { throw "BootTimeSampleWindow must be >= 1." }
  if ($cfg.BootTimeHighSec -lt 0) { throw "BootTimeHighSec must be >= 0." }
  if ($cfg.BootTimeLowSec -lt 0) { throw "BootTimeLowSec must be >= 0." }
  if ($null -ne $cfg.PrunePassArtifacts -and -not ($cfg.PrunePassArtifacts -is [bool])) { throw "PrunePassArtifacts must be boolean." }
  if ($null -ne $cfg.PruneSkipArtifacts -and -not ($cfg.PruneSkipArtifacts -is [bool])) { throw "PruneSkipArtifacts must be boolean." }
  if (-not ($cfg.ReadyPatterns -is [System.Collections.IEnumerable])) { throw "ReadyPatterns must be an array." }
  if (-not ($cfg.ErrorPatterns -is [System.Collections.IEnumerable])) { throw "ErrorPatterns must be an array." }
  if ($cfg.ErrorIgnorePatterns -and -not ($cfg.ErrorIgnorePatterns -is [System.Collections.IEnumerable])) { throw "ErrorIgnorePatterns must be an array." }
  if (($cfg.ReadyPatterns | Where-Object { -not ($_ -is [string]) }).Count -gt 0) { throw "ReadyPatterns must be strings." }
  if (($cfg.ErrorPatterns | Where-Object { -not ($_ -is [string]) }).Count -gt 0) { throw "ErrorPatterns must be strings." }
  if ($cfg.ErrorIgnorePatterns -and ($cfg.ErrorIgnorePatterns | Where-Object { -not ($_ -is [string]) }).Count -gt 0) { throw "ErrorIgnorePatterns must be strings." }
  if (-not (Test-Path $cfg.ServerRoot)) { throw "ServerRoot not found: $($cfg.ServerRoot)" }
  if (-not (Test-Path $cfg.AssetsZip)) { throw "AssetsZip not found: $($cfg.AssetsZip)" }
  if (-not (Test-Path $cfg.ModsSource)) { throw "ModsSource not found: $($cfg.ModsSource)" }
}

function Get-ModHash {
  param([string]$Path)
  try {
    return "sha256:$((Get-FileHash -Algorithm SHA256 -Path $Path).Hash)"
  } catch {
    return ''
  }
}

function Read-ZipEntryText {
  param($Entry)
  $stream = $Entry.Open()
  $reader = New-Object System.IO.StreamReader($stream)
  $text = $reader.ReadToEnd()
  $reader.Close()
  $stream.Close()
  return $text
}

function Get-ModManifest {
  param($mod)
  try { Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue } catch {}
  $zip = $null
  try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($mod.Path)
    $entry = $zip.Entries | Where-Object {
      $_.FullName -match '(?i)(^|/)(hytale-plugin\.json|plugin\.json|mod\.json|manifest\.json)$'
    } | Select-Object -First 1
    if (-not $entry) { return @{ Found = $false; Text = ''; Name = '' } }
    return @{ Found = $true; Text = (Read-ZipEntryText -Entry $entry); Name = $entry.FullName }
  } catch {
    return @{ Found = $false; Text = ''; Name = '' }
  } finally {
    if ($zip) { $zip.Dispose() }
  }
}

function Get-DependencyNames {
  param($manifest)
  $names = @()
  if (-not $manifest) { return $names }
  foreach ($key in @('dependencies','Dependencies','requiredDependencies','RequiredDependencies')) {
    if ($manifest.PSObject.Properties.Name -contains $key) {
      $dep = $manifest.$key
      if ($dep -is [System.Collections.IDictionary]) {
        foreach ($k in $dep.Keys) { if ($k) { $names += $k } }
      } elseif ($dep -is [pscustomobject]) {
        foreach ($p in $dep.PSObject.Properties) { if ($p.Name) { $names += $p.Name } }
      } elseif ($dep -is [System.Collections.IEnumerable]) {
        foreach ($d in $dep) {
          if ($d -is [string]) { $names += $d }
          elseif ($d -and $d.name) { $names += $d.name }
          elseif ($d -and $d.id) { $names += $d.id }
        }
      }
    }
  }
  return ($names | Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 } | Select-Object -Unique)
}

function Get-ManifestId {
  param($manifest)
  if (-not $manifest) { return '' }
  $group = $null
  $name = $null
  foreach ($k in @('Group','group','Namespace','namespace')) {
    if ($manifest.PSObject.Properties.Name -contains $k) { $group = $manifest.$k; break }
  }
  foreach ($k in @('Name','name')) {
    if ($manifest.PSObject.Properties.Name -contains $k) { $name = $manifest.$k; break }
  }
  foreach ($k in @('Id','id','ID')) {
    if ($manifest.PSObject.Properties.Name -contains $k) { return $manifest.$k }
  }
  if ($group -and $name) { return "$group`:$name" }
  if ($name) { return $name }
  return ''
}

function Get-EntryPoint {
  param($manifest)
  if (-not $manifest) { return '' }
  foreach ($k in @('main','entrypoint','Main','EntryPoint')) {
    if ($manifest.PSObject.Properties.Name -contains $k) { return $manifest.$k }
  }
  return ''
}

function Get-ModKey {
  param($mods)
  return ($mods | ForEach-Object {
    if ($_.Hash) { "$($_.Name):$($_.Hash)" } else { $_.Name }
  }) -join '|'
}

function Get-ModMeta {
  param($mod)
  $manifestInfo = Get-ModManifest -mod $mod
  $id = ''
  $declared = @()
  if ($manifestInfo.Found) {
    try {
      $manifest = $manifestInfo.Text | ConvertFrom-Json
      $id = Get-ManifestId -manifest $manifest
      $declared = Get-DependencyNames -manifest $manifest
    } catch {
      $id = ''
      $declared = @()
    }
  }
  if (-not $id) { $id = [System.IO.Path]::GetFileNameWithoutExtension($mod.Name) }
  return [pscustomobject]@{
    Id = $id
    DeclaredDependencies = ($declared | Select-Object -Unique)
    Dependencies = ($declared | Select-Object -Unique)
    OverrideDependencies = @()
  }
}

function Build-ModMaps {
  param($mods, $overrides)
  $metaByPath = @{}
  $modById = @{}
  foreach ($m in $mods) {
    $meta = Get-ModMeta -mod $m
    if ($overrides) {
      $overrideDeps = @()
      if ($meta.Id -and $overrides.ContainsKey($meta.Id)) { $overrideDeps = @($overrides[$meta.Id]) }
      elseif ($overrides.ContainsKey($m.Name)) { $overrideDeps = @($overrides[$m.Name]) }
      if ($overrideDeps.Count -gt 0) {
        $meta.OverrideDependencies = $overrideDeps
        $meta.Dependencies = @($meta.Dependencies + $overrideDeps | Select-Object -Unique)
      }
    }
    $metaByPath[$m.Path] = $meta
    if ($meta.Id -and -not $modById.ContainsKey($meta.Id)) { $modById[$meta.Id] = $m }
  }
  return @{ MetaByPath = $metaByPath; ModById = $modById }
}

function Expand-ModSet {
  param($mods, $metaByPath, $modById)
  $queue = New-Object System.Collections.Generic.Queue[object]
  foreach ($m in $mods) { $queue.Enqueue($m) }
  $seen = @{}
  $missing = New-Object System.Collections.Generic.HashSet[string]
  while ($queue.Count -gt 0) {
    $m = $queue.Dequeue()
    if ($seen.ContainsKey($m.Path)) { continue }
    $seen[$m.Path] = $m
    $meta = $metaByPath[$m.Path]
    if ($meta -and $meta.Dependencies) {
      foreach ($dep in ($meta.Dependencies | Sort-Object)) {
        if (Is-BuiltinDependency -Dep $dep) { continue }
        if ($modById.ContainsKey($dep)) { $queue.Enqueue($modById[$dep]) }
        else { $null = $missing.Add($dep) }
      }
    }
  }
  $expanded = $seen.Values | Sort-Object Name
  return [pscustomobject]@{ Mods = $expanded; Missing = @($missing) }
}

function Is-BuiltinDependency {
  param([string]$Dep)
  if (-not $Dep) { return $false }
  if ($Dep -match '^Hytale:') { return $true }
  return $false
}

function Ensure-Dirs {
  param($cfg)
  $dirs = @($cfg.WorkDir, $cfg.TemplateDir, $cfg.RunsDir, $cfg.ReportsDir, $cfg.ReprosDir, $cfg.LogsDir, $cfg.CacheDir)
  foreach ($d in $dirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  }
}

function Apply-RunRetention {
  param($cfg)
  if ($cfg.RunRetentionCount -le 0 -and $cfg.RunRetentionDays -le 0) { return }
  if (-not (Test-Path $cfg.RunsDir)) { return }
  $dirs = Get-ChildItem -Path $cfg.RunsDir -Directory | Sort-Object LastWriteTime -Descending
  if ($cfg.RunRetentionDays -gt 0) {
    $cutoff = (Get-Date).AddDays(-$cfg.RunRetentionDays)
    foreach ($d in $dirs | Where-Object { $_.LastWriteTime -lt $cutoff }) {
      try { Remove-Item -Recurse -Force -Path $d.FullName } catch {}
    }
    $dirs = Get-ChildItem -Path $cfg.RunsDir -Directory | Sort-Object LastWriteTime -Descending
  }
  if ($cfg.RunRetentionCount -gt 0) {
    $keep = $dirs | Select-Object -First $cfg.RunRetentionCount
    $keepSet = @{}
    foreach ($k in $keep) { $keepSet[$k.FullName] = $true }
    foreach ($d in $dirs) {
      if (-not $keepSet.ContainsKey($d.FullName)) {
        try { Remove-Item -Recurse -Force -Path $d.FullName } catch {}
      }
    }
  }
}

function Test-SameVolume {
  param([string]$PathA, [string]$PathB)
  $rootA = [System.IO.Path]::GetPathRoot($PathA).TrimEnd('\').ToUpper()
  $rootB = [System.IO.Path]::GetPathRoot($PathB).TrimEnd('\').ToUpper()
  return ($rootA -eq $rootB)
}

function New-HardlinkSafe {
  param([string]$Path, [string]$Target)
  try {
    New-Item -ItemType HardLink -Path $Path -Target $Target -Force | Out-Null
    return $true
  } catch {
    try {
      $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "mklink /H `"$Path`" `"$Target`"" -Wait -NoNewWindow -PassThru
      return ($p.ExitCode -eq 0)
    } catch { return $false }
  }
}

function New-JunctionSafe {
  param([string]$Path, [string]$Target)
  try {
    New-Item -ItemType Junction -Path $Path -Target $Target -Force | Out-Null
    return $true
  } catch {
    try {
      $p = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "mklink /J `"$Path`" `"$Target`"" -Wait -NoNewWindow -PassThru
      return ($p.ExitCode -eq 0)
    } catch { return $false }
  }
}

function Copy-Template {
  param($cfg, [string]$ServerDir)
  if (-not $cfg.ThinCloneEnabled) {
    Copy-Item -Path (Join-Path $cfg.TemplateDir '*') -Destination $ServerDir -Recurse -Force
    return
  }
  if (-not (Test-SameVolume -PathA $cfg.TemplateDir -PathB $ServerDir)) {
    Write-Host "ThinClone disabled: template and runs are on different volumes."
    Copy-Item -Path (Join-Path $cfg.TemplateDir '*') -Destination $ServerDir -Recurse -Force
    return
  }
  $writableDirs = $cfg.ThinCloneWritableDirs
  $writableFiles = $cfg.ThinCloneWritableFiles
  foreach ($item in (Get-ChildItem -Path $cfg.TemplateDir -Force)) {
    $dest = Join-Path $ServerDir $item.Name
    if ($item.PSIsContainer) {
      if ($writableDirs -contains $item.Name) {
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
      } else {
        if (-not (New-JunctionSafe -Path $dest -Target $item.FullName)) {
          Copy-Item -Path $item.FullName -Destination $dest -Recurse -Force
        }
      }
    } else {
      if ($writableFiles -contains $item.Name) {
        Copy-Item -Path $item.FullName -Destination $dest -Force
      } else {
        if (-not (New-HardlinkSafe -Path $dest -Target $item.FullName)) {
          Copy-Item -Path $item.FullName -Destination $dest -Force
        }
      }
    }
  }
  foreach ($dirName in $writableDirs) {
    $p = Join-Path $ServerDir $dirName
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  }
}

function Write-ModListFiles {
  param([string]$TestDir, $Mods)
  if (-not $TestDir -or -not $Mods) { return }
  $txt = Join-Path $TestDir 'mods.txt'
  $lines = @($Mods | ForEach-Object { $_.Name })
  $lines | Set-Content -Path $txt -Encoding Ascii

  $jsonPath = Join-Path $TestDir 'mods.json'
  $payload = @()
  foreach ($m in $Mods) {
    $hash = ''
    if ($m.PSObject.Properties.Name -contains 'Hash') { $hash = $m.Hash }
    $payload += [pscustomobject]@{ Name = $m.Name; Hash = $hash }
  }
  $payload | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding Ascii
}

function Update-RunIndex {
  param([string]$RunRoot, [int]$TestId, [string]$Status, [int]$DurationSec, [string]$Pattern, [int]$Port, [string]$TestDir, [string]$StartedAt, [string]$CompletedAt)
  if (-not $RunRoot) { return }
  $indexPath = Join-Path $RunRoot 'index.json'
  $payload = $null
  if (Test-Path $indexPath) {
    try { $payload = Get-Content -Raw -Path $indexPath | ConvertFrom-Json } catch { $payload = $null }
  }
  if (-not $payload) {
    $payload = [pscustomobject]@{
      SchemaVersion = '1.0.0'
      RunId = (Split-Path -Leaf $RunRoot)
      GeneratedAt = (Get-Date).ToString('s')
      Tests = @()
    }
  }
  $modTxt = Join-Path $TestDir 'mods.txt'
  $modJson = Join-Path $TestDir 'mods.json'
  $entry = [pscustomobject]@{
    TestId = $TestId
    Status = $Status
    DurationSec = $DurationSec
    Pattern = $Pattern
    Port = $Port
    TestDir = $TestDir
    ModsTxt = (Split-Path -Leaf $modTxt)
    ModsJson = (Split-Path -Leaf $modJson)
    StartedAt = $StartedAt
    CompletedAt = $CompletedAt
  }
  $tests = @()
  if ($payload.Tests) { $tests = @($payload.Tests | Where-Object { $_.TestId -ne $TestId }) }
  $tests += $entry
  $payload.Tests = $tests
  $payload.GeneratedAt = (Get-Date).ToString('s')
  $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $indexPath -Encoding Ascii
}

function Prune-TestArtifacts {
  param($cfg, [string]$TestDir, [string]$Status)
  if (-not $TestDir -or -not (Test-Path $TestDir)) { return $false }
  $doPrune = (($Status -eq 'pass') -and $cfg.PrunePassArtifacts) -or (($Status -eq 'skip') -and $cfg.PruneSkipArtifacts)
  if (-not $doPrune) { return $false }
  foreach ($name in @('server','logs','join')) {
    $p = Join-Path $TestDir $name
    if (Test-Path $p) {
      try { Remove-Item -Recurse -Force -Path $p } catch {}
    }
  }
  return $true
}

function Stage-TestInstance {
  param($cfg, $testId, $mods, [string]$runRoot, $metaByPath, $modById)
  if ($metaByPath -and $modById) {
    $expanded = Expand-ModSet -mods $mods -metaByPath $metaByPath -modById $modById
    if ($expanded.Missing.Count -gt 0) {
      return [pscustomobject]@{
        SkipResult = [pscustomobject]@{
          TestId = $testId
          Status = 'skip'
          DurationSec = 0
          Pattern = "missing dependency: $($expanded.Missing -join ', ')"
          LogDir = ''
          Port = $null
          StartedAt = (Get-Date).ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Stage = $null
      }
    }
    $missingFiles = @()
    foreach ($m in $expanded.Mods) {
      if (-not (Test-Path $m.Path)) { $missingFiles += $m.Name }
    }
    if ($missingFiles.Count -gt 0) {
      return [pscustomobject]@{
        SkipResult = [pscustomobject]@{
          TestId = $testId
          Status = 'skip'
          DurationSec = 0
          Pattern = "missing mod files: $($missingFiles -join ', ')"
          LogDir = ''
          Port = $null
          StartedAt = (Get-Date).ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Stage = $null
      }
    }
    $mods = $expanded.Mods
  }

  $testDir = Join-Path $runRoot ("test-{0:0000}" -f $testId)
  if (Test-Path $testDir) { Remove-Item -Recurse -Force -Path $testDir }
  $serverDir = Join-Path $testDir 'server'
  $logDir = Join-Path $testDir 'logs'
  New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  Copy-Template -cfg $cfg -ServerDir $serverDir

  $modsDir = Join-Path $serverDir 'mods'
  if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }
  foreach ($m in $mods) {
    if (Test-Path $m.Path) {
      Copy-Item -Path $m.Path -Destination $modsDir -Force
    }
  }
  Write-ModListFiles -TestDir $testDir -Mods $mods

  return [pscustomobject]@{
    SkipResult = $null
    Stage = [pscustomobject]@{
      TestId = $testId
      TestDir = $testDir
      ServerDir = $serverDir
      LogDir = $logDir
      Mods = $mods
    }
  }
}

function Start-StagedInstance {
  param($cfg, $stage, [int]$port, [string]$AuthMode = 'offline')
  $stdout = Join-Path $stage.LogDir 'stdout.log'
  $stderr = Join-Path $stage.LogDir 'stderr.log'

  $args = @()
  if ($cfg.Xms) { $args += "-Xms$($cfg.Xms)" }
  if ($cfg.Xmx) { $args += "-Xmx$($cfg.Xmx)" }
  if ($cfg.UseAOTCache) {
    $aotPath = Join-Path $stage.ServerDir 'HytaleServer.aot'
    if (Test-Path $aotPath) { $args += "-XX:AOTCache=HytaleServer.aot" }
  }
  $auth = Normalize-AuthMode -Value $AuthMode -Default 'offline'
  $args += @('-jar','HytaleServer.jar','--assets',$cfg.AssetsZip,'--auth-mode',$auth,'--bind',"0.0.0.0:$port",'--disable-sentry')

  $proc = Start-Process -FilePath 'java' -ArgumentList $args -WorkingDirectory $stage.ServerDir -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -NoNewWindow
  Apply-ProcessTuning -cfg $cfg -proc $proc

  return [pscustomobject]@{
    TestId = $stage.TestId
    TestDir = $stage.TestDir
    Mods = $stage.Mods
    Port = $port
    StartTime = Get-Date
    Process = $proc
    Stdout = $stdout
    Stderr = $stderr
  }
}

function Load-DepOverrides {
  param($cfg)
  $path = $cfg.DepOverridesPath
  if (-not $path -or -not (Test-Path $path)) { return @{} }
  $raw = Get-Content -Raw -Path $path
  if (-not $raw.Trim()) { return @{} }
  $obj = $raw | ConvertFrom-Json
  $map = @{}
  foreach ($p in $obj.PSObject.Properties) {
    if (-not $p.Name) { continue }
    $vals = @()
    if ($p.Value -is [string]) { $vals = @($p.Value) }
    elseif ($p.Value -is [System.Collections.IEnumerable]) { $vals = @($p.Value) }
    $vals = $vals | Where-Object { $_ -and $_.ToString().Trim().Length -gt 0 }
    if ($vals.Count -gt 0) { $map[$p.Name] = $vals }
  }
  return $map
}

function Load-Excludes {
  param($cfg)
  $path = $cfg.ExcludesPath
  if (-not $path -or -not (Test-Path $path)) { return @() }
  $lines = Get-Content -Path $path
  $items = @()
  foreach ($l in $lines) {
    $line = $l.Trim()
    if (-not $line) { continue }
    if ($line.StartsWith('#') -or $line.StartsWith(';') -or $line.StartsWith('//')) { continue }
    $items += $line
  }
  return $items
}

function Get-ModFiles {
  param($cfg)
  Get-ChildItem -Path $cfg.ModsSource -File | Where-Object { $_.Extension -in '.jar','.zip' } |
    ForEach-Object {
      [pscustomobject]@{
        Name = $_.Name
        Path = $_.FullName
        Size = $_.Length
        Extension = $_.Extension
        Hash = Get-ModHash -Path $_.FullName
      }
    }
}

function Filter-Mods {
  param($mods, $excludes)
  if (-not $excludes -or $excludes.Count -eq 0) { return $mods }
  $excludeSet = @{}
  foreach ($e in $excludes) {
    $k = $e.ToString().Trim().ToLower()
    if ($k) { $excludeSet[$k] = $true }
  }
  $filtered = @()
  foreach ($m in $mods) {
    $meta = Get-ModMeta -mod $m
    $nameKey = $m.Name.ToLower()
    $idKey = if ($meta.Id) { $meta.Id.ToString().ToLower() } else { '' }
    if ($excludeSet.ContainsKey($nameKey) -or ($idKey -and $excludeSet.ContainsKey($idKey))) { continue }
    $filtered += $m
  }
  return $filtered
}

function Write-ModList {
  param($mods, $cfg)
  $jsonPath = Join-Path $cfg.ReportsDir 'mods.json'
  $csvPath = Join-Path $cfg.ReportsDir 'mods.csv'
  $payload = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    GeneratedAt = (Get-Date).ToString('s')
    Mods = $mods
  }
  $payload | ConvertTo-Json -Depth 4 | Set-Content -Path $jsonPath -Encoding Ascii
  $mods | Export-Csv -Path $csvPath -NoTypeInformation
  Write-Host "Wrote $jsonPath and $csvPath"
}

function Get-RandomSample {
  param([System.Random]$Rand, [int]$N, [int]$K)
  if ($K -ge $N) { return 0..($N-1) }
  $arr = 0..($N-1)
  for ($i = 0; $i -lt $K; $i++) {
    $j = $Rand.Next($i, $N)
    $tmp = $arr[$i]
    $arr[$i] = $arr[$j]
    $arr[$j] = $tmp
  }
  return $arr[0..($K-1)]
}

function New-PairwisePlan {
  param($mods, $cfg)
  $n = $mods.Count
  if ($n -lt 2) { throw "Need at least 2 mods for pairwise plan." }
  $groupSize = [Math]::Min($cfg.PairwiseGroupSize, $n)
  $tries = $cfg.PairwiseTriesPerGroup
  $rand = [System.Random]::new($cfg.PairwiseSeed)
  $uncovered = New-Object 'System.Collections.Generic.HashSet[string]'
  for ($i = 0; $i -lt $n; $i++) {
    for ($j = $i + 1; $j -lt $n; $j++) {
      $null = $uncovered.Add("$i|$j")
    }
  }

  $tests = @()
  $maxPairsPerGroup = ($groupSize * ($groupSize - 1)) / 2
  while ($uncovered.Count -gt 0) {
    $bestGroup = $null
    $bestCover = -1
    for ($t = 0; $t -lt $tries; $t++) {
      $indices = Get-RandomSample -Rand $rand -N $n -K $groupSize
      $cover = 0
      for ($a = 0; $a -lt $indices.Count; $a++) {
        for ($b = $a + 1; $b -lt $indices.Count; $b++) {
          $key = "$($indices[$a])|$($indices[$b])"
          if ($uncovered.Contains($key)) { $cover++ }
        }
      }
      if ($cover -gt $bestCover) {
        $bestCover = $cover
        $bestGroup = $indices
        if ($bestCover -eq $maxPairsPerGroup) { break }
      }
    }
    if (-not $bestGroup) { break }
    for ($a = 0; $a -lt $bestGroup.Count; $a++) {
      for ($b = $a + 1; $b -lt $bestGroup.Count; $b++) {
        $key = "$($bestGroup[$a])|$($bestGroup[$b])"
        $null = $uncovered.Remove($key)
      }
    }
    $tests += ,$bestGroup
    if (($tests.Count % 50) -eq 0) {
      Write-Host "Generated $($tests.Count) groups, remaining pairs: $($uncovered.Count)"
    }
  }

  $totalPairs = [int](($n * ($n - 1)) / 2)
  $coveredPairs = $totalPairs - $uncovered.Count
  $coveragePct = if ($totalPairs -gt 0) { [math]::Round(($coveredPairs / $totalPairs) * 100, 2) } else { 100 }

  return [pscustomobject]@{
    SchemaVersion = '1.0.0'
    GeneratedAt = (Get-Date).ToString('s')
    Type = 'pairwise'
    GroupSize = $groupSize
    Seed = $cfg.PairwiseSeed
    TriesPerGroup = $tries
    Mods = $mods
    Coverage = [pscustomobject]@{
      TotalPairs = $totalPairs
      CoveredPairs = $coveredPairs
      CoveragePct = $coveragePct
    }
    Tests = $tests
  }
}

function Write-Plan {
  param($plan, $cfg)
  $planPath = Join-Path $cfg.ReportsDir 'plan.json'
  $plan | ConvertTo-Json -Depth 6 | Set-Content -Path $planPath -Encoding Ascii
  Write-Host "Wrote $planPath"
}

function Ensure-Template {
  param($cfg)
  $jar = Join-Path $cfg.TemplateDir 'HytaleServer.jar'
  if (-not (Test-Path $jar)) {
    New-Item -ItemType Directory -Path $cfg.TemplateDir -Force | Out-Null
    Copy-Item -Path (Join-Path $cfg.ServerRoot '*') -Destination $cfg.TemplateDir -Recurse -Force
  }
  foreach ($d in @('mods','universe','logs')) {
    $p = Join-Path $cfg.TemplateDir $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  }
}

function Resolve-ProcessPriority {
  param([string]$Value)
  if (-not $Value) { return $null }
  $v = $Value.ToString().Trim().ToLower().Replace('-','')
  switch ($v) {
    'idle' { return [System.Diagnostics.ProcessPriorityClass]::Idle }
    'belownormal' { return [System.Diagnostics.ProcessPriorityClass]::BelowNormal }
    'normal' { return [System.Diagnostics.ProcessPriorityClass]::Normal }
    'abovenormal' { return [System.Diagnostics.ProcessPriorityClass]::AboveNormal }
    'high' { return [System.Diagnostics.ProcessPriorityClass]::High }
    default { return $null }
  }
}

function Resolve-TraceLevel {
  param([string]$Value)
  if (-not $Value) { return $null }
  $v = $Value.ToString().Trim().ToLower()
  switch ($v) {
    'error' { return 0 }
    'warn' { return 1 }
    'info' { return 2 }
    'debug' { return 3 }
    default { return $null }
  }
}

function Write-Trace {
  param([string]$Level, [string]$Event, [int]$TestId, $Data)
  if (-not $script:TraceLogPath) { return }
  $min = Resolve-TraceLevel -Value $script:TraceLogLevel
  $cur = Resolve-TraceLevel -Value $Level
  if ($null -eq $min -or $null -eq $cur) { return }
  if ($cur -gt $min) { return }
  $payload = [pscustomobject]@{
    Ts = (Get-Date).ToString('s')
    RunId = $script:TraceRunId
    TestId = $TestId
    Level = $Level
    Event = $Event
    Data = $Data
  }
  $json = $payload | ConvertTo-Json -Depth 6 -Compress
  Add-Content -Path $script:TraceLogPath -Value $json -Encoding Ascii
}

function Trim-LogFile {
  param([string]$Path, [int]$MaxBytes)
  if ($MaxBytes -le 0) { return }
  if (-not (Test-Path $Path)) { return }
  $info = Get-Item -LiteralPath $Path
  if ($info.Length -le $MaxBytes) { return }
  $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
  try {
    $fs.Seek(-$MaxBytes, [System.IO.SeekOrigin]::End) | Out-Null
    $buffer = New-Object byte[] $MaxBytes
    $read = $fs.Read($buffer, 0, $MaxBytes)
    $fs.SetLength(0)
    $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
    $fs.Write($buffer, 0, $read)
  } finally {
    $fs.Close()
  }
}

function Trim-InstanceLogs {
  param($cfg, $inst)
  Trim-LogFile -Path $inst.Stdout -MaxBytes $cfg.LogMaxBytes
  Trim-LogFile -Path $inst.Stderr -MaxBytes $cfg.LogMaxBytes
}

function Get-LogTail {
  param([string]$Path, [int]$Lines)
  if ($Lines -le 0) { return '' }
  if (-not (Test-Path $Path)) { return '' }
  try {
    return (Get-Content -Path $Path -Tail $Lines) -join "`n"
  } catch {
    return ''
  }
}

function Remove-IgnoredLines {
  param([string]$Text, $IgnorePatterns)
  if (-not $IgnorePatterns -or $IgnorePatterns.Count -eq 0) { return $Text }
  $out = $Text
  foreach ($p in $IgnorePatterns) {
    if (-not $p) { continue }
    try {
      $out = [regex]::Replace($out, "(?m)^.*$p.*$(\r?\n)?", "")
    } catch {}
  }
  return $out
}

function Test-AffinityMode {
  param([string]$Value)
  if (-not $Value) { return $true }
  $v = $Value.ToString().Trim().ToLower()
  if ($v -in @('all','round-robin')) { return $true }
  if ($v -match '^mask:') {
    $hex = $v.Substring(5)
    if ($hex -match '^0x') { $hex = $hex.Substring(2) }
    return $hex -match '^[0-9a-f]+$'
  }
  return $false
}

function Get-AffinityMask {
  param($cfg)
  if (-not $cfg.CpuAffinityMode) { return $null }
  $mode = $cfg.CpuAffinityMode.ToString().Trim().ToLower()
  if ($mode -eq '' -or $mode -eq 'all') { return $null }
  if ($mode -eq 'round-robin') {
    $coreCount = [Environment]::ProcessorCount
    if ($coreCount -lt 1) { return $null }
    $idx = $script:AffinityCursor % $coreCount
    $script:AffinityCursor++
    return [int64](1L -shl $idx)
  }
  if ($mode -match '^mask:') {
    $hex = $mode.Substring(5)
    if ($hex -match '^0x') { $hex = $hex.Substring(2) }
    try { return [int64]("0x$hex") } catch { return $null }
  }
  return $null
}

function Apply-ProcessTuning {
  param($cfg, $proc)
  if (-not $proc) { return }
  $priority = Resolve-ProcessPriority -Value $cfg.ProcessPriority
  if ($priority) {
    try { $proc.PriorityClass = $priority } catch {}
  }
  $mask = Get-AffinityMask -cfg $cfg
  if ($mask) {
    try { $proc.ProcessorAffinity = [intptr]$mask } catch {}
  }
}

function Get-SystemStats {
  $cpu = 0
  try { $cpu = (Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average } catch { $cpu = 0 }
  if (-not $cpu) { $cpu = 0 }
  $os = $null
  try { $os = Get-CimInstance Win32_OperatingSystem } catch { $os = $null }
  $memTotalGb = 0
  $memUsedGb = 0
  if ($os) {
    $memTotalGb = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $memUsedGb = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
  }
  $memPct = if ($memTotalGb -gt 0) { [math]::Round(($memUsedGb / $memTotalGb) * 100, 1) } else { 0 }
  $java = Get-Process -Name java -ErrorAction SilentlyContinue
  $javaMemGb = if ($java) { [math]::Round(($java | Measure-Object WorkingSet -Sum).Sum / 1GB, 2) } else { 0 }
  return [pscustomobject]@{
    CpuPct = [math]::Round($cpu, 2)
    MemUsedGb = $memUsedGb
    MemTotalGb = $memTotalGb
    MemPct = $memPct
    JavaMemGb = $javaMemGb
  }
}

function Write-ResourceSample {
  param([string]$Path, $Stats)
  if (-not $Path -or -not $Stats) { return }
  if (-not (Test-Path $Path)) {
    "ts,cpu_pct,mem_used_gb,mem_total_gb,mem_pct,java_mem_gb" | Set-Content -Path $Path -Encoding Ascii
  }
  $line = "{0},{1},{2},{3},{4},{5}" -f (Get-Date).ToString('s'), $Stats.CpuPct, $Stats.MemUsedGb, $Stats.MemTotalGb, $Stats.MemPct, $Stats.JavaMemGb
  Add-Content -Path $Path -Value $line -Encoding Ascii
}

function Add-BootTimeSample {
  param($cfg, [int]$Seconds)
  if (-not $cfg.BootTimeAdaptiveEnabled) { return }
  if ($cfg.BootTimeSampleWindow -lt 1) { return }
  if (-not $script:BootTimeSamples) { $script:BootTimeSamples = New-Object System.Collections.Generic.Queue[int] }
  $script:BootTimeSamples.Enqueue([int]$Seconds)
  while ($script:BootTimeSamples.Count -gt $cfg.BootTimeSampleWindow) { $null = $script:BootTimeSamples.Dequeue() }
}

function Get-BootTimeAverage {
  if (-not $script:BootTimeSamples -or $script:BootTimeSamples.Count -eq 0) { return $null }
  $avg = ($script:BootTimeSamples.ToArray() | Measure-Object -Average).Average
  return [math]::Round($avg, 2)
}

function Start-ResourceMonitor {
  param($cfg, [string]$Path)
  if ($cfg.ResourceSampleIntervalSec -le 0) { return $null }
  $script:ResourceStats = $null
  $script:ResourceLogLast = [datetime]::MinValue
  $script:ResourceLogIntervalSec = $cfg.ResourceLogIntervalSec
  $script:ResourceLogPath = $Path
  $script:SampleWindow = $cfg.AdaptiveSampleWindow
  $script:CpuSamples = New-Object System.Collections.Generic.Queue[double]
  $script:MemSamples = New-Object System.Collections.Generic.Queue[double]
  $script:SpikeUntil = [datetime]::MinValue
  $timer = New-Object System.Timers.Timer
  $timer.Interval = [int]($cfg.ResourceSampleIntervalSec * 1000)
  $timer.AutoReset = $true
  $timer.add_Elapsed({
    try {
      $stats = Get-SystemStats
      if ($script:SampleWindow -gt 0) {
        $script:CpuSamples.Enqueue([double]$stats.CpuPct)
        while ($script:CpuSamples.Count -gt $script:SampleWindow) { $null = $script:CpuSamples.Dequeue() }
        $script:MemSamples.Enqueue([double]$stats.MemPct)
        while ($script:MemSamples.Count -gt $script:SampleWindow) { $null = $script:MemSamples.Dequeue() }
        $avgCpu = ($script:CpuSamples | Measure-Object -Average).Average
        $maxCpu = ($script:CpuSamples | Measure-Object -Maximum).Maximum
        $avgMem = ($script:MemSamples | Measure-Object -Average).Average
        $maxMem = ($script:MemSamples | Measure-Object -Maximum).Maximum
        $stats | Add-Member -NotePropertyName AvgCpuPct -NotePropertyValue ([math]::Round($avgCpu,2)) -Force
        $stats | Add-Member -NotePropertyName MaxCpuPct -NotePropertyValue ([math]::Round($maxCpu,2)) -Force
        $stats | Add-Member -NotePropertyName AvgMemPct -NotePropertyValue ([math]::Round($avgMem,2)) -Force
        $stats | Add-Member -NotePropertyName MaxMemPct -NotePropertyValue ([math]::Round($maxMem,2)) -Force
      }
      $script:ResourceStats = $stats
      if ($script:ResourceLogPath -and $script:ResourceLogIntervalSec -gt 0) {
        $now = Get-Date
        if (($now - $script:ResourceLogLast).TotalSeconds -ge $script:ResourceLogIntervalSec) {
          Write-ResourceSample -Path $script:ResourceLogPath -Stats $stats
          $script:ResourceLogLast = $now
        }
      }
    } catch {}
  })
  $timer.Start()
  return $timer
}

function Stop-ResourceMonitor {
  param($timer)
  if ($timer) {
    try { $timer.Stop() } catch {}
    try { $timer.Dispose() } catch {}
  }
}

function Test-Throttle {
  param($cfg, $Stats)
  if (-not $Stats) { return $false }
  if ($cfg.ThrottleCpuPct -gt 0 -and $Stats.CpuPct -ge $cfg.ThrottleCpuPct) { return $true }
  if ($cfg.ThrottleMemPct -gt 0 -and $Stats.MemPct -ge $cfg.ThrottleMemPct) { return $true }
  return $false
}

function Adjust-Parallel {
  param($cfg, $Stats, [ref]$EffectiveMaxParallel, [ref]$LastAdjust)
  if (-not $cfg.AdaptiveThrottleEnabled) { return }
  if (-not $Stats) { return }
  $now = Get-Date
  if (($now - $LastAdjust.Value).TotalSeconds -lt $cfg.AdaptiveCooldownSec) { return }

  $cpu = if ($Stats.PSObject.Properties.Name -contains 'AvgCpuPct') { $Stats.AvgCpuPct } else { $Stats.CpuPct }
  $mem = if ($Stats.PSObject.Properties.Name -contains 'AvgMemPct') { $Stats.AvgMemPct } else { $Stats.MemPct }
  $maxCpu = if ($Stats.PSObject.Properties.Name -contains 'MaxCpuPct') { $Stats.MaxCpuPct } else { $Stats.CpuPct }

  if ($cfg.AdaptiveSpikePct -gt 0 -and $maxCpu -ge $cfg.AdaptiveSpikePct) {
    $script:SpikeUntil = $now.AddSeconds($cfg.AdaptiveSpikeHoldSec)
  }
  if ($now -lt $script:SpikeUntil) {
    $EffectiveMaxParallel.Value = [math]::Max($cfg.AdaptiveMinParallel, $EffectiveMaxParallel.Value - $cfg.AdaptiveStepDown)
    $LastAdjust.Value = $now
    return
  }

  $hardHit = $false
  if ($cfg.ThrottleCpuPct -gt 0 -and $Stats.CpuPct -ge $cfg.ThrottleCpuPct) { $hardHit = $true }
  if ($cfg.ThrottleMemPct -gt 0 -and $Stats.MemPct -ge $cfg.ThrottleMemPct) { $hardHit = $true }
  if ($hardHit) {
    $EffectiveMaxParallel.Value = [math]::Max($cfg.AdaptiveMinParallel, $EffectiveMaxParallel.Value - $cfg.AdaptiveStepDown)
    $LastAdjust.Value = $now
    return
  }

  $tooHigh = ($cpu -ge $cfg.AdaptiveCpuHighPct) -or ($mem -ge $cfg.AdaptiveMemHighPct)
  $tooLow = ($cpu -le $cfg.AdaptiveCpuLowPct) -and ($mem -le $cfg.AdaptiveMemLowPct)

  if ($tooHigh) {
    $EffectiveMaxParallel.Value = [math]::Max($cfg.AdaptiveMinParallel, $EffectiveMaxParallel.Value - $cfg.AdaptiveStepDown)
    $LastAdjust.Value = $now
  } elseif ($tooLow) {
    $EffectiveMaxParallel.Value = [math]::Min($cfg.AdaptiveMaxParallel, $EffectiveMaxParallel.Value + $cfg.AdaptiveStepUp)
    $LastAdjust.Value = $now
  } else {
    if ($cfg.BootTimeAdaptiveEnabled) {
      $avgBoot = Get-BootTimeAverage
      if ($null -ne $avgBoot) {
        if ($avgBoot -ge $cfg.BootTimeHighSec) {
          $EffectiveMaxParallel.Value = [math]::Max($cfg.AdaptiveMinParallel, $EffectiveMaxParallel.Value - $cfg.AdaptiveStepDown)
          $LastAdjust.Value = $now
        } elseif ($avgBoot -le $cfg.BootTimeLowSec) {
          $EffectiveMaxParallel.Value = [math]::Min($cfg.AdaptiveMaxParallel, $EffectiveMaxParallel.Value + $cfg.AdaptiveStepUp)
          $LastAdjust.Value = $now
        }
      }
    }
  }
}

function Start-Instance {
  param($cfg, $testId, $mods, $port, $runRoot, [string]$AuthMode = 'offline')
  $testDir = Join-Path $runRoot ("test-{0:0000}" -f $testId)
  $serverDir = Join-Path $testDir 'server'
  $logDir = Join-Path $testDir 'logs'
  New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  Copy-Template -cfg $cfg -ServerDir $serverDir

  $modsDir = Join-Path $serverDir 'mods'
  if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }
  foreach ($m in $mods) {
    if (Test-Path $m.Path) {
      Copy-Item -Path $m.Path -Destination $modsDir -Force
    }
  }
  Write-ModListFiles -TestDir $testDir -Mods $mods

  $stdout = Join-Path $logDir 'stdout.log'
  $stderr = Join-Path $logDir 'stderr.log'

  $args = @()
  if ($cfg.Xms) { $args += "-Xms$($cfg.Xms)" }
  if ($cfg.Xmx) { $args += "-Xmx$($cfg.Xmx)" }
  if ($cfg.UseAOTCache) {
    $aotPath = Join-Path $serverDir 'HytaleServer.aot'
    if (Test-Path $aotPath) { $args += "-XX:AOTCache=HytaleServer.aot" }
  }
  $auth = Normalize-AuthMode -Value $AuthMode -Default 'offline'
  $args += @('-jar','HytaleServer.jar','--assets',$cfg.AssetsZip,'--auth-mode',$auth,'--bind',"0.0.0.0:$port",'--disable-sentry')

  $proc = Start-Process -FilePath 'java' -ArgumentList $args -WorkingDirectory $serverDir -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -NoNewWindow
  Apply-ProcessTuning -cfg $cfg -proc $proc

  return [pscustomobject]@{
    TestId = $testId
    TestDir = $testDir
    Mods = $mods
    Port = $port
    StartTime = Get-Date
    Process = $proc
    Stdout = $stdout
    Stderr = $stderr
  }
}

function Join-Args {
  param([string[]]$Args)
  return ($Args | ForEach-Object {
    if ($_ -match '\s') { '"' + ($_ -replace '"','\"') + '"' } else { $_ }
  }) -join ' '
}

function Normalize-AuthMode {
  param([string]$Value, [string]$Default)
  if (-not $Value) { return $Default }
  $v = $Value.ToString().Trim().ToLower()
  if ($v -in @('offline','authenticated')) { return $v }
  return $Default
}

function Start-ScenarioInstance {
  param($cfg, $testId, $mods, $port, $runRoot, [string]$AuthMode = 'offline')
  $testDir = Join-Path $runRoot ("test-{0:0000}" -f $testId)
  $serverDir = Join-Path $testDir 'server'
  $logDir = Join-Path $testDir 'logs'
  New-Item -ItemType Directory -Path $serverDir -Force | Out-Null
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  Copy-Template -cfg $cfg -ServerDir $serverDir

  $modsDir = Join-Path $serverDir 'mods'
  if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Path $modsDir -Force | Out-Null }
  foreach ($m in $mods) {
    Copy-Item -Path $m.Path -Destination $modsDir -Force
  }
  Write-ModListFiles -TestDir $testDir -Mods $mods

  $stdout = Join-Path $logDir 'stdout.log'
  $stderr = Join-Path $logDir 'stderr.log'

  $args = @()
  if ($cfg.Xms) { $args += "-Xms$($cfg.Xms)" }
  if ($cfg.Xmx) { $args += "-Xmx$($cfg.Xmx)" }
  if ($cfg.UseAOTCache) {
    $aotPath = Join-Path $serverDir 'HytaleServer.aot'
    if (Test-Path $aotPath) { $args += "-XX:AOTCache=HytaleServer.aot" }
  }
  $auth = Normalize-AuthMode -Value $AuthMode -Default 'offline'
  $args += @('-jar','HytaleServer.jar','--assets',$cfg.AssetsZip,'--auth-mode',$auth,'--bind',"0.0.0.0:$port",'--disable-sentry')

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'java'
  $psi.Arguments = Join-Args -Args $args
  $psi.WorkingDirectory = $serverDir
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.RedirectStandardInput = $true
  $psi.CreateNoWindow = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi

  $stdoutWriter = New-Object System.IO.StreamWriter($stdout, $true, [System.Text.Encoding]::UTF8)
  $stderrWriter = New-Object System.IO.StreamWriter($stderr, $true, [System.Text.Encoding]::UTF8)
  $stdoutHandler = [System.Diagnostics.DataReceivedEventHandler]{ param($sender,$e) if ($e.Data) { $stdoutWriter.WriteLine($e.Data); $stdoutWriter.Flush() } }
  $stderrHandler = [System.Diagnostics.DataReceivedEventHandler]{ param($sender,$e) if ($e.Data) { $stderrWriter.WriteLine($e.Data); $stderrWriter.Flush() } }
  $proc.add_OutputDataReceived($stdoutHandler)
  $proc.add_ErrorDataReceived($stderrHandler)
  $null = $proc.Start()
  $proc.BeginOutputReadLine()
  $proc.BeginErrorReadLine()
  Apply-ProcessTuning -cfg $cfg -proc $proc

  return [pscustomobject]@{
    TestId = $testId
    TestDir = $testDir
    Mods = $mods
    Port = $port
    StartTime = Get-Date
    Process = $proc
    Stdout = $stdout
    Stderr = $stderr
    StdIn = $proc.StandardInput
    StdoutWriter = $stdoutWriter
    StderrWriter = $stderrWriter
  }
}

function Stop-ScenarioInstance {
  param($inst)
  try {
    if ($inst.StdIn) { $inst.StdIn.WriteLine("stop"); $inst.StdIn.Flush() }
  } catch {}
  try {
    if ($inst.Process -and -not $inst.Process.HasExited) { $inst.Process.WaitForExit(3000) | Out-Null }
  } catch {}
  try {
    if ($inst.Process -and -not $inst.Process.HasExited) { $inst.Process.Kill() }
  } catch {}
  try { if ($inst.StdoutWriter) { $inst.StdoutWriter.Flush(); $inst.StdoutWriter.Close() } } catch {}
  try { if ($inst.StderrWriter) { $inst.StderrWriter.Flush(); $inst.StderrWriter.Close() } } catch {}
}

function Read-NewText {
  param([string]$Path, [ref]$Offset)
  if (-not (Test-Path $Path)) { return '' }
  $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
    $fs.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin) | Out-Null
    $sr = New-Object System.IO.StreamReader($fs)
    $text = $sr.ReadToEnd()
    $Offset.Value = $fs.Position
    $sr.Close()
    return $text
  } finally {
    $fs.Close()
  }
}

function Wait-ForPattern {
  param($cfg, [string]$Pattern, [int]$TimeoutSeconds, [string]$StdoutPath, [string]$StderrPath, [ref]$StdoutOffset, [ref]$StderrOffset)
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $buffer = ''
  while ((Get-Date) -lt $deadline) {
    $buffer += (Read-NewText -Path $StdoutPath -Offset $StdoutOffset)
    $buffer += (Read-NewText -Path $StderrPath -Offset $StderrOffset)
    $errorBuffer = Remove-IgnoredLines -Text $buffer -IgnorePatterns $cfg.ErrorIgnorePatterns
    foreach ($p in $cfg.ErrorPatterns) {
      if ($errorBuffer -match $p) { return @{ Status = 'fail'; Reason = "error pattern: $p" } }
    }
    if ($buffer -match $Pattern) { return @{ Status = 'pass'; Reason = 'matched' } }
    if ($buffer.Length -gt 20000) { $buffer = $buffer.Substring($buffer.Length - 20000) }
    Start-Sleep -Milliseconds 250
  }
  return @{ Status = 'fail'; Reason = 'timeout' }
}

function Wait-ForReady {
  param($cfg, [int]$TimeoutSeconds, [string]$StdoutPath, [string]$StderrPath, [ref]$StdoutOffset, [ref]$StderrOffset)
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $buffer = ''
  while ((Get-Date) -lt $deadline) {
    $buffer += (Read-NewText -Path $StdoutPath -Offset $StdoutOffset)
    $buffer += (Read-NewText -Path $StderrPath -Offset $StderrOffset)
    $errorBuffer = Remove-IgnoredLines -Text $buffer -IgnorePatterns $cfg.ErrorIgnorePatterns
    foreach ($p in $cfg.ErrorPatterns) {
      if ($errorBuffer -match $p) { return @{ Status = 'fail'; Reason = "error pattern: $p" } }
    }
    foreach ($p in $cfg.ReadyPatterns) {
      if ($buffer -match $p) { return @{ Status = 'pass'; Reason = "ready: $p" } }
    }
    if ($buffer.Length -gt 20000) { $buffer = $buffer.Substring($buffer.Length - 20000) }
    Start-Sleep -Milliseconds 250
  }
  return @{ Status = 'fail'; Reason = 'timeout' }
}

function Get-LogStatus {
  param($cfg, $inst)
  $text = ''
  if (Test-Path $inst.Stdout) { $text += (Get-Content -Raw -Path $inst.Stdout) }
  if (Test-Path $inst.Stderr) { $text += "`n" + (Get-Content -Raw -Path $inst.Stderr) }

  $errorText = Remove-IgnoredLines -Text $text -IgnorePatterns $cfg.ErrorIgnorePatterns
  foreach ($p in $cfg.ErrorPatterns) {
    if ($errorText -match $p) { return @{ Status = 'error'; Pattern = $p } }
  }
  foreach ($p in $cfg.ReadyPatterns) {
    if ($text -match $p) { return @{ Status = 'ready'; Pattern = $p } }
  }
  return @{ Status = 'running'; Pattern = '' }
}

function Run-DepScan {
  param($cfg)
  Ensure-Dirs -cfg $cfg
  $mods = Get-ModFiles -cfg $cfg
  $excludes = Load-Excludes -cfg $cfg
  if ($excludes.Count -gt 0) { $mods = Filter-Mods -mods $mods -excludes $excludes }
  $overrides = Load-DepOverrides -cfg $cfg
  $modMaps = Build-ModMaps -mods $mods -overrides $overrides
  $metaByPath = $modMaps.MetaByPath
  $modById = $modMaps.ModById

  $items = @()
  $missingAll = New-Object 'System.Collections.Generic.HashSet[string]'
  $modsWithMissing = 0
  $modsWithUndeclared = 0
  foreach ($m in $mods) {
    $meta = $metaByPath[$m.Path]
    $decl = @()
    $effective = @()
    $missing = @()
    $undeclared = @()
    if ($meta) {
      $decl = @($meta.DeclaredDependencies)
      $effective = @($meta.Dependencies)
      foreach ($dep in $effective) {
        if (Is-BuiltinDependency -Dep $dep) { continue }
        if (-not $modById.ContainsKey($dep)) {
          $missing += $dep
          $null = $missingAll.Add($dep)
        }
      }
      if ($meta.OverrideDependencies -and $meta.OverrideDependencies.Count -gt 0) {
        foreach ($od in $meta.OverrideDependencies) {
          if (-not ($decl -contains $od)) { $undeclared += $od }
        }
      }
    }
    if ($missing.Count -gt 0) { $modsWithMissing++ }
    if ($undeclared.Count -gt 0) { $modsWithUndeclared++ }
    $items += [pscustomobject]@{
      Mod = $m.Name
      Id = if ($meta) { $meta.Id } else { '' }
      DeclaredDependencies = $decl
      EffectiveDependencies = $effective
      MissingDependencies = $missing
      UndeclaredHardDependencies = $undeclared
    }
  }

  $summary = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    GeneratedAt = (Get-Date).ToString('s')
    TotalMods = $mods.Count
    ModsWithMissing = $modsWithMissing
    ModsWithUndeclared = $modsWithUndeclared
    MissingUnique = @($missingAll)
  }

  $payload = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    GeneratedAt = (Get-Date).ToString('s')
    Summary = $summary
    Mods = $items
  }

  $jsonPath = Join-Path $cfg.ReportsDir 'deps.json'
  $mdPath = Join-Path $cfg.ReportsDir 'deps.md'
  $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding Ascii

  $md = @()
  $md += "# Hylab Dependency Preflight"
  $md += ""
  $md += "TotalMods: $($summary.TotalMods)"
  $md += "ModsWithMissing: $($summary.ModsWithMissing)"
  $md += "ModsWithUndeclared: $($summary.ModsWithUndeclared)"
  if ($summary.MissingUnique.Count -gt 0) {
    $md += "MissingUnique: $($summary.MissingUnique -join ', ')"
  }
  $md += ""
  $md += "## Mods with missing dependencies"
  foreach ($item in ($items | Where-Object { $_.MissingDependencies.Count -gt 0 })) {
    $md += "- $($item.Mod) ($($item.Id)) -> $($item.MissingDependencies -join ', ')"
  }
  $md += ""
  $md += "## Undeclared hard dependencies (from overrides)"
  foreach ($item in ($items | Where-Object { $_.UndeclaredHardDependencies.Count -gt 0 })) {
    $md += "- $($item.Mod) ($($item.Id)) -> $($item.UndeclaredHardDependencies -join ', ')"
  }
  $md | Set-Content -Path $mdPath -Encoding Ascii

  Write-Host "Deps report: $jsonPath"
  Write-Host "Deps summary: $mdPath"
}

function Run-BootTests {
  param($cfg, $plan, [string]$RunId, [int]$StartIndex, [int]$Count, [int]$Limit)
  Ensure-Template -cfg $cfg
  Apply-RunRetention -cfg $cfg
  $runId = if ($RunId) { $RunId } else { (Get-Date).ToString('yyyyMMdd-HHmmss') }
  $runRoot = Join-Path $cfg.RunsDir $runId
  if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Path $runRoot -Force | Out-Null }
  $resourcePath = $null
  if ($cfg.ResourceLogIntervalSec -gt 0) {
    $resourcePath = Join-Path $cfg.ReportsDir ("resource-$runId.csv")
  }
  $script:TraceRunId = $runId
  $script:TraceLogLevel = $cfg.TraceLogLevel
  $script:TraceLogPath = Join-Path $cfg.ReportsDir ("trace-$runId.jsonl")
  $script:BootTimeSamples = New-Object System.Collections.Generic.Queue[int]
  $lastThrottleLog = [datetime]::MinValue

  $tests = $plan.Tests
  $modList = $plan.Mods
  $overrides = Load-DepOverrides -cfg $cfg
  $modMaps = Build-ModMaps -mods $modList -overrides $overrides
  $metaByPath = $modMaps.MetaByPath
  $modById = $modMaps.ModById

  $start = 0
  if ($PSBoundParameters.ContainsKey('StartIndex')) { $start = [int]$StartIndex }
  if ($start -lt 0 -or $start -ge $tests.Count) { throw "StartIndex out of range: $start" }

  $maxCount = $tests.Count
  if ($PSBoundParameters.ContainsKey('Count')) {
    $maxCount = [int]$Count
  } elseif ($PSBoundParameters.ContainsKey('Limit')) {
    $maxCount = [int]$Limit
  }
  if ($maxCount -lt 1) { throw "Count/Limit must be >= 1." }
  $end = [Math]::Min($tests.Count - 1, $start + $maxCount - 1)
  Write-Host "Booting tests $start..$end of $($tests.Count - 1)"

  $queue = New-Object System.Collections.Generic.Queue[object]
  for ($i = $start; $i -le $end; $i++) {
    $queue.Enqueue(@{ Id = $i; Indices = $tests[$i] })
  }

  $running = @()
  $results = @()
  $staged = New-Object System.Collections.Generic.Queue[object]
  $stageAhead = if ($cfg.StageAheadCount -gt 0) { $cfg.StageAheadCount } else { $cfg.MaxParallel }
  $port = $cfg.PortStart
  $total = ($end - $start + 1)
  $lastProgress = -1
  $lastProgressLog = [datetime]::MinValue
  $effectiveMaxParallel = $cfg.MaxParallel
  $lastAdjust = [datetime]::MinValue
  $monitor = Start-ResourceMonitor -cfg $cfg -Path $resourcePath
  Write-Trace -Level 'info' -Event 'run_start' -TestId -1 -Data @{
    StartIndex = $start
    EndIndex = $end
    Total = $total
    MaxParallel = $cfg.MaxParallel
    BootTimeoutSeconds = $cfg.BootTimeoutSeconds
    Xmx = $cfg.Xmx
    Xms = $cfg.Xms
  }

  while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    $stats = $script:ResourceStats
    if (-not $stats) { $stats = Get-SystemStats }
    if ($cfg.AdaptiveThrottleEnabled) {
      Adjust-Parallel -cfg $cfg -Stats $stats -EffectiveMaxParallel ([ref]$effectiveMaxParallel) -LastAdjust ([ref]$lastAdjust)
    }
    if ($effectiveMaxParallel -lt 1) { $effectiveMaxParallel = 1 }
    while ($staged.Count -lt $stageAhead -and $queue.Count -gt 0) {
      $next = $queue.Dequeue()
      $mods = @()
      foreach ($idx in $next.Indices) { $mods += $modList[$idx] }
      $stageResult = Stage-TestInstance -cfg $cfg -testId $next.Id -mods $mods -runRoot $runRoot -metaByPath $metaByPath -modById $modById
      if ($stageResult.SkipResult) {
        $skip = $stageResult.SkipResult
        $skip | Add-Member -NotePropertyName RunId -NotePropertyValue $runId -Force
        $results += $skip
        Write-Trace -Level 'warn' -Event 'test_skip' -TestId $next.Id -Data @{
          Reason = 'skip'
          Pattern = $skip.Pattern
        }
        continue
      }
      $staged.Enqueue($stageResult.Stage)
    }
    while ($running.Count -lt $effectiveMaxParallel -and $staged.Count -gt 0) {
      if (-not $stats) { $stats = Get-SystemStats }
      if ($stats -and (Test-Throttle -cfg $cfg -Stats $stats)) {
        if (((Get-Date) - $lastThrottleLog).TotalSeconds -ge 5) {
          Write-Host ("Throttle spawn: CPU {0}% Mem {1}% (limits {2}%/{3}%)" -f $stats.CpuPct, $stats.MemPct, $cfg.ThrottleCpuPct, $cfg.ThrottleMemPct)
          $lastThrottleLog = Get-Date
        }
        $delay = if ($cfg.ThrottleCheckIntervalMs -gt 0) { $cfg.ThrottleCheckIntervalMs } else { 250 }
        Start-Sleep -Milliseconds $delay
        break
      }
      $stage = $staged.Dequeue()
      $inst = Start-StagedInstance -cfg $cfg -stage $stage -port $port
      $modNames = if ((Resolve-TraceLevel -Value $script:TraceLogLevel) -ge 3) { @($stage.Mods | ForEach-Object { $_.Name }) } else { @() }
      Write-Trace -Level 'info' -Event 'instance_start' -TestId $stage.TestId -Data @{
        Port = $port
        ModCount = $stage.Mods.Count
        Mods = $modNames
      }
      $running += $inst
      $port++
      if ($port -gt $cfg.PortEnd) { $port = $cfg.PortStart }
    }

    $stillRunning = @()
    foreach ($inst in $running) {
      $elapsed = (Get-Date) - $inst.StartTime
      $status = Get-LogStatus -cfg $cfg -inst $inst
      if ($status.Status -eq 'ready') {
        try { Stop-Process -Id $inst.Process.Id -Force } catch {}
        $results += [pscustomobject]@{
          RunId = $runId
          TestId = $inst.TestId
          Status = 'pass'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $status.Pattern
          LogDir = $inst.TestDir
          Port = $inst.Port
          StartedAt = $inst.StartTime.ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Update-RunIndex -RunRoot $runRoot -TestId $inst.TestId -Status 'pass' -DurationSec ([int]$elapsed.TotalSeconds) -Pattern $status.Pattern -Port $inst.Port -TestDir $inst.TestDir -StartedAt $inst.StartTime.ToString('s') -CompletedAt (Get-Date).ToString('s')
        if (-not (Prune-TestArtifacts -cfg $cfg -TestDir $inst.TestDir -Status 'pass')) {
          Trim-InstanceLogs -cfg $cfg -inst $inst
        }
        Add-BootTimeSample -cfg $cfg -Seconds ([int]$elapsed.TotalSeconds)
        Write-Trace -Level 'info' -Event 'test_result' -TestId $inst.TestId -Data @{
          Status = 'pass'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $status.Pattern
          Port = $inst.Port
        }
      } elseif ($status.Status -eq 'error') {
        try { Stop-Process -Id $inst.Process.Id -Force } catch {}
        $results += [pscustomobject]@{
          RunId = $runId
          TestId = $inst.TestId
          Status = 'fail'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $status.Pattern
          LogDir = $inst.TestDir
          Port = $inst.Port
          StartedAt = $inst.StartTime.ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Update-RunIndex -RunRoot $runRoot -TestId $inst.TestId -Status 'fail' -DurationSec ([int]$elapsed.TotalSeconds) -Pattern $status.Pattern -Port $inst.Port -TestDir $inst.TestDir -StartedAt $inst.StartTime.ToString('s') -CompletedAt (Get-Date).ToString('s')
        Trim-InstanceLogs -cfg $cfg -inst $inst
        Add-BootTimeSample -cfg $cfg -Seconds ([int]$elapsed.TotalSeconds)
        $tail = @{}
        if ((Resolve-TraceLevel -Value $script:TraceLogLevel) -ge 3) {
          $tail.StdoutTail = Get-LogTail -Path $inst.Stdout -Lines $cfg.DebugTailLines
          $tail.StderrTail = Get-LogTail -Path $inst.Stderr -Lines $cfg.DebugTailLines
        }
        Write-Trace -Level 'warn' -Event 'test_result' -TestId $inst.TestId -Data @{
          Status = 'fail'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $status.Pattern
          Port = $inst.Port
          Debug = $tail
        }
      } elseif ($elapsed.TotalSeconds -ge $cfg.BootTimeoutSeconds) {
        try { Stop-Process -Id $inst.Process.Id -Force } catch {}
        $results += [pscustomobject]@{
          RunId = $runId
          TestId = $inst.TestId
          Status = 'timeout'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = ''
          LogDir = $inst.TestDir
          Port = $inst.Port
          StartedAt = $inst.StartTime.ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Update-RunIndex -RunRoot $runRoot -TestId $inst.TestId -Status 'timeout' -DurationSec ([int]$elapsed.TotalSeconds) -Pattern '' -Port $inst.Port -TestDir $inst.TestDir -StartedAt $inst.StartTime.ToString('s') -CompletedAt (Get-Date).ToString('s')
        Trim-InstanceLogs -cfg $cfg -inst $inst
        Add-BootTimeSample -cfg $cfg -Seconds ([int]$elapsed.TotalSeconds)
        $tail = @{}
        if ((Resolve-TraceLevel -Value $script:TraceLogLevel) -ge 3) {
          $tail.StdoutTail = Get-LogTail -Path $inst.Stdout -Lines $cfg.DebugTailLines
          $tail.StderrTail = Get-LogTail -Path $inst.Stderr -Lines $cfg.DebugTailLines
        }
        Write-Trace -Level 'warn' -Event 'test_result' -TestId $inst.TestId -Data @{
          Status = 'timeout'
          DurationSec = [int]$elapsed.TotalSeconds
          Port = $inst.Port
          Debug = $tail
        }
      } else {
        $stillRunning += $inst
      }
    }

    $running = $stillRunning
    $completed = $results.Count
    if ($completed -ne $lastProgress -and ((((Get-Date) - $lastProgressLog).TotalSeconds -ge 5) -or $completed -eq $total)) {
      Write-Host "Progress: $completed/$total complete (parallel=$effectiveMaxParallel)"
      $lastProgress = $completed
      $lastProgressLog = Get-Date
    }
    Start-Sleep -Milliseconds 750
  }
  Stop-ResourceMonitor -timer $monitor
  if ($resourcePath -and -not (Test-Path $resourcePath)) {
    $stats = if ($script:ResourceStats) { $script:ResourceStats } else { Get-SystemStats }
    Write-ResourceSample -Path $resourcePath -Stats $stats
  }
  Write-Trace -Level 'info' -Event 'run_end' -TestId -1 -Data @{
    Total = $total
    Results = $results.Count
  }

  $reportPath = Join-Path $cfg.ReportsDir "boot-$runId.csv"
  if (Test-Path $reportPath) {
    $results | Export-Csv -Path $reportPath -NoTypeInformation -Append
  } else {
    $results | Export-Csv -Path $reportPath -NoTypeInformation
  }
  Write-Host "Boot report: $reportPath"
}

function Expand-JoinCommand {
  param([string]$Command, [string]$RunId, [int]$TestId, [int]$Port, [string]$TestDir, [string]$LogDir)
  $cmd = $Command
  $cmd = $cmd -replace '\{host\}', '127.0.0.1'
  $cmd = $cmd -replace '\{port\}', "$Port"
  $cmd = $cmd -replace '\{runId\}', $RunId
  $cmd = $cmd -replace '\{testId\}', "$TestId"
  $cmd = $cmd -replace '\{testDir\}', $TestDir
  $cmd = $cmd -replace '\{logDir\}', $LogDir
  return $cmd
}

function Invoke-JoinCommand {
  param($cfg, [string]$Command, [string]$RunId, [int]$TestId, [string]$TestDir, [int]$Port)
  if (-not $Command) {
    return [pscustomobject]@{ Status = 'skip'; Reason = 'join command not configured'; LogDir = '' }
  }
  $logDir = Join-Path $TestDir 'join'
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  $stdout = Join-Path $logDir 'stdout.log'
  $stderr = Join-Path $logDir 'stderr.log'
  $expanded = Expand-JoinCommand -Command $Command -RunId $RunId -TestId $TestId -Port $Port -TestDir $TestDir -LogDir $logDir
  try {
    $proc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $expanded -WorkingDirectory $TestDir -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -NoNewWindow
  } catch {
    return [pscustomobject]@{ Status = 'fail'; Reason = 'join command failed to start'; LogDir = $logDir }
  }
  $finished = $true
  if ($cfg.JoinTimeoutSeconds -gt 0) {
    $finished = $proc.WaitForExit($cfg.JoinTimeoutSeconds * 1000)
  } else {
    $proc.WaitForExit()
  }
  if (-not $finished) {
    try { Stop-Process -Id $proc.Id -Force } catch {}
    Trim-LogFile -Path $stdout -MaxBytes $cfg.LogMaxBytes
    Trim-LogFile -Path $stderr -MaxBytes $cfg.LogMaxBytes
    return [pscustomobject]@{ Status = 'timeout'; Reason = 'join timeout'; LogDir = $logDir }
  }
  if ($proc.ExitCode -ne 0) {
    Trim-LogFile -Path $stdout -MaxBytes $cfg.LogMaxBytes
    Trim-LogFile -Path $stderr -MaxBytes $cfg.LogMaxBytes
    return [pscustomobject]@{ Status = 'fail'; Reason = "join exit code $($proc.ExitCode)"; LogDir = $logDir }
  }
  Trim-LogFile -Path $stdout -MaxBytes $cfg.LogMaxBytes
  Trim-LogFile -Path $stderr -MaxBytes $cfg.LogMaxBytes
  return [pscustomobject]@{ Status = 'pass'; Reason = 'join ok'; LogDir = $logDir }
}

function Run-JoinTests {
  param($cfg, $plan, [string]$RunId, [int]$StartIndex, [int]$Count, [int]$Limit)
  Ensure-Template -cfg $cfg
  Apply-RunRetention -cfg $cfg
  $runId = if ($RunId) { $RunId } else { (Get-Date).ToString('yyyyMMdd-HHmmss') }
  $runRoot = Join-Path $cfg.RunsDir $runId
  if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Path $runRoot -Force | Out-Null }
  $resourcePath = $null
  if ($cfg.ResourceLogIntervalSec -gt 0) {
    $resourcePath = Join-Path $cfg.ReportsDir ("resource-$runId.csv")
  }
  $script:TraceRunId = $runId
  $script:TraceLogLevel = $cfg.TraceLogLevel
  $script:TraceLogPath = Join-Path $cfg.ReportsDir ("trace-$runId.jsonl")
  $script:BootTimeSamples = New-Object System.Collections.Generic.Queue[int]
  $lastThrottleLog = [datetime]::MinValue

  $tests = $plan.Tests
  $modList = $plan.Mods
  $overrides = Load-DepOverrides -cfg $cfg
  $modMaps = Build-ModMaps -mods $modList -overrides $overrides
  $metaByPath = $modMaps.MetaByPath
  $modById = $modMaps.ModById

  $start = 0
  if ($PSBoundParameters.ContainsKey('StartIndex')) { $start = [int]$StartIndex }
  if ($start -lt 0 -or $start -ge $tests.Count) { throw "StartIndex out of range: $start" }

  $maxCount = $tests.Count
  if ($PSBoundParameters.ContainsKey('Count')) {
    $maxCount = [int]$Count
  } elseif ($PSBoundParameters.ContainsKey('Limit')) {
    $maxCount = [int]$Limit
  }
  if ($maxCount -lt 1) { throw "Count/Limit must be >= 1." }
  $end = [Math]::Min($tests.Count - 1, $start + $maxCount - 1)
  Write-Host "Join testing tests $start..$end of $($tests.Count - 1)"

  $queue = New-Object System.Collections.Generic.Queue[object]
  for ($i = $start; $i -le $end; $i++) {
    $queue.Enqueue(@{ Id = $i; Indices = $tests[$i] })
  }

  $results = @()
  if (-not $cfg.JoinCommand) {
    for ($i = $start; $i -le $end; $i++) {
      $results += [pscustomobject]@{
        RunId = $runId
        TestId = $i
        Status = 'skip'
        DurationSec = 0
        Pattern = 'join command not configured'
        LogDir = ''
        Port = $null
        StartedAt = (Get-Date).ToString('s')
        CompletedAt = (Get-Date).ToString('s')
      }
    }
    $reportPath = Join-Path $cfg.ReportsDir "join-$runId.csv"
    $results | Export-Csv -Path $reportPath -NoTypeInformation
    Write-Host "Join report: $reportPath"
    return
  }

  $running = @()
  $staged = New-Object System.Collections.Generic.Queue[object]
  $stageAhead = if ($cfg.StageAheadCount -gt 0) { $cfg.StageAheadCount } else { $cfg.MaxParallel }
  $port = $cfg.PortStart
  $total = ($end - $start + 1)
  $lastProgress = -1
  $lastProgressLog = [datetime]::MinValue
  $effectiveMaxParallel = $cfg.MaxParallel
  $lastAdjust = [datetime]::MinValue
  $monitor = Start-ResourceMonitor -cfg $cfg -Path $resourcePath
  Write-Trace -Level 'info' -Event 'run_start' -TestId -1 -Data @{
    StartIndex = $start
    EndIndex = $end
    Total = $total
    MaxParallel = $cfg.MaxParallel
    BootTimeoutSeconds = $cfg.BootTimeoutSeconds
    JoinTimeoutSeconds = $cfg.JoinTimeoutSeconds
    JoinAuthMode = $cfg.JoinAuthMode
  }

  while ($queue.Count -gt 0 -or $running.Count -gt 0) {
    $stats = $script:ResourceStats
    if (-not $stats) { $stats = Get-SystemStats }
    if ($cfg.AdaptiveThrottleEnabled) {
      Adjust-Parallel -cfg $cfg -Stats $stats -EffectiveMaxParallel ([ref]$effectiveMaxParallel) -LastAdjust ([ref]$lastAdjust)
    }
    if ($effectiveMaxParallel -lt 1) { $effectiveMaxParallel = 1 }
    while ($staged.Count -lt $stageAhead -and $queue.Count -gt 0) {
      $next = $queue.Dequeue()
      $mods = @()
      foreach ($idx in $next.Indices) { $mods += $modList[$idx] }
      $stageResult = Stage-TestInstance -cfg $cfg -testId $next.Id -mods $mods -runRoot $runRoot -metaByPath $metaByPath -modById $modById
      if ($stageResult.SkipResult) {
        $skip = $stageResult.SkipResult
        $skip | Add-Member -NotePropertyName RunId -NotePropertyValue $runId -Force
        $results += $skip
        Write-Trace -Level 'warn' -Event 'test_skip' -TestId $next.Id -Data @{
          Reason = 'skip'
          Pattern = $skip.Pattern
        }
        continue
      }
      $staged.Enqueue($stageResult.Stage)
    }
    while ($running.Count -lt $effectiveMaxParallel -and $staged.Count -gt 0) {
      if (-not $stats) { $stats = Get-SystemStats }
      if ($stats -and (Test-Throttle -cfg $cfg -Stats $stats)) {
        if (((Get-Date) - $lastThrottleLog).TotalSeconds -ge 5) {
          Write-Host ("Throttle spawn: CPU {0}% Mem {1}% (limits {2}%/{3}%)" -f $stats.CpuPct, $stats.MemPct, $cfg.ThrottleCpuPct, $cfg.ThrottleMemPct)
          $lastThrottleLog = Get-Date
        }
        $delay = if ($cfg.ThrottleCheckIntervalMs -gt 0) { $cfg.ThrottleCheckIntervalMs } else { 250 }
        Start-Sleep -Milliseconds $delay
        break
      }
      $stage = $staged.Dequeue()
      $inst = Start-StagedInstance -cfg $cfg -stage $stage -port $port -AuthMode $cfg.JoinAuthMode
      $modNames = if ((Resolve-TraceLevel -Value $script:TraceLogLevel) -ge 3) { @($stage.Mods | ForEach-Object { $_.Name }) } else { @() }
      Write-Trace -Level 'info' -Event 'instance_start' -TestId $stage.TestId -Data @{
        Port = $port
        ModCount = $stage.Mods.Count
        Mods = $modNames
        JoinAuthMode = $cfg.JoinAuthMode
      }
      $running += $inst
      $port++
      if ($port -gt $cfg.PortEnd) { $port = $cfg.PortStart }
    }

    $stillRunning = @()
    foreach ($inst in $running) {
      $elapsed = (Get-Date) - $inst.StartTime
      $status = Get-LogStatus -cfg $cfg -inst $inst
      if ($status.Status -eq 'ready') {
        $join = Invoke-JoinCommand -cfg $cfg -Command $cfg.JoinCommand -RunId $runId -TestId $inst.TestId -TestDir $inst.TestDir -Port $inst.Port
        try { Stop-Process -Id $inst.Process.Id -Force } catch {}
        $elapsed = (Get-Date) - $inst.StartTime
        $finalStatus = $join.Status
        $pattern = if ($join.Status -eq 'pass') { $status.Pattern } else { $join.Reason }
        $results += [pscustomobject]@{
          RunId = $runId
          TestId = $inst.TestId
          Status = $finalStatus
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $pattern
          LogDir = $inst.TestDir
          Port = $inst.Port
          StartedAt = $inst.StartTime.ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Update-RunIndex -RunRoot $runRoot -TestId $inst.TestId -Status $finalStatus -DurationSec ([int]$elapsed.TotalSeconds) -Pattern $pattern -Port $inst.Port -TestDir $inst.TestDir -StartedAt $inst.StartTime.ToString('s') -CompletedAt (Get-Date).ToString('s')
        if (-not (Prune-TestArtifacts -cfg $cfg -TestDir $inst.TestDir -Status $finalStatus)) {
          Trim-InstanceLogs -cfg $cfg -inst $inst
        }
        Add-BootTimeSample -cfg $cfg -Seconds ([int]$elapsed.TotalSeconds)
        Write-Trace -Level 'info' -Event 'test_result' -TestId $inst.TestId -Data @{
          Status = $finalStatus
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $pattern
          Port = $inst.Port
          JoinLogDir = $join.LogDir
        }
      } elseif ($status.Status -eq 'error') {
        try { Stop-Process -Id $inst.Process.Id -Force } catch {}
        $results += [pscustomobject]@{
          RunId = $runId
          TestId = $inst.TestId
          Status = 'fail'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $status.Pattern
          LogDir = $inst.TestDir
          Port = $inst.Port
          StartedAt = $inst.StartTime.ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Update-RunIndex -RunRoot $runRoot -TestId $inst.TestId -Status 'fail' -DurationSec ([int]$elapsed.TotalSeconds) -Pattern $status.Pattern -Port $inst.Port -TestDir $inst.TestDir -StartedAt $inst.StartTime.ToString('s') -CompletedAt (Get-Date).ToString('s')
        Trim-InstanceLogs -cfg $cfg -inst $inst
        Add-BootTimeSample -cfg $cfg -Seconds ([int]$elapsed.TotalSeconds)
        Write-Trace -Level 'warn' -Event 'test_result' -TestId $inst.TestId -Data @{
          Status = 'fail'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = $status.Pattern
          Port = $inst.Port
        }
      } elseif ($elapsed.TotalSeconds -ge $cfg.BootTimeoutSeconds) {
        try { Stop-Process -Id $inst.Process.Id -Force } catch {}
        $results += [pscustomobject]@{
          RunId = $runId
          TestId = $inst.TestId
          Status = 'timeout'
          DurationSec = [int]$elapsed.TotalSeconds
          Pattern = ''
          LogDir = $inst.TestDir
          Port = $inst.Port
          StartedAt = $inst.StartTime.ToString('s')
          CompletedAt = (Get-Date).ToString('s')
        }
        Update-RunIndex -RunRoot $runRoot -TestId $inst.TestId -Status 'timeout' -DurationSec ([int]$elapsed.TotalSeconds) -Pattern '' -Port $inst.Port -TestDir $inst.TestDir -StartedAt $inst.StartTime.ToString('s') -CompletedAt (Get-Date).ToString('s')
        Trim-InstanceLogs -cfg $cfg -inst $inst
        Add-BootTimeSample -cfg $cfg -Seconds ([int]$elapsed.TotalSeconds)
        Write-Trace -Level 'warn' -Event 'test_result' -TestId $inst.TestId -Data @{
          Status = 'timeout'
          DurationSec = [int]$elapsed.TotalSeconds
          Port = $inst.Port
        }
      } else {
        $stillRunning += $inst
      }
    }

    $running = $stillRunning
    $completed = $results.Count
    if ($completed -ne $lastProgress -and ((((Get-Date) - $lastProgressLog).TotalSeconds -ge 5) -or $completed -eq $total)) {
      Write-Host "Progress: $completed/$total complete (parallel=$effectiveMaxParallel)"
      $lastProgress = $completed
      $lastProgressLog = Get-Date
    }
    Start-Sleep -Milliseconds 750
  }
  Stop-ResourceMonitor -timer $monitor
  if ($resourcePath -and -not (Test-Path $resourcePath)) {
    $stats = if ($script:ResourceStats) { $script:ResourceStats } else { Get-SystemStats }
    Write-ResourceSample -Path $resourcePath -Stats $stats
  }
  Write-Trace -Level 'info' -Event 'run_end' -TestId -1 -Data @{
    Total = $total
    Results = $results.Count
  }

  $reportPath = Join-Path $cfg.ReportsDir "join-$runId.csv"
  if (Test-Path $reportPath) {
    $results | Export-Csv -Path $reportPath -NoTypeInformation -Append
  } else {
    $results | Export-Csv -Path $reportPath -NoTypeInformation
  }
  Write-Host "Join report: $reportPath"
}

function Invoke-SingleBoot {
  param($cfg, $mods, [string]$runRoot, [int]$testId, [int]$port, $metaByPath, $modById)
  if ($metaByPath -and $modById) {
    $expanded = Expand-ModSet -mods $mods -metaByPath $metaByPath -modById $modById
    if ($expanded.Missing.Count -gt 0) {
      return [pscustomobject]@{
        TestId = $testId
        Status = 'skip'
        DurationSec = 0
        Pattern = "missing dependency: $($expanded.Missing -join ', ')"
        LogDir = ''
        Port = $port
        StartedAt = (Get-Date).ToString('s')
        CompletedAt = (Get-Date).ToString('s')
      }
    }
    $missingFiles = @()
    foreach ($m in $expanded.Mods) {
      if (-not (Test-Path $m.Path)) { $missingFiles += $m.Name }
    }
    if ($missingFiles.Count -gt 0) {
      return [pscustomobject]@{
        TestId = $testId
        Status = 'skip'
        DurationSec = 0
        Pattern = "missing mod files: $($missingFiles -join ', ')"
        LogDir = ''
        Port = $port
        StartedAt = (Get-Date).ToString('s')
        CompletedAt = (Get-Date).ToString('s')
      }
    }
    $mods = $expanded.Mods
  }
  $inst = Start-Instance -cfg $cfg -testId $testId -mods $mods -port $port -runRoot $runRoot
  while ($true) {
    $elapsed = (Get-Date) - $inst.StartTime
    $status = Get-LogStatus -cfg $cfg -inst $inst
    if ($status.Status -eq 'ready') {
      try { Stop-Process -Id $inst.Process.Id -Force } catch {}
      return [pscustomobject]@{
        TestId = $inst.TestId
        Status = 'pass'
        DurationSec = [int]$elapsed.TotalSeconds
        Pattern = $status.Pattern
        LogDir = $inst.TestDir
        Port = $inst.Port
        StartedAt = $inst.StartTime.ToString('s')
        CompletedAt = (Get-Date).ToString('s')
      }
    } elseif ($status.Status -eq 'error') {
      try { Stop-Process -Id $inst.Process.Id -Force } catch {}
      return [pscustomobject]@{
        TestId = $inst.TestId
        Status = 'fail'
        DurationSec = [int]$elapsed.TotalSeconds
        Pattern = $status.Pattern
        LogDir = $inst.TestDir
        Port = $inst.Port
        StartedAt = $inst.StartTime.ToString('s')
        CompletedAt = (Get-Date).ToString('s')
      }
    } elseif ($elapsed.TotalSeconds -ge $cfg.BootTimeoutSeconds) {
      try { Stop-Process -Id $inst.Process.Id -Force } catch {}
      return [pscustomobject]@{
        TestId = $inst.TestId
        Status = 'timeout'
        DurationSec = [int]$elapsed.TotalSeconds
        Pattern = ''
        LogDir = $inst.TestDir
        Port = $inst.Port
        StartedAt = $inst.StartTime.ToString('s')
        CompletedAt = (Get-Date).ToString('s')
      }
    }
    Start-Sleep -Milliseconds 500
  }
}

function Run-Proofcheck {
  param($cfg, [switch]$Strict)
  Ensure-Dirs -cfg $cfg
  $mods = Get-ModFiles -cfg $cfg
  $excludes = Load-Excludes -cfg $cfg
  if ($excludes.Count -gt 0) { $mods = Filter-Mods -mods $mods -excludes $excludes }
  $modNames = $mods | ForEach-Object { $_.Name }
  $results = @()

  foreach ($mod in $mods) {
    $hash = Get-ModHash -Path $mod.Path
    $rules = @()
    $manifestInfo = Get-ModManifest -mod $mod

    if (-not $manifestInfo.Found) {
      $rules += [pscustomobject]@{ Id = 'manifest.required'; Status = 'fail'; Severity = 'error'; Evidence = 'manifest not found' }
      $results += [pscustomobject]@{ Mod = $mod.Name; Path = $mod.Path; Hash = $hash; Rules = $rules; Overall = 'fail' }
      continue
    } else {
      $rules += [pscustomobject]@{ Id = 'manifest.required'; Status = 'pass'; Severity = 'error'; Evidence = $manifestInfo.Name }
    }

    $manifest = $null
    try {
      $manifest = $manifestInfo.Text | ConvertFrom-Json
      $rules += [pscustomobject]@{ Id = 'manifest.parse'; Status = 'pass'; Severity = 'error'; Evidence = 'parsed' }
    } catch {
      $rules += [pscustomobject]@{ Id = 'manifest.parse'; Status = 'fail'; Severity = 'error'; Evidence = 'invalid JSON' }
    }

    $entrypoint = Get-EntryPoint -manifest $manifest
    if ($entrypoint) {
      $rules += [pscustomobject]@{ Id = 'entrypoint.declared'; Status = 'pass'; Severity = 'warn'; Evidence = $entrypoint }
    } else {
      $rules += [pscustomobject]@{ Id = 'entrypoint.declared'; Status = 'warn'; Severity = 'warn'; Evidence = 'entrypoint not declared' }
    }

    $deps = Get-DependencyNames -manifest $manifest
    if ($deps.Count -gt 0) {
      $missing = $deps | Where-Object { -not ($modNames -contains $_) }
      if ($missing.Count -gt 0) {
        $rules += [pscustomobject]@{ Id = 'dependency.closure'; Status = 'fail'; Severity = 'error'; Evidence = "missing: $($missing -join ', ')" }
      } else {
        $rules += [pscustomobject]@{ Id = 'dependency.closure'; Status = 'pass'; Severity = 'error'; Evidence = 'all dependencies present' }
      }
    } else {
      $rules += [pscustomobject]@{ Id = 'dependency.closure'; Status = 'pass'; Severity = 'info'; Evidence = 'no dependencies' }
    }

    $hasAsset = $false
    $entryFound = $false
    try {
      Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
      $zip = [System.IO.Compression.ZipFile]::OpenRead($mod.Path)
      $hasAsset = $zip.Entries | Where-Object { $_.FullName -match '\.(blockymodel|blockyanim)$' } | Select-Object -First 1
      if ($entrypoint) {
        $entryPath = ($entrypoint -replace '\.','/') + '.class'
        $entryFound = $zip.Entries | Where-Object { $_.FullName -eq $entryPath } | Select-Object -First 1
      }
      $zip.Dispose()
    } catch {}
    if ($entrypoint) {
      if ($entryFound) {
        $rules += [pscustomobject]@{ Id = 'entrypoint.class'; Status = 'pass'; Severity = 'error'; Evidence = $entrypoint }
      } else {
        $rules += [pscustomobject]@{ Id = 'entrypoint.class'; Status = 'fail'; Severity = 'error'; Evidence = 'entrypoint class not found' }
      }
    }
    if ($hasAsset) {
      $rules += [pscustomobject]@{ Id = 'asset.format'; Status = 'pass'; Severity = 'info'; Evidence = 'asset files found' }
    } else {
      $rules += [pscustomobject]@{ Id = 'asset.format'; Status = 'pass'; Severity = 'info'; Evidence = 'no asset files found' }
    }

    $overall = if ($rules | Where-Object { $_.Status -eq 'fail' }) { 'fail' } elseif ($rules | Where-Object { $_.Status -eq 'warn' }) { if ($Strict) { 'fail' } else { 'warn' } } else { 'pass' }
    $results += [pscustomobject]@{
      Mod = $mod.Name
      Path = $mod.Path
      Hash = $hash
      Rules = $rules
      Overall = $overall
    }
  }

  $payload = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    GeneratedAt = (Get-Date).ToString('s')
    Proofs = $results
  }
  $outPath = Join-Path $cfg.ReportsDir ("proof-{0}.json" -f (Get-Date).ToString('yyyyMMdd-HHmmss'))
  $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding Ascii
  Copy-Item -Path $outPath -Destination (Join-Path $cfg.ReportsDir "proof.json") -Force
  Write-Host "Proofcheck report: $outPath"
}

function Run-Bisect {
  param($cfg, [string]$RunId, [int]$TestId, [string]$Status)
  Ensure-Dirs -cfg $cfg
  $reportCsv = if ($RunId) { Join-Path $cfg.ReportsDir "boot-$RunId.csv" } else { Get-LatestBootReport -cfg $cfg }
  if (-not (Test-Path $reportCsv)) { throw "Report not found: $reportCsv" }
  $rows = Import-Csv -Path $reportCsv
  if (-not $rows -or $rows.Count -eq 0) { throw "Report is empty: $reportCsv" }

  $row = $null
  if ($TestId -ge 0) {
    $row = $rows | Where-Object { [int]$_.TestId -eq $TestId } | Select-Object -First 1
  } else {
    $filter = @('fail','timeout')
    if ($Status) {
      $filter = $Status.Split(',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }
    }
    $row = $rows | Where-Object { $filter -contains $_.Status.ToLower() } | Select-Object -First 1
  }
  if (-not $row) { throw "No matching test found to bisect." }

  $planPath = Join-Path $cfg.ReportsDir 'plan.json'
  if (-not (Test-Path $planPath)) { throw "plan.json not found in reports dir." }
  $plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
  $indices = $plan.Tests[[int]$row.TestId]
  $mods = @()
  foreach ($idx in $indices) { $mods += $plan.Mods[$idx] }

  Ensure-Template -cfg $cfg
  $overrides = Load-DepOverrides -cfg $cfg
  $modMaps = Build-ModMaps -mods $plan.Mods -overrides $overrides
  $metaByPath = $modMaps.MetaByPath
  $modById = $modMaps.ModById
  $bisectRunId = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $runRoot = Join-Path $cfg.RunsDir ("bisect-{0}" -f $bisectRunId)
  New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
  $cache = @{}
  $cachePath = Join-Path $cfg.CacheDir 'bisect-cache.json'
  $cacheHits = 0
  if (Test-Path $cachePath) {
    try {
      $cacheRaw = Get-Content -Raw -Path $cachePath | ConvertFrom-Json
      foreach ($p in $cacheRaw.PSObject.Properties) { $cache[$p.Name] = $p.Value }
    } catch {}
  }
  $attempts = @()
  $port = $cfg.PortStart
  $testCounter = 0

  function Test-Set {
    param($set)
    $key = Get-ModKey -mods $set
    if ($cache.ContainsKey($key)) {
      $cacheHits++
      $cached = $cache[$key]
      if ($cached -is [bool]) { return $cached }
      return ($cached.Status -in @('fail','timeout'))
    }
    $result = Invoke-SingleBoot -cfg $cfg -mods $set -runRoot $runRoot -testId $testCounter -port $port -metaByPath $metaByPath -modById $modById
    $testCounter++
    $port++
    if ($port -gt $cfg.PortEnd) { $port = $cfg.PortStart }
    $fail = $result.Status -in @('fail','timeout')
    $cache[$key] = [pscustomobject]@{ Status = $result.Status; UpdatedAt = (Get-Date).ToString('s') }
    $attempts += [pscustomobject]@{
      Mods = ($set | ForEach-Object { $_.Name })
      Status = $result.Status
      DurationSec = $result.DurationSec
      LogDir = $result.LogDir
    }
    return $fail
  }

  function Ddmin {
    param($set)
    $n = 2
    $current = $set
    while ($current.Count -ge 2) {
      $subsetSize = [int][math]::Ceiling($current.Count / $n)
      $subsets = @()
      for ($i = 0; $i -lt $current.Count; $i += $subsetSize) {
        $subsets += ,($current[$i..([math]::Min($i + $subsetSize - 1, $current.Count - 1))])
      }

      $reduced = $false
      foreach ($subset in $subsets) {
        if (Test-Set -set $subset) {
          $current = $subset
          $n = 2
          $reduced = $true
          break
        }
      }
      if ($reduced) { continue }

      foreach ($subset in $subsets) {
        $complement = $current | Where-Object { $subset -notcontains $_ }
        if ($complement.Count -gt 0 -and (Test-Set -set $complement)) {
          $current = $complement
          $n = 2
          $reduced = $true
          break
        }
      }
      if ($reduced) { continue }

      if ($n -ge $current.Count) { break }
      $n = [math]::Min($current.Count, $n * 2)
    }
    return $current
  }

  $minSet = Ddmin -set $mods
  $payload = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    GeneratedAt = (Get-Date).ToString('s')
    SourceRunId = (Get-RunIdFromReportPath -Path $reportCsv)
    SourceTestId = [int]$row.TestId
    FailureStatus = $row.Status
    FailurePattern = $row.Pattern
    BisectRunId = $bisectRunId
    MinimalSet = ($minSet | ForEach-Object { $_.Name })
    Attempts = $attempts
    CacheHits = $cacheHits
  }
  $outPath = Join-Path $cfg.ReportsDir ("bisect-{0}.json" -f $bisectRunId)
  $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding Ascii
  Copy-Item -Path $outPath -Destination (Join-Path $cfg.ReportsDir "bisect.json") -Force
  $cache | ConvertTo-Json -Depth 6 | Set-Content -Path $cachePath -Encoding Ascii
  Write-Host "Bisect report: $outPath"
}

function Write-Repro {
  param($cfg, [string]$RunId, [int]$TestId, [switch]$IncludeMods)
  Ensure-Dirs -cfg $cfg
  $reportCsv = if ($RunId) { Join-Path $cfg.ReportsDir "boot-$RunId.csv" } else { Get-LatestBootReport -cfg $cfg }
  if (-not (Test-Path $reportCsv)) { throw "Boot report not found: $reportCsv" }
  $rows = Import-Csv -Path $reportCsv
  if (-not $rows -or $rows.Count -eq 0) { throw "Boot report is empty: $reportCsv" }

  $row = $null
  if ($TestId -ge 0) {
    $row = $rows | Where-Object { [int]$_.TestId -eq $TestId } | Select-Object -First 1
  } else {
    $row = $rows | Where-Object { $_.Status -in @('fail','timeout') } | Select-Object -First 1
  }
  if (-not $row) { throw "No test found for repro." }

  $resolvedRunId = if ($RunId) { $RunId } else { Get-RunIdFromReportPath -Path $reportCsv }
  if (-not $resolvedRunId) { $resolvedRunId = (Get-Date).ToString('yyyyMMdd-HHmmss') }
  $bundleId = "repro-$resolvedRunId-$($row.TestId)"
  $reproDir = Join-Path $cfg.ReprosDir $bundleId
  New-Item -ItemType Directory -Path $reproDir -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $reproDir 'logs') -Force | Out-Null

  $logDir = Join-Path $row.LogDir 'logs'
  if (Test-Path $logDir) {
    Copy-Item -Path (Join-Path $logDir '*') -Destination (Join-Path $reproDir 'logs') -Recurse -Force
  }

  $planPath = Join-Path $cfg.ReportsDir 'plan.json'
  if (Test-Path $planPath) {
    Copy-Item -Path $planPath -Destination (Join-Path $reproDir 'plan.json') -Force
  }

  $cfg | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $reproDir 'config.json') -Encoding Ascii

  $mods = @()
  if (Test-Path $planPath) {
    $plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
    $indices = $plan.Tests[[int]$row.TestId]
    foreach ($idx in $indices) { $mods += $plan.Mods[$idx] }
  }

  if ($IncludeMods -and $mods.Count -gt 0) {
    $modsDir = Join-Path $reproDir 'mods'
    New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
    foreach ($m in $mods) { Copy-Item -Path $m.Path -Destination $modsDir -Force }
  }

  $manifest = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    BundleId = $bundleId
    CreatedAt = (Get-Date).ToString('s')
    RunId = $resolvedRunId
    TestId = [int]$row.TestId
    ServerVersion = ''
    Mods = ($mods | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Hash = Get-ModHash -Path $_.Path } })
    ConfigSnapshotPath = 'config.json'
    PlanPath = 'plan.json'
    Logs = @('logs/stdout.log','logs/stderr.log')
    Lanes = @('boot')
    Notes = "Derived from run $resolvedRunId test $($row.TestId)"
  }
  $manifestPath = Join-Path $reproDir 'manifest.json'
  $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestPath -Encoding Ascii

  $checksums = @()
  Get-ChildItem -Path $reproDir -Recurse -File | ForEach-Object {
    $checksums += [pscustomobject]@{
      Path = $_.FullName.Substring($reproDir.Length + 1)
      Hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
    }
  }
  $checksums | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $reproDir 'checksums.json') -Encoding Ascii

  Write-Host "Repro bundle: $reproDir"
}

function Load-Scenario {
  param([string]$Path)
  if (-not (Test-Path $Path)) { throw "Scenario file not found: $Path" }
  $ext = [System.IO.Path]::GetExtension($Path).ToLower()
  $raw = Get-Content -Raw -Path $Path
  if ($ext -in @('.yaml','.yml')) {
    $yamlCmd = Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue
    if (-not $yamlCmd) { throw "YAML not supported in this PowerShell. Use JSON." }
    return $raw | ConvertFrom-Yaml
  }
  return $raw | ConvertFrom-Json
}

function Run-Scenario {
  param($cfg, [string]$ScenarioPath, [string]$RunId, [int]$TestId)
  Ensure-Dirs -cfg $cfg
  if (-not $ScenarioPath) { throw "ScenarioPath is required." }
  $scenario = Load-Scenario -Path $ScenarioPath
  if (-not $scenario.version -or $scenario.version -ne 1) { throw "Scenario version must be 1." }
  if (-not $scenario.steps -or $scenario.steps.Count -eq 0) { throw "Scenario must include steps." }
  $planPath = Join-Path $cfg.ReportsDir 'plan.json'
  if (-not (Test-Path $planPath)) { throw "plan.json not found. Run: .\modlab.ps1 plan" }
  $plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
  $testIndex = if ($TestId -ge 0) { $TestId } else { 0 }
  if ($testIndex -ge $plan.Tests.Count) { throw "TestId out of range: $testIndex" }
  $indices = $plan.Tests[$testIndex]
  $mods = @()
  foreach ($idx in $indices) { $mods += $plan.Mods[$idx] }

  Ensure-Template -cfg $cfg
  $scenarioRunId = if ($RunId) { $RunId } else { (Get-Date).ToString('yyyyMMdd-HHmmss') }
  $overrides = Load-DepOverrides -cfg $cfg
  $modMaps = Build-ModMaps -mods $plan.Mods -overrides $overrides
  $expanded = Expand-ModSet -mods $mods -metaByPath $modMaps.MetaByPath -modById $modMaps.ModById
  if ($expanded.Missing.Count -gt 0) {
    $scenarioId = if ($scenario.id) { $scenario.id } elseif ($scenario.name) { $scenario.name } else { '' }
    $payload = [pscustomobject]@{
      SchemaVersion = '1.0.0'
      GeneratedAt = (Get-Date).ToString('s')
      RunId = $scenarioRunId
      TestId = [int]$testIndex
      ScenarioId = $scenarioId
      ScenarioPath = $ScenarioPath
      Status = 'skip'
      Steps = @()
      Reason = "missing dependency: $($expanded.Missing -join ', ')"
      LogDir = ''
      Port = $cfg.PortStart
      StartedAt = (Get-Date).ToString('s')
      CompletedAt = (Get-Date).ToString('s')
    }
    $outPath = Join-Path $cfg.ReportsDir ("scenario-{0}-{1}.json" -f $payload.RunId, $payload.TestId)
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding Ascii
    Write-Host "Scenario report: $outPath"
    return
  }
  $mods = $expanded.Mods
  $runRoot = Join-Path $cfg.RunsDir $scenarioRunId
  New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
  $inst = Start-ScenarioInstance -cfg $cfg -testId $testIndex -mods $mods -port $cfg.PortStart -runRoot $runRoot
  $stepResults = @()
  $overall = 'fail'
  try {
    $stdoutOffset = 0
    $stderrOffset = 0
    $stepIndex = 0
    foreach ($step in $scenario.steps) {
      $type = $step.type
      $status = 'pass'
      $reason = ''
      $output = ''
      if ($type -eq 'wait-for-ready') {
        $timeout = if ($null -ne $step.timeoutSeconds) { [int]$step.timeoutSeconds } else { $cfg.BootTimeoutSeconds }
        $res = Wait-ForReady -cfg $cfg -TimeoutSeconds $timeout -StdoutPath $inst.Stdout -StderrPath $inst.Stderr -StdoutOffset ([ref]$stdoutOffset) -StderrOffset ([ref]$stderrOffset)
        if ($res.Status -ne 'pass') { $status = 'fail'; $reason = $res.Reason }
      } elseif ($type -eq 'expect-log') {
        if (-not $step.pattern) {
          $status = 'fail'
          $reason = 'pattern required'
        } else {
          $timeout = if ($null -ne $step.timeoutSeconds) { [int]$step.timeoutSeconds } else { 15 }
          $res = Wait-ForPattern -cfg $cfg -Pattern $step.pattern -TimeoutSeconds $timeout -StdoutPath $inst.Stdout -StderrPath $inst.Stderr -StdoutOffset ([ref]$stdoutOffset) -StderrOffset ([ref]$stderrOffset)
          if ($res.Status -ne 'pass') { $status = 'fail'; $reason = $res.Reason }
        }
      } elseif ($type -eq 'sleep') {
        if ($null -eq $step.seconds) {
          $status = 'fail'
          $reason = 'seconds required'
        } else {
          Start-Sleep -Seconds ([int]$step.seconds)
        }
      } elseif ($type -eq 'run-command') {
        if (-not $step.command) {
          $status = 'fail'
          $reason = 'command required'
        } else {
          try {
            $inst.StdIn.WriteLine($step.command)
            $inst.StdIn.Flush()
            Start-Sleep -Milliseconds 250
            $output += (Read-NewText -Path $inst.Stdout -Offset ([ref]$stdoutOffset))
            $output += (Read-NewText -Path $inst.Stderr -Offset ([ref]$stderrOffset))
          } catch {
            $status = 'fail'
            $reason = 'command send failed'
          }
        }
      } else {
        $status = 'fail'
        $reason = "unknown step type: $type"
      }
      $stepResults += [pscustomobject]@{
        StepIndex = $stepIndex
        StepType = $type
        Status = $status
        Reason = $reason
        Command = $step.command
        Pattern = $step.pattern
        Output = $output.Trim()
      }
      if ($status -eq 'fail') { break }
      $stepIndex++
    }
    $overall = if ($stepResults | Where-Object { $_.Status -eq 'fail' }) { 'fail' } else { 'pass' }
  } finally {
    Stop-ScenarioInstance -inst $inst
  }
  $scenarioId = if ($scenario.id) { $scenario.id } elseif ($scenario.name) { $scenario.name } else { '' }
  $payload = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    GeneratedAt = (Get-Date).ToString('s')
    RunId = $scenarioRunId
    TestId = [int]$testIndex
    ScenarioId = $scenarioId
    ScenarioPath = $ScenarioPath
    Status = $overall
    Steps = $stepResults
    LogDir = $inst.TestDir
    Port = $inst.Port
    StartedAt = $inst.StartTime.ToString('s')
    CompletedAt = (Get-Date).ToString('s')
  }
  $outPath = Join-Path $cfg.ReportsDir ("scenario-{0}-{1}.json" -f $payload.RunId, $payload.TestId)
  $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding Ascii
  Write-Host "Scenario report: $outPath"
}

function Get-RunIdFromReportPath {
  param([string]$Path, [string]$Prefix = 'boot')
  if ($Path -match "$Prefix-(.+)\.csv") { return $Matches[1] }
  return ''
}

function Get-LatestBootReport {
  param($cfg, [string]$Prefix = 'boot')
  $files = Get-ChildItem -Path $cfg.ReportsDir -Filter "$Prefix-*.csv" | Sort-Object LastWriteTime -Descending
  if (-not $files -or $files.Count -eq 0) { throw "No $Prefix-*.csv reports found in $($cfg.ReportsDir)" }
  return $files[0].FullName
}

function Escape-Xml {
  param([string]$Text)
  if ($null -eq $Text) { return '' }
  $t = $Text -replace '&','&amp;'
  $t = $t -replace '<','&lt;'
  $t = $t -replace '>','&gt;'
  $t = $t -replace '"','&quot;'
  $t = $t -replace "'","&apos;"
  return $t
}

function Write-JUnit {
  param([string]$Path, [string]$RunId, $Summary, $Results)
  $tests = $Results.Count
  $failures = ($Results | Where-Object { $_.Status -in @('fail','timeout') }).Count
  $skips = ($Results | Where-Object { $_.Status -eq 'skip' }).Count
  $timestamp = (Get-Date).ToString('s')
  $xml = New-Object System.Text.StringBuilder
  [void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
  [void]$xml.AppendLine("<testsuite name=""hylab"" tests=""$tests"" failures=""$failures"" skipped=""$skips"" timestamp=""$timestamp"">")
  foreach ($r in $Results) {
    $caseName = "test-$($r.TestId)"
    $caseTime = $r.DurationSec
    if ($r.Status -eq 'pass') {
      [void]$xml.AppendLine("<testcase name=""$(Escape-Xml $caseName)"" time=""$caseTime"" />")
    } elseif ($r.Status -eq 'skip') {
      [void]$xml.AppendLine("<testcase name=""$(Escape-Xml $caseName)"" time=""$caseTime""><skipped /></testcase>")
    } else {
      $msg = "$($r.Status) $($r.Pattern)"
      [void]$xml.AppendLine("<testcase name=""$(Escape-Xml $caseName)"" time=""$caseTime""><failure message=""$(Escape-Xml $msg)"" /></testcase>")
    }
  }
  [void]$xml.AppendLine("</testsuite>")
  $xml.ToString() | Set-Content -Path $Path -Encoding Ascii
}

function Write-Report {
  param($cfg, [string]$RunId, [string]$Out, [switch]$Json, [switch]$Csv, [switch]$Junit, [string]$Lane)
  $prefix = if ($Lane) { $Lane } else { 'boot' }
  $reportCsv = if ($RunId) { Join-Path $cfg.ReportsDir "$prefix-$RunId.csv" } else { Get-LatestBootReport -cfg $cfg -Prefix $prefix }
  if (-not (Test-Path $reportCsv)) { throw "Boot report not found: $reportCsv" }
  $rows = Import-Csv -Path $reportCsv
  if (-not $rows -or $rows.Count -eq 0) { throw "Boot report is empty: $reportCsv" }

  $resolvedRunId = if ($RunId) { $RunId } else { Get-RunIdFromReportPath -Path $reportCsv -Prefix $prefix }
  if (-not $resolvedRunId) { $resolvedRunId = (Get-Date).ToString('yyyyMMdd-HHmmss') }
  $outDir = if ($Out) { $Out } else { $cfg.ReportsDir }
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
  $wantAny = $Json -or $Csv -or $Junit
  if (-not $wantAny) { $Json = $true; $Csv = $true; $Junit = $true }
  $reportOutCsv = if ($Csv) { Join-Path $outDir ("results-{0}.csv" -f $resolvedRunId) } else { $reportCsv }

  $total = $rows.Count
  $pass = ($rows | Where-Object { $_.Status -eq 'pass' }).Count
  $fail = ($rows | Where-Object { $_.Status -eq 'fail' }).Count
  $timeout = ($rows | Where-Object { $_.Status -eq 'timeout' }).Count
  $skip = ($rows | Where-Object { $_.Status -eq 'skip' }).Count

  $durations = $rows | ForEach-Object { [int]$_.DurationSec } | Sort-Object
  $avg = if ($durations.Count -gt 0) { [math]::Round(($durations | Measure-Object -Average).Average, 2) } else { 0 }
  $p95 = if ($durations.Count -gt 0) { $idx = [math]::Ceiling($durations.Count * 0.95) - 1; $durations[$idx] } else { 0 }

  $failPatterns = $rows | Where-Object { $_.Status -in @('fail','timeout') } | ForEach-Object {
    if ($_.Status -eq 'timeout') { 'timeout' } elseif ($_.Pattern) { $_.Pattern } else { 'unknown' }
  }
  $topFailure = ''
  if ($failPatterns) { $topFailure = ($failPatterns | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name }

  $planPath = Join-Path $cfg.ReportsDir 'plan.json'
  $modCount = $null
  if (Test-Path $planPath) {
    $plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
    if ($plan.Mods) { $modCount = $plan.Mods.Count }
  }

  $summary = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    RunId = $resolvedRunId
    GeneratedAt = (Get-Date).ToString('s')
    Total = $total
    Pass = $pass
    Fail = $fail
    Timeout = $timeout
    Skip = $skip
    AvgDurationSec = $avg
    P95DurationSec = $p95
    TopFailure = $topFailure
    ModCount = $modCount
    ReportCsv = $reportOutCsv
  }

  $results = $rows | ForEach-Object {
    [pscustomobject]@{
      RunId = $_.RunId
      TestId = [int]$_.TestId
      Status = $_.Status
      DurationSec = [int]$_.DurationSec
      Pattern = $_.Pattern
      LogDir = $_.LogDir
      Port = if ($_.Port) { [int]$_.Port } else { $null }
      StartedAt = $_.StartedAt
      CompletedAt = $_.CompletedAt
    }
  }

  $payload = [pscustomobject]@{
    SchemaVersion = '1.0.0'
    RunId = $resolvedRunId
    GeneratedAt = (Get-Date).ToString('s')
    Results = $results
    Summary = $summary
  }

  $mdPath = Join-Path $outDir ("summary-{0}.md" -f $resolvedRunId)
  $md = @()
  $md += "# Hylab Summary"
  $md += ""
  $md += "RunId: $resolvedRunId"
  if ($modCount) { $md += "Mods: $modCount" }
  $md += "Pass: $pass  Fail: $fail  Timeout: $timeout  Skip: $skip"
  $md += "AvgDurationSec: $avg"
  $md += "P95DurationSec: $p95"
  if ($topFailure) { $md += "TopFailure: $topFailure" }
  $md += "ReportCsv: $reportOutCsv"
  $md | Set-Content -Path $mdPath -Encoding Ascii
  Copy-Item -Path $mdPath -Destination (Join-Path $outDir "summary.md") -Force

  if ($Csv) {
    $results | Export-Csv -Path $reportOutCsv -NoTypeInformation
    Copy-Item -Path $reportOutCsv -Destination (Join-Path $outDir "results.csv") -Force
  }

  if ($Json) {
    $jsonPath = Join-Path $outDir ("results-{0}.json" -f $resolvedRunId)
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding Ascii
    Copy-Item -Path $jsonPath -Destination (Join-Path $outDir "results.json") -Force
    Write-Host "Report JSON: $jsonPath"
  }

  if ($Junit) {
    $junitPath = Join-Path $outDir ("junit-{0}.xml" -f $resolvedRunId)
    Write-JUnit -Path $junitPath -RunId $resolvedRunId -Summary $summary -Results $results
    Copy-Item -Path $junitPath -Destination (Join-Path $outDir "junit.xml") -Force
    Write-Host "JUnit: $junitPath"
  }

  Write-Host "Report MD: $mdPath"
  if ($Json) {
    $metrics = [pscustomobject]@{
      SchemaVersion = '1.0.0'
      RunId = $resolvedRunId
      GeneratedAt = (Get-Date).ToString('s')
    Total = $total
    Pass = $pass
    Fail = $fail
    Timeout = $timeout
    Skip = $skip
      AvgDurationSec = $avg
      P95DurationSec = $p95
      TopFailure = $topFailure
      ModCount = $modCount
    }
    $metricsPath = Join-Path $outDir ("metrics-{0}.json" -f $resolvedRunId)
    $metrics | ConvertTo-Json -Depth 4 | Set-Content -Path $metricsPath -Encoding Ascii
    Copy-Item -Path $metricsPath -Destination (Join-Path $outDir "metrics.json") -Force
    Write-Host "Metrics: $metricsPath"
  }
}

switch ($Command) {
  'help' {
    Write-Host "Hylab" 
    Write-Host "Commands: scan | plan | boot | join | report | proofcheck | bisect | repro | scenario | deps | tune-memory" 
  }
  'scan' {
    $cfg = Load-Config -Path $ConfigPath
    Ensure-Dirs -cfg $cfg
    $mods = Get-ModFiles -cfg $cfg
    $excludes = Load-Excludes -cfg $cfg
    if ($excludes.Count -gt 0) { $mods = Filter-Mods -mods $mods -excludes $excludes }
    Write-ModList -mods $mods -cfg $cfg
  }
  'plan' {
    $cfg = Load-Config -Path $ConfigPath
    Ensure-Dirs -cfg $cfg
    $mods = Get-ModFiles -cfg $cfg
    $excludes = Load-Excludes -cfg $cfg
    if ($excludes.Count -gt 0) { $mods = Filter-Mods -mods $mods -excludes $excludes }
    $plan = New-PairwisePlan -mods $mods -cfg $cfg
    Write-Plan -plan $plan -cfg $cfg
  }
  'boot' {
    $cfg = Load-Config -Path $ConfigPath
    Ensure-Dirs -cfg $cfg
    $planPath = Join-Path $cfg.ReportsDir 'plan.json'
    if (-not (Test-Path $planPath)) {
      throw "plan.json not found. Run: .\modlab.ps1 plan"
    }
    $plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
    Run-BootTests -cfg $cfg -plan $plan -RunId $RunId -StartIndex $StartIndex -Count $Count -Limit $Limit
  }
  'join' {
    $cfg = Load-Config -Path $ConfigPath
    Ensure-Dirs -cfg $cfg
    $planPath = Join-Path $cfg.ReportsDir 'plan.json'
    if (-not (Test-Path $planPath)) {
      throw "plan.json not found. Run: .\modlab.ps1 plan"
    }
    $plan = Get-Content -Raw -Path $planPath | ConvertFrom-Json
    Run-JoinTests -cfg $cfg -plan $plan -RunId $RunId -StartIndex $StartIndex -Count $Count -Limit $Limit
  }
  'report' {
    $cfg = Load-Config -Path $ConfigPath
    Ensure-Dirs -cfg $cfg
    Write-Report -cfg $cfg -RunId $RunId -Out $Out -Json:$Json -Csv:$Csv -Junit:$Junit -Lane $Lane
  }
  'proofcheck' {
    $cfg = Load-Config -Path $ConfigPath
    Run-Proofcheck -cfg $cfg -Strict:$Strict
  }
  'bisect' {
    $cfg = Load-Config -Path $ConfigPath
    Run-Bisect -cfg $cfg -RunId $RunId -TestId $TestId -Status $BisectStatus
  }
  'repro' {
    $cfg = Load-Config -Path $ConfigPath
    Write-Repro -cfg $cfg -RunId $RunId -TestId $TestId -IncludeMods:$IncludeMods
  }
  'scenario' {
    $cfg = Load-Config -Path $ConfigPath
    Run-Scenario -cfg $cfg -ScenarioPath $ScenarioPath -RunId $RunId -TestId $TestId
  }
  'deps' {
    $cfg = Load-Config -Path $ConfigPath
    Run-DepScan -cfg $cfg
  }
  default {
    Write-Host "Not implemented yet: $Command" 
    exit 1
  }
}
