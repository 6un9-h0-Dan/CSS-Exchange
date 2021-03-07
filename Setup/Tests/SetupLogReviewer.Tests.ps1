[CmdletBinding()]
param()

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$parent = $here.Replace("\Tests", "")
. "$parent\$sut" -PesterLoad

Write-Host ("running in pester test")

$sr = "$parent\$sut"

Write-Host "Script $sr"

Describe "Testing SetupLogReviewer" {

    Context "Prerequisite Checks" {
        Mock Write-Host {}
        Mock Write-Warning {}
        It "Additional Context" {
            $results = & $sr -SetupLog "$here\PrerequisiteCheck\ExchangeSetup_Fail_In_Child.log"
            $results.Contains("User Logged On: CHILD\Kylo") | Should be true
            $results.Contains("Setup Running on: Solo-E16A.Child.Solo.net") | Should be true
            $results.Contains("Setup Running in Domain: Child") | Should be true
            $results.Contains("Setup Running in AD Site Name: Default-First-Site-Name") | Should be true
            $results.Contains("Schema Master: Solo-DC1.Solo.net") | Should be true
            $results.Contains("Schema Master in Domain: Solo") | Should be true
        }
        It "Prepare AD Failed" {
            & $sr -SetupLog "$here\PrerequisiteCheck\ExchangeSetup_Fail_In_Child.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -Scope It `
                -ParameterFilter { $Object -eq "Unable to run setup in current domain." -and $ForegroundColor -eq "Red" }
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -Scope It `
                -ParameterFilter { $Object -like "*Run setup with the /prepareAD parameter on a computer in the domain Solo and site Default-First-Site-Name, and wait for replication to complete.*" }
        }

        It "No ORG Man" {
            & $sr -SetupLog "$here\PrerequisiteCheck\ExchangeSetup_ADUpdated_NoOrgMan.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -Scope It `
                -ParameterFilter { $Object -eq "User SOLO\Kylo isn't apart of Organization Management group." -and $ForegroundColor -eq "Red" }
        }

        It "Schema Admins group" {
            & $sr -SetupLog "$here\PrerequisiteCheck\ExchangeSetup_NoPerm.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $Object -eq "/PrepareSchema is required and user SOLO\Kylo isn't apart of the Schema Admins group." -and $ForegroundColor -eq "Red" }
        }

        It "Reboot Pending" {
            & $sr -SetupLog "$here\PrerequisiteCheck\ExchangeSetup_Reboot_Pending.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $Object -eq "Computer is pending reboot based off the Windows Component is the registry" -and $ForegroundColor -eq "Red" }
        }

        It "Enterprise Admins Group" {
            & $sr -SetupLog "$here\PrerequisiteCheck\ExchangeSetup_SchemaAdmin_PrepareSchema.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $Object -eq "/PrepareSchema is required and user SOLO\Kylo isn't apart of the Enterprise Admins group." -and $ForegroundColor -eq "Red" }
        }
    }

    Context "Known Issues" {
        Mock Write-Host {}
        Mock Write-Warning {}
        It "MESG was deleted" {
            & $sr -SetupLog "$here\KnownIssues\ExchangeSetupmsExchangeSecurityGroupsContainerDeleted.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $Object -like "*'OU=Microsoft Exchange Security Groups' was deleted from the root of the domain. We need to have it created again at the root of the domain to continue." }
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $Object -like "*System.NullReferenceException*" -and $ForegroundColor -eq "Yellow" }
        }

        It "Failed to import schema" {
            & $sr -SetupLog "$here\KnownIssues\ExchangeSetup-PrepareSchema-8245.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $Object -like "*Failed to import schema setting from file 'C:\Windows\Temp\ExchangeSetup\Setup\Data\PostExchange2003_schema80.ldf'*" }
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $Object -like "*If you can't find the ldf file in the C:\Windows\Temp location, then find the file in the ISO*" }
        }

        It "Wrong Group Type" {
            & $sr -SetupLog "$here\KnownIssues\ExchangeSetupWrongGroupType.log"
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $object -like "*Change the CN=Exchange Servers,OU=Test,DC=Solo,DC=local object to Universal, SecurityEnabled" }
            Assert-MockCalled -Exactly 1 -CommandName Write-Host `
                -ParameterFilter { $object -like "*The well-known object entry with the GUID `"6c01d2a7-f083-4503-8132-789eeb127b84`"*" -and $ForegroundColor -eq "Yellow" }
        }
    }
}