# Requires -Version 5.1
# Pester v5+

Describe "Remove-GhostNetAdapter" {
    BeforeAll {
        $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\RemoveGhostNetAdapter.psd1'
        Import-Module $modulePath -Force
    }

    It "Should import the function" {
        Get-Command Remove-GhostNetAdapter | Should -Not -BeNullOrEmpty
    }

    It "Should be an advanced function" {
        (Get-Command Remove-GhostNetAdapter).CmdletBinding | Should -Be $true
    }

    It "Should accept -UseAdvancedReset and -ExportLogPath parameters" {
        $params = (Get-Command Remove-GhostNetAdapter).Parameters.Keys
        $params | Should -Contain "UseAdvancedReset"
        $params | Should -Contain "ExportLogPath"
    }

    It "Should not throw on dry run" {
        { Remove-GhostNetAdapter -WhatIf } | Should -Not -Throw
    }

    It "Should fail gracefully with invalid ExportLogPath" {
        $invalidPath = "Z:\nonexistent\ghostlog.json"
        { Remove-GhostNetAdapter -ExportLogPath $invalidPath -WhatIf } | Should -Not -Throw
    }

    It "Should return no output by default" {
        $result = Remove-GhostNetAdapter -WhatIf
        $result | Should -BeNullOrEmpty
    }
}
