$script:DSCModuleName      = 'xRemoteDesktopSessionHost'
$script:DSCResourceName    = 'MSFT_xRDSessionCollection'

function Invoke-TestSetup
{
    try
    {
        Import-Module -Name DscResource.Test -Force
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Unit'
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

try
{
    InModuleScope $script:dscResourceName {
        $script:DSCResourceName    = 'MSFT_xRDSessionCollection'

        $testInvalidCollectionName = 'InvalidCollectionNameLongerThan256-12345678910111213141516171819202122232425262728142124124124awffjwifhw28qfhw27[q9aqfj2wai9fua29fua2fna29fja2fj29f2u192u4-[12fj2390fau2-9fu-9fu1-2ur1-2u149u2mfaweifjwifjw19wu-u2394u12-f2u1223fu-1f1239fy193413403mgjefas902311'
        $testcollectionName = 'TestCollection'
        $testcollectionNameMulti = 'TestCollectionMulti'

        $testSessionHost = 'localhost'
        $testSessionHostMulti = 'rdsh1','rdsh2','rdsh3'
        $invalidSessionHostMulti = 'rds1','rds2','rds3'
        $testConnectionBroker = 'localhost.fqdn'

        $validTargetResourceCall = @{
            CollectionName   = $testCollection[0].Name
            SessionHost      = $testSessionHost
            ConnectionBroker = $testConnectionBroker
        }

        $nonExistentTargetResourceCall1 = @{
            CollectionName   = 'TestCollection4'
            SessionHost      = $testSessionHost
            ConnectionBroker = $testConnectionBroker
        }

        $nonExistentTargetResourceCall2 = @{
            CollectionName   = 'TestCollection5'
            SessionHost      = $testSessionHost
            ConnectionBroker = $testConnectionBroker
        }
        $validMultiTargetResourceCall = @{
            CollectionName = $testcollectionNameMulti
            SessionHost = $testSessionHostMulti
            ConnectionBroker = $testConnectionBroker
        }
        $invalidMultiTargetResourceCall = @{
            CollectionName = $testcollectionNameMulti
            SessionHost = $testSessionHostMulti | Select-Object -Skip 1
            ConnectionBroker = $testConnectionBroker
        }

        Import-Module RemoteDesktop -Force

        #region Function Get-TargetResource
        Describe "$($script:DSCResourceName)\Get-TargetResource" {
            Mock -CommandName Get-RDSessionCollection {
                return @(
                    {
                        CollectionName = $testCollectionName
                        CollectionDescription = 'Test Collection'
                        SessionHost = $testSessionHost
                        ConnectionBroker = $testConnectionBroker
                    },
                    {
                        CollectionName = $testCollectionName2
                        CollectionDescription = 'Test Collection 2'
                        SessionHost = $testSessionHost
                        ConnectionBroker = $testConnectionBroker
                    }
                )
            }
            Mock -CommandName Get-RDSessionHost {
                return @{
                    CollectionName = $testCollectionName
                    SessionHost = $testSessionHost
                }
                return @{
                    CollectionName = $testCollectionNameMulti
                    SessionHost = $testSessionHostMulti
                }
            }

            Context "Parameter Values,Validations and Errors" {

                It "Should error when CollectionName length is greater than 256" {
                    {Get-TargetResource -CollectionName $testInvalidCollectionName -SessionHost $testSessionHost} | Should throw
                }

                Mock -CommandName Get-RDSessionCollection {
                    $result = @()

                    foreach ($sessionCollection in $testCollection)
                    {
                        $result += New-Object -TypeName PSObject -Property @{
                            CollectionName        = $sessionCollection.Name
                            CollectionDescription = $sessionCollection.Description
                            SessionHost           = $testSessionHost
                            ConnectionBroker      = $testConnectionBroker
                        }
                    }

                    return $result
                }

                It 'Calls Get-RDSessionCollection with CollectionName and ConnectionBroker parameters' {
                    Get-TargetResource @validTargetResourceCall
                    Assert-MockCalled -CommandName Get-RDSessionCollection -Times 1 -Scope It -ParameterFilter {
                        $CollectionName -eq $testCollection[0].Name -and
                        $ConnectionBroker -eq $testConnectionBroker
                    }
                }

                It 'Calls Get-RDSessionHost' {
                    Get-TargetResource @validTargetResourceCall
                    Assert-MockCalled -CommandName Get-RDSessionHost -Times 1 -Scope It -ParameterFilter {
                        $CollectionName -eq $testCollectionName -and
                        $ConnectionBroker -eq $testConnectionBroker
                    }
                }
            }

            Context "Non-existent Session Collection requested (other session collections returned - Win2019 behaviour)" {

                Mock -CommandName Get-RDSessionCollection -MockWith {
                    [pscustomobject]@{
                        CollectionName        = 'TestCollection3'
                        CollectionDescription = 'Test Collection 3'
                        SessionHost           = $testSessionHost
                        ConnectionBroker      = $testConnectionBroker
                    }
                }

                $result = Get-TargetResource @nonExistentTargetResourceCall1
                It "Should return return a hash table" {
                    $result | Should -BeOfType System.Collections.Hashtable
                }

                It 'Should return supplied session host, with other values being $null' {
                    $result.ConnectionBroker      = $null
                    $result.CollectionName        = $null
                    $result.CollectionDescription = $null
                    $result.SessionHost           = $testSessionHost
                }
            }

            Context "Non-existent Session Collection requested (no session collections returned - normal behaviour)" {

                Mock -CommandName Get-RDSessionCollection {
                    return $null
                }

                $result = Get-TargetResource @nonExistentTargetResourceCall2
                It "Should return return a hash table (Win 2019)" {
                    $result | Should -BeOfType System.Collections.Hashtable
                }

                It 'Should return supplied session host, with other values being $null' {
                    $result.ConnectionBroker      = $null
                    $result.CollectionName        = $null
                    $result.CollectionDescription = $null
                    $result.SessionHost           = $testSessionHost
                }
            }


            Context "Two Session Collections exist with same CollectionName" {
                Mock -CommandName Get-RDSessionCollection {
                    $result = @()

                    foreach ($sessionCollection in $testCollection)
                    {
                        $result += New-Object -TypeName PSObject -Property @{
                            CollectionName        = $testCollection[0].Name
                            CollectionDescription = $sessionCollection.Description
                            SessionHost           = $testSessionHost
                            ConnectionBroker      = $testConnectionBroker
                        }
                    }

                    return $result
                }

                It "should throw exception" {
                    { Get-TargetResource @validTargetResourceCall } | Should throw
                }
            }

        }
        #endregion

        #region Function Set-TargetResource
        Describe "$($script:DSCResourceName)\Set-TargetResource" {

            Context "Parameter Values,Validations and Errors" {

                It "Should error when CollectionName length is greater than 256" {
                    {Set-TargetResource -CollectionName $testInvalidCollectionName -SessionHost $testSessionHost} | Should throw
                }
            }

            Mock -CommandName Get-RDSessionCollection -MockWith {
                return [PSCustomObject]@{
                    CollectionName        = $testCollection[0].Name
                    CollectionDescription = 'Test Collection'
                    SessionHost           = $testSessionHost
                    ConnectionBroker      = $testConnectionBroker
                }
            }

            Mock -CommandName New-RDSessionCollection

            Context 'Validate Set-TargetResource actions' {
                It 'Given the configuration is applied, New-RDSessionCollection and Get-RDSessionCollection are called' {
                    Set-TargetResource -CollectionName $testCollection[0].Name -ConnectionBroker $testConnectionBroker -SessionHost $testSessionHost
                    Assert-MockCalled -CommandName New-RDSessionCollection -Times 1 -Scope Context
                    Assert-MockCalled -CommandName Get-RDSessionCollection -Times 1 -Scope Describe
                }
            }

            Context 'Get-RDSessionCollection returns no RDSessionCollection after calling New-RDSessionCollection with no exception' {
                Mock -CommandName Get-RDSessionCollection -MockWith {
                    $null
                }

                $exceptionMessage = ( '''Test-TargetResource'' returns false after call to ''New-RDSessionCollection''; CollectionName: {0}; ConnectionBroker {1}.' -f $testCollection[0].Name,$testConnectionBroker )

                It 'throws an exception' {
                    {
                        Set-TargetResource -CollectionName $testCollection[0].Name -ConnectionBroker $testConnectionBroker -SessionHost $testSessionHost
                    } | should throw $exceptionMessage
                }

                It 'calls New-RDSessionCollection and Get-RDSessionCollection' {
                    Assert-MockCalled -CommandName New-RDSessionCollection -Times 1 -Scope Context
                    Assert-MockCalled -CommandName Get-RDSessionCollection -Times 1 -Scope Describe
                }
            }

            Context 'Get-RDSessionCollection returns an exception, but creates the desired RDSessionCollection' {
                Mock -CommandName New-RDSessionCollection -MockWith {
                    throw [Microsoft.PowerShell.Commands.WriteErrorException] 'The property EncryptionLevel is configured by using Group Policy settings. Use the Group Policy Management Console to configure this property.'
                }

                It 'does not return an exception' {
                    { Set-TargetResource -CollectionName $testCollection[0].Name -ConnectionBroker $testConnectionBroker -SessionHost $testSessionHost } | Should -Not -Throw
                }

                It 'calls New-RDSessionCollection and Get-RDSessionCollection' {
                    Assert-MockCalled -CommandName New-RDSessionCollection -Times 1 -Scope Context
                    Assert-MockCalled -CommandName Get-RDSessionCollection -Times 1 -Scope Describe
                }
            }

            Context 'Get-RDSessionCollection returns an exception, without creating the desired RDSessionCollection' {
                Mock -CommandName New-RDSessionCollection -MockWith {
                    throw [Microsoft.PowerShell.Commands.WriteErrorException] "A Remote Desktop Services deployment does not exist on $testConnectionBroker. This operation can be performed after creating a deployment. For information about creating a deployment, run `"Get-Help New-RDVirtualDesktopDeployment`" or `"Get-Help New-RDSessionDeployment`""
                }

                Mock -CommandName Get-RDSessionCollection -MockWith {
                    $null
                }

                It 'returns an exception' {
                    { Set-TargetResource -CollectionName $testCollection[0].Name -ConnectionBroker $testConnectionBroker -SessionHost $testSessionHost } | Should -Throw
                }

                It 'calls New-RDSessionCollection and Get-RDSessionCollection' {
                    Assert-MockCalled -CommandName New-RDSessionCollection -Times 1 -Scope Context
                    Assert-MockCalled -CommandName Get-RDSessionCollection -Times 1 -Scope Describe
                }
            }
        }
        #endregion

        #region Function Test-TargetResource
        Describe "$($script:DSCResourceName)\Test-TargetResource" {
            Context "Parameter Values,Validations and Errors" {

                It "Should error when CollectionName length is greater than 256" {
                    {Test-TargetResource -CollectionName $testInvalidCollectionName -SessionHost $testSessionHost} | Should throw
                }
            }

            Context 'Validating Test-TargetResource output' {
                Mock -CommandName Get-RDSessionCollection
                Mock -CommandName Get-RDSessionHost

                It 'Given Get-RDSessionCollection not returning a collection, test returns false' {
                    Test-TargetResource @validTargetResourceCall | Should Be $false
                }

                Mock -CommandName Get-RDSessionCollection -MockWith {
                    [pscustomobject]@{
                        AutoAssignPersonalDesktop    = $false
                        CollectionAlias              = $testCollection[0].Name
                        CollectionDescription        = 'Pester Test Collection Output'
                        CollectionName               = $testCollection[0].Name
                        CollectionType               = 'PooledUnmanaged'
                        GrantAdministrativePrivilege = $false
                        ResourceType                 = 'Remote Desktop'
                        Size                         = 1
                    }
                }
                Mock -CommandName Get-RDSessionHost {
                    return @{
                        CollectionName = $testCollectionName
                        SessionHost = $testSessionHost
                    }
                    return @{
                        CollectionName = $testCollectionNameMulti
                        SessionHost = $testSessionHostMulti
                    }
                }

                It 'Given Get-RDSessionCollection returning a collection, test returns true' {
                    Test-TargetResource @validTargetResourceCall | Should Be $true
                }

                Mock -CommandName Get-RDSessionHost {
                    return @{
                        CollectionName = $testCollectionName
                        SessionHost = $testSessionHost
                    }
                    return @{
                        CollectionName = $testCollectionNameMulti
                        SessionHost = $testSessionHostMulti
                    }
                }

                It 'Given the incorrect number of session hosts it should return false' {
                    Test-TargetResource @invalidMultiTargetResourceCall | Should Be $false
                }

                Mock -CommandName Get-RDSessionHost {
                    return @{
                        CollectionName = $testCollectionName
                        SessionHost = $testSessionHost
                    }
                    return @{
                        CollectionName = $testCollectionNameMulti
                        SessionHost = $invalidTestSessionHostMulti
                    }
                }

                It 'Given the list of session hosts is not equal, return false' {
                    Test-TargetResource @validMultiTargetResourceCall | Should Be $false
                }
            }
        }
        #endregion
    }
}
finally
{
    Invoke-TestCleanup
}
