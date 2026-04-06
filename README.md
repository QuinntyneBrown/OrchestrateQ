# OrchestrateQ

A PowerShell module for orchestrating AI Agents and building reusable workflows on Windows (and cross-platform PowerShell 5.1+).

> **Supported agents out of the box:** Claude CLI · Gemini CLI · GitHub Copilot CLI (`gh`) · OpenAI Codex CLI · Any custom executable

---

## Features

- 🤖 **Register & manage AI agents** — Claude, Gemini, Copilot, Codex, or any custom executable  
- 🔗 **Define multi-step workflows** — sequential and parallel execution  
- 🧩 **Template engine** — `{Input}`, `{PreviousOutput}`, `{StepName.Output}`, workflow variables, and env vars  
- ♻️ **Retry logic** — configurable per-step retry count with back-off  
- ⏱️ **Timeout support** — per-step timeout for parallel background jobs  
- 📋 **Lifecycle hooks** — `OnSuccess` / `OnFailure` scriptblocks per step  
- 💾 **Portable workflows** — `Export-Workflow` / `Import-Workflow` via JSON  
- 🧪 **Fully tested** — 43 Pester tests included  

---

## Quick Start

### 1. Import the module

```powershell
Import-Module .\src\OrchestrateQ\OrchestrateQ.psd1
```

### 2. Register an AI agent

```powershell
# Claude CLI (requires 'claude' on PATH)
Register-AIAgent -Name "Claude" -Type Claude

# Gemini CLI with a model override
Register-AIAgent -Name "Gemini" -Type Gemini `
    -DefaultParameters @{ model = "gemini-pro" }

# GitHub Copilot (requires 'gh' on PATH and gh copilot extension)
Register-AIAgent -Name "Copilot" -Type Copilot

# OpenAI Codex
Register-AIAgent -Name "Codex" -Type Codex

# Any custom executable
Register-AIAgent -Name "MyBot" -Type Custom -ExecutablePath "C:\Tools\mybot.exe"
```

### 3. Invoke an agent directly

```powershell
$response = Invoke-AIAgent -Name "Claude" -Prompt "Write a hello world in Python"
Write-Host $response

# One-shot without pre-registering
$response = Invoke-AIAgent -Type Gemini -Prompt "Explain quantum computing in one sentence"
```

### 4. Build a workflow

```powershell
# Create the workflow
$wf = New-Workflow -Name "CodeReview" `
    -Description "Analyze code, suggest improvements, write summary" `
    -Variables @{ Language = "Python" }

# Register agents (if not already done)
Register-AIAgent -Name "Reviewer"  -Type Claude
Register-AIAgent -Name "Suggester" -Type Gemini

# Add sequential steps
$wf | Add-WorkflowStep -Name "Analyze" `
    -AgentName "Reviewer" `
    -PromptTemplate "Analyze this {Language} code for bugs and style issues:`n{Input}"

$wf | Add-WorkflowStep -Name "Suggest" `
    -AgentName "Suggester" `
    -PromptTemplate "Based on this analysis:`n{Analyze.Output}`n`nSuggest specific code improvements."

$wf | Add-WorkflowStep -Name "Summary" `
    -AgentName "Reviewer" `
    -PromptTemplate "Write a concise summary combining:`nAnalysis: {Analyze.Output}`nSuggestions: {Suggest.Output}"
```

### 5. Run the workflow

```powershell
$code = Get-Content ".\myfile.py" -Raw

# Returns the final step's output
$output = Invoke-Workflow -Name "CodeReview" -Input $code
Write-Host $output

# Or get the full result including per-step details
$result = Invoke-Workflow -Name "CodeReview" -Input $code -PassThru
$result.StepResults | Format-Table StepName, Success, Duration
```

---

## Template Tokens

Inside a step's `-PromptTemplate`, the following tokens are substituted at run time:

| Token | Replaced with |
|-------|---------------|
| `{Input}` | The string passed to `Invoke-Workflow -Input` |
| `{PreviousOutput}` | The output of the most-recently completed step |
| `{StepName.Output}` | The output of the named step (e.g. `{Analyze.Output}`) |
| `{VariableName}` | A workflow-level or call-time variable |
| `{Env.VAR_NAME}` | An environment variable (e.g. `{Env.OPENAI_API_KEY}`) |

---

## Parallel Steps

Mark steps as parallel to run them concurrently:

```powershell
$wf | Add-WorkflowStep -Name "ReviewSecurity" -AgentName "Claude" `
    -PromptTemplate "Find security issues in:{Input}" -Parallel

$wf | Add-WorkflowStep -Name "ReviewPerf" -AgentName "Gemini" `
    -PromptTemplate "Find performance issues in:{Input}" -Parallel

# Sequential step runs after both parallel steps complete
$wf | Add-WorkflowStep -Name "Merge" -AgentName "Claude" `
    -PromptTemplate "Merge findings:`nSecurity: {ReviewSecurity.Output}`nPerf: {ReviewPerf.Output}"
```

---

## Retry and Timeout

```powershell
$wf | Add-WorkflowStep -Name "FetchData" `
    -AgentName "Codex" `
    -PromptTemplate "Fetch and summarize: {Input}" `
    -MaxRetries 3 `        # retry up to 3 times on failure
    -TimeoutSeconds 60     # give up after 60 s (parallel steps only)
```

---

## Lifecycle Hooks

```powershell
$wf | Add-WorkflowStep -Name "Generate" -AgentName "Claude" `
    -PromptTemplate "Generate code for: {Input}" `
    -OnSuccess { param($r) Write-Host "✅ Generated in $($r.Duration.TotalSeconds)s" } `
    -OnFailure { param($r) Write-Warning "❌ Generation failed: $($r.Error)" }
```

---

## Export and Import Workflows

Save a workflow to JSON and reload it in another session:

```powershell
# Export
Export-Workflow -Name "CodeReview" -Path ".\workflows\CodeReview.json"

# Import (in a new session)
Import-Workflow -Path ".\workflows\CodeReview.json"
Invoke-Workflow -Name "CodeReview" -Input $code
```

---

## All Cmdlets

| Cmdlet | Description |
|--------|-------------|
| `Register-AIAgent` | Register an AI agent |
| `Get-AIAgent` | List registered agents |
| `Remove-AIAgent` | Remove an agent |
| `Invoke-AIAgent` | Send a prompt directly to an agent |
| `New-Workflow` | Create a workflow |
| `Add-WorkflowStep` | Add a step to a workflow |
| `Get-Workflow` | List workflows |
| `Remove-Workflow` | Remove a workflow |
| `Invoke-Workflow` | Execute a workflow |
| `Export-Workflow` | Save a workflow to JSON |
| `Import-Workflow` | Load a workflow from JSON |

Use `Get-Help <CmdletName> -Full` for detailed help on any cmdlet.

---

## Running Tests

```powershell
Invoke-Pester -Path .\tests\OrchestrateQ.Tests.ps1 -Output Detailed
```

---

## Requirements

- **PowerShell** 5.1 or later (Windows PowerShell or PowerShell Core)
- **Pester** 5.x (for tests only)
- One or more AI agent CLIs installed and on `PATH`
