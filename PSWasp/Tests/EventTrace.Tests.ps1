Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

$TestDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RootModuleDir = Resolve-Path "$TestDir\.."
$Module = "$RootModuleDir\EventTrace.psd1"



Import-Module $Module -Force -ErrorAction Stop

# Global session name
$SessName = "PesterETWSession"
# Global output file
$OutputFile = Join-Path (Resolve-Path .) "etw_session.etl"
# Global provider
$ProviderName = "Microsoft-Windows-Kernel-Process"

Describe 'New-ETWProviderConfig' {
    Context 'output validation' {
        It 'Should return PS object' {
            (New-ETWProviderConfig).PSObject.TypeNames[1] | Should Be 'System.Object'
        }

        It 'Should contain 3 properties' {
            New-ETWProviderConfig | Get-Member | Where-Object {$_.MemberType -eq 'NoteProperty' }  | `
                Measure-Object | Select-Object -ExpandProperty count | Should be 4
        }
    }
}

Describe 'ConvertTo-ETWGuid' {
    Context 'input validation' {
        It 'Should should accept string input' {
            { ConvertTo-ETWGuid -ProviderName $ProviderName } | Should Not Throw
        }

        It "Should error on non-existent provider" {
            { ConvertTo-ETWGuid -ProviderName "DOES NOT EXIST" } | Should Throw
        }

        It 'Should generate errors when required parameters are not provided' {
            { ConvertTo-ETWGuid -ProviderName } | Should Throw
        }
    }

    Context 'output validation' {
        It 'Should return type GUID' {
            { ConvertTo-ETWGuid -ProviderName $ProviderName -is [System.Guid] } | Should Be $true
        }
    }
}

Describe 'Get-ETWProviderKeywords' {
    Context 'input validation' {
        It 'Should require input' {
            { Get-ETWProviderKeywords -Provider } | Should Throw
        }

        It 'Should accept string input' {
            { Get-ETWProviderKeywords -Provider $ProviderName }
        }

        It "Should error on non-existent provider" {
            { Get-ETWProviderKeywords -ProviderName "DOES NOT EXIST" } | Should Throw
        }
    }
    Context 'output validation'{
        It 'Should return properly formatted ProviderDataItem objects' {
            $Result = Get-ETWProviderKeywords -Provider $ProviderName

            $Result[0].PSObject.TypeNames[0] | Should be 'Microsoft.Diagnostics.Tracing.Session.ProviderDataItem'
        }
    }
}

Describe 'New-ETWProviderOption' {
    Context 'output validation' {
        It 'Should return provider options object' {
            (New-ETWProviderOption).PSObject.TypeNames[0] | Should be 'Microsoft.Diagnostics.Tracing.Session.TraceEventProviderOptions'
        }
    }
}

Describe 'Get-ETWProvider' {
    Context 'output validation' {
        It 'Should generate output'{ 
            { Get-ETWProvider } | Should Not BeNullOrEmpty
        }
        It 'Should return properly formatted ProviderMetadata objects' {
            $Result = Get-ETWProvider

            $Result[0].PSObject.TypeNames[0] | Should be 'System.Diagnostics.Eventing.Reader.ProviderMetadata'
        }
    }
}

Describe 'Get-ETWSessionDetails' {
    Context 'input validation' {
        It 'Should require input' {
            { Get-ETWSessionDetails -SessionName } | Should Throw
        }

        It 'Should error when invalid name provided' {
            { Get-ETWSessionDetails -SessionName "not valid" } | Should Throw "Session does not exist"
        }
    }

    Context 'output validation' {
        It 'Should return TraceEventSessionObject' {
            $SessionName = (Get-ETWSessionNames)[0]
            
            $Result = Get-ETWSessionDetails -SessionName $SessionName
            $Result[0].PSObject.TypeNames[0] | Should be 'Microsoft.Diagnostics.Tracing.Session.TraceEventSession'
        }
    }
}


Describe 'Start-ETWSession' {
    $ProviderConfig = New-ETWProviderConfig
    $ProviderConfig.Name = $ProviderName
    $ProviderConfig.Keywords = Get-ETWProviderKeywords -Provider $ProviderName | Where-Object {
        $_.Name -match "_process$|_image$|_thread$" }

    Context 'input validation' {
        It 'Should generate errors when required params are not provided' {
            { Start-ETWSession  -SessionConfig -SessionName -OutputFile } | Should Throw 
        }
        InModuleScope EventTrace{
            It 'Should fail to run if session already exists' {
                Mock Test-IsSession { return $true }

                { Start-ETWSession -ProviderConfig $null -OutputFile $OutputFile -SessionName $SessName } `
                    | Should Throw

            }
        }

        It 'Output file should not exist' {
            Test-Path $OutputFile | Should be $false
        }
    }

    Context 'output validation' {
        It 'Should create ETW session' {
            (Start-ETWSession -SessionName $SessName -OutputFile $OutputFile -ProviderConfig $ProviderConfig)[1]  | Should be $true
        }

        # sleep for 2 seconds to verify file is created and events generated
        Start-Sleep -Seconds 2

        It 'Should create etl output file' {
            Test-Path $OutputFile | Should Be $true   
        }
    }
}

Describe 'Stop-ETWSession' {
    Context 'input validation' {
        It 'Should generate an error when a non-existent session is provided' {
            { Stop-ETWSession -SessionName "does not exist" } | Should Throw
        }
    }
    
    Context "output validation" {
        It 'Should stop session' {
            (Stop-ETWSession -SessionName $SessName)[1] | Should be $true
        }

        # size of blank etl file is 64 KB
        It 'Output file should exist and be larger than 64 KB' {
           (Get-ChildItem $OutputFile).Length / 1Kb | Should BeGreaterThan 64
        } 
   }

}

Describe 'Get-ETWEventLog' {
    Context 'input validation' {
        It 'Should error when required parameter not provided' {
            { Get-ETWEventLog -Path } | Should Throw
        }
    }

    # Context 'output validation' {
        # It 'Should properly parse output' {
            # (Get-ETWEventLog -Path $OutputFile).Count | Should BeGreaterThan 1 
        # }
    # }
}


Describe 'Cleanup tests' {
    Context 'Remove module' {
        It 'Should not throw error removing module' {
            { Remove-Module 'EventTrace' } | Should Not Throw
        }
    }
    Context 'Delete test etl file' {
        It 'Should delete output file' {
           { Remove-Item $OutputFile -Force } | Should Not Throw
        }

        It 'Output file should not exist' {
            Test-Path $OutputFile  | Should be $false
        }
    }
}

