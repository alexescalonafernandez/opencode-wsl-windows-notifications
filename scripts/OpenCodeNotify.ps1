param(
    [string]$EventName,
    [string]$Message,
    [string]$ProjectName,
    [string]$SessionTitle,
    [string]$AgentName
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Import-Module BurntToast -Force

$title = if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    "OpenCode"
}
else {
    "OpenCode - $ProjectName"
}

$eventLabel = switch ($EventName) {
    "permission"        { "Permission required" }
    "question"          { "Question requires attention" }
    "complete"          { "Task completed" }
    "subagent_complete" { "Subagent completed" }
    "error"             { "Error" }
    "plan_exit"         { "Plan ready for review" }
    default             { $EventName }
}

if ($EventName -eq "subagent_complete" -and -not [string]::IsNullOrWhiteSpace($AgentName)) {
    if ([string]::IsNullOrWhiteSpace($SessionTitle)) {
        $detail = $AgentName
    }
    else {
        $detail = "$AgentName - $SessionTitle"
    }
}
elif ($EventName -eq "complete") {
    if (-not [string]::IsNullOrWhiteSpace($SessionTitle)) {
        $detail = $SessionTitle
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Message)) {
        $detail = $Message
    }
    else {
        $detail = "OpenCode task finished"
    }
}
else {
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        $detail = $Message
    }
    elseif (-not [string]::IsNullOrWhiteSpace($SessionTitle)) {
        $detail = $SessionTitle
    }
    else {
        $detail = "OpenCode requires attention"
    }
}

New-BurntToastNotification -Text $title, $eventLabel, $detail
