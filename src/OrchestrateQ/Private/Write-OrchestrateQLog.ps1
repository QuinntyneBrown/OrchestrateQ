function Write-OrchestrateQLog {
    <#
    .SYNOPSIS
        Internal logging helper for OrchestrateQ.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string] $Level = 'INFO',

        [string] $LogPath
    )

    $timestamp  = [datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss.fff')
    $entry      = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'ERROR' { Write-Error   $Message -ErrorAction Continue }
        'WARN'  { Write-Warning $Message }
        'DEBUG' { Write-Debug   $entry }
        default { Write-Verbose $entry }
    }

    if ($LogPath) {
        try {
            $entry | Out-File -FilePath $LogPath -Append -Encoding utf8
        }
        catch {
            Write-Warning "OrchestrateQ: could not write to log file '$LogPath': $_"
        }
    }
}
