function Invoke-AgentDispatch {
    <#
    .SYNOPSIS
        Routes a prompt to the correct private agent invoker based on agent type.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AIAgent] $Agent,

        [Parameter(Mandatory)]
        [string] $Prompt,

        [hashtable] $Parameters = @{}
    )

    switch ($Agent.Type) {
        ([AIAgentType]::Claude)  { return Invoke-ClaudeAgent  -Agent $Agent -Prompt $Prompt -Parameters $Parameters }
        ([AIAgentType]::Gemini)  { return Invoke-GeminiAgent  -Agent $Agent -Prompt $Prompt -Parameters $Parameters }
        ([AIAgentType]::Copilot) { return Invoke-CopilotAgent -Agent $Agent -Prompt $Prompt -Parameters $Parameters }
        ([AIAgentType]::Codex)   { return Invoke-CodexAgent   -Agent $Agent -Prompt $Prompt -Parameters $Parameters }
        ([AIAgentType]::Custom)  { return Invoke-CustomAgent  -Agent $Agent -Prompt $Prompt -Parameters $Parameters }
        default {
            throw "Unsupported agent type: $($Agent.Type)"
        }
    }
}
