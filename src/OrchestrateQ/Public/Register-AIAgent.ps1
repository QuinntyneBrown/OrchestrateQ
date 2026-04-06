function Register-AIAgent {
    <#
    .SYNOPSIS
        Registers an AI agent with OrchestrateQ.

    .DESCRIPTION
        Stores the agent configuration in the module-scoped agent registry so it can
        be referenced by name in workflows and direct Invoke-AIAgent calls.

    .PARAMETER Name
        A unique display name for this agent (e.g. "Claude", "MyGemini").

    .PARAMETER Type
        The agent family: Claude | Gemini | Copilot | Codex | Custom.

    .PARAMETER ExecutablePath
        Path to (or name of) the CLI executable.  When omitted, the default
        CLI command for the agent type is used.

    .PARAMETER DefaultParameters
        A hashtable of parameters always passed to the agent (merged with per-call
        parameters; per-call values take precedence).

    .PARAMETER Force
        Overwrite an existing agent registration with the same name.

    .EXAMPLE
        Register-AIAgent -Name "Claude" -Type Claude

    .EXAMPLE
        Register-AIAgent -Name "MyGemini" -Type Gemini `
            -ExecutablePath "gemini" `
            -DefaultParameters @{ model = "gemini-pro" }

    .EXAMPLE
        Register-AIAgent -Name "CodeBot" -Type Custom `
            -ExecutablePath "C:\Tools\mybot.exe"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('AIAgent')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [AIAgentType] $Type,

        [Parameter()]
        [string] $ExecutablePath,

        [Parameter()]
        [hashtable] $DefaultParameters = @{},

        [Parameter()]
        [switch] $Force
    )

    if ($script:AgentRegistry.ContainsKey($Name) -and -not $Force) {
        throw "An agent named '$Name' is already registered.  Use -Force to overwrite."
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Register AI Agent')) {
        $agent                    = [AIAgent]::new($Name, $Type)
        $agent.ExecutablePath     = $ExecutablePath
        $agent.DefaultParameters  = $DefaultParameters

        # Test availability: check if the executable can be found
        $exeName = if ($ExecutablePath) { $ExecutablePath } else {
            switch ($Type) {
                ([AIAgentType]::Claude)  { 'claude' }
                ([AIAgentType]::Gemini)  { 'gemini' }
                ([AIAgentType]::Copilot) { 'gh' }
                ([AIAgentType]::Codex)   { 'codex' }
                default                  { $null }
            }
        }

        if ($exeName) {
            $agent.IsAvailable = [bool](Get-Command $exeName -ErrorAction SilentlyContinue)
        }

        $script:AgentRegistry[$Name] = $agent

        Write-OrchestrateQLog "Registered agent '$Name' (Type=$Type, Available=$($agent.IsAvailable))"
        return $agent
    }
}
