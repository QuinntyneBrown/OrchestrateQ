function Resolve-PromptTemplate {
    <#
    .SYNOPSIS
        Replaces {Variable} tokens in a prompt template.

    .DESCRIPTION
        Tokens recognised:
          {Input}                - the workflow input string
          {PreviousOutput}       - the output of the last completed step
          {StepName.Output}      - the output of a named step
          {Variable.Name}        - a workflow-level variable
          {Env.VAR_NAME}         - an environment variable

    .EXAMPLE
        Resolve-PromptTemplate -Template "Review: {Input}" -Context @{ Input = "code..." }
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Template,

        [Parameter(Mandatory)]
        [hashtable] $Context
    )

    $result = $Template

    # Replace all {Key} tokens from Context
    foreach ($key in $Context.Keys) {
        $value  = $Context[$key]
        $result = $result -replace [regex]::Escape("{$key}"), $value
    }

    # Replace {Env.VAR_NAME} tokens
    $result = [regex]::Replace($result, '\{Env\.([^}]+)\}', {
        param($match)
        $envVar = $match.Groups[1].Value
        $val    = [System.Environment]::GetEnvironmentVariable($envVar)
        if ($null -ne $val) { $val } else { $match.Value }
    })

    return $result
}
