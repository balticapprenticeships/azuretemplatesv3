################################################################
# Script to configure Windows lab environment using DSC        #
# Author: Chris Langford                                       #
# Version: 1.0.1                                               #
################################################################

Configuration xBaLabSecPlusServerCfg {
    [CmdletBinding()]

    Param (
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    $features = @("Hyper-V", "RSAT-Hyper-V-Tools", "Hyper-V-Tools", "Hyper-V-PowerShell")

    Node localhost {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        # This resource block create a local user
        xUser "CreateUserAccount" {
            Ensure = "Present"
            UserName = Split-Path -Path $Credential.UserName -Leaf
            Password = $Credential
            FullName = "Baltic Apprentice"
            Description = "Baltic Apprentice"
            PasswordNeverExpires = $true
            PasswordChangeRequired = $false
            PasswordChangeNotAllowed = $true
        }

        # This resource block adds user to a spacific group
        xGroup "AddToRemoteDesktopUserGroup"
        {
            GroupName = "Remote Desktop Users"
            Ensure = "Present"
            MembersToInclude = Split-Path -Path $Credential.UserName -Leaf
            DependsOn = "[xUser]CreateUserAccount"
        }

        # This resource block adds user to a spacific group
        xGroup "AddToHyperVAdministratorGroup"
        {
            GroupName = "Hyper-V Administrators"
            Ensure = "Present"
            MembersToInclude = Split-Path -Path $Credential.UserName -Leaf
            DependsOn = "[xUser]CreateUserAccount"
        }

        # This resource block ensures that a Windows Features (Roles) is present
        xWindowsFeatureSet "AddHyperVFeatures"
        {
            Name = $features
            Ensure = "Present"
            IncludeAllSubFeature = $true
        }

        # This resource block ensures that the file is executed
        xScript "RunvSwitchForNestedVms"
        {
            SetScript = { 
                New-VMSwitch -SwitchName "Int-vSwitch" -SwitchType Internal
            }
            TestScript = { $false }
            GetScript = { 
                # Do Nothing
            }
            DependsOn = "[xWindowsFeatureSet]AddHyperVFeatures"
        }

        xScript "RunCreateSecPlus-DCVm"
        {
            SetScript = { 
                New-VM -Name "VSERVER" -MemoryStartupBytes 2GB -Generation 2 -BootDevice VHD -VHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\SecurityPlus\VSERVER.vhdx" -SwitchName "Int-vSwitch"
            }
            TestScript = { $false }
            GetScript = {  
                # Do Nothing
            }
            DependsOn = "[xWindowsFeatureSet]AddHyperVFeatures"
        }

        xScript "RunCreateSecPlus-Win10Vm"
        {
            SetScript = { 
                New-VM -Name "Client01" -MemoryStartupBytes 1GB -Generation 1 -BootDevice VHD -VHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\SecurityPlus\Client01.vhdx" -SwitchName "Int-vSwitch"
            }
            TestScript = { $false }
            GetScript = { 
                # Do Nothing
            }
            DependsOn = "[xWindowsFeatureSet]AddHyperVFeatures"
        }
    }
    
}