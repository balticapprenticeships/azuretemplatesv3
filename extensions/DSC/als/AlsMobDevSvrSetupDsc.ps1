#######################################################################
# Script to configure Windows lab environment using DSC for ALS       #
# Author: Chris Langford                                              #
# Version: 1.0.0                                                      #
#######################################################################

$password = "Balticlearner1" | ConvertTo-SecureString -asPlainText -Force
$username = "Apprentice"
[PSCredential] $credential = New-Object System.Management.Automation.PSCredential($username,$password)

Configuration MtaMDEnvServer {
    
    # Set values for feature install
    $features = @("Hyper-V", "RSAT-Hyper-V-Tools", "Hyper-V-Tools", "Hyper-V-PowerShell")

    # Import the DSC Module
    Import-DscResource -ModuleName PsDesiredStateConfiguration -ModuleVersion 2.0.5
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 9.1.0

    Node 'localhost' {

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        # This resource block create a local user
        xUser "CreateUserAccount" {
            Ensure = "Present"
            UserName = Split-Path -Path $Credential.username -Leaf
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
        xScript "RunNATForNestedVms"
        {
            SetScript = { 
                New-VMSwitch -SwitchName "Int-vSwitch" -SwitchType Internal                
                New-NetIPAddress -InterfaceAlias "vEthernet (Int-vSwitch)" -IPAddress 172.16.20.254 -PrefixLength 24
                New-NetNat -Name NAT-VM -InternalIPInterfaceAddressPrefix 172.16.20.0/24
            }
            TestScript = { $false }
            GetScript = { 
                # Do Nothing
            }
            DependsOn = "[xWindowsFeatureSet]AddHyperVFeatures"
        }

        # This resource block ensures that the file is executed
        xScript "RunvSwitchForNestedVms"
        {
            SetScript = { 
                New-VMSwitch -SwitchName "Private-vSwitch" -SwitchType Private
            }
            TestScript = { $false }
            GetScript = { 
                # Do Nothing
            }
            DependsOn = "[xWindowsFeatureSet]AddHyperVFeatures"
        }

        xScript "RunvCreateMTAMD-DCVm"
        {
            SetScript = { 
                New-VM -Name "MD-DC (Domain Controller)" -MemoryStartupBytes 2GB -Generation 2 -BootDevice VHD -VHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\MobilityandDevices\MTAMD-DC.vhdx" -SwitchName "Private-vSwitch"
            }
            TestScript = { $false }
            GetScript = { 
                # Do Nothing
            }
            DependsOn = "[xWindowsFeatureSet]AddHyperVFeatures"
        }

        xScript "RunvMTAMD-Win10Vm"
        {
            SetScript = { 
                New-VM -Name "MD-Windows 10 Client" -MemoryStartupBytes 1GB -Generation 1 -BootDevice VHD -VHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\MobilityandDevices\MTAMD-Win10.vhdx" -SwitchName "Private-vSwitch"
                New-VM -Name "MD-Windows 10 AAD Client" -MemoryStartupBytes 1GB -Generation 1 -BootDevice VHD -VHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\MobilityandDevices\MTAMD-Win10-AAD.vhdx" -SwitchName "Int-vSwitch"
            }
            TestScript = { $false }
            GetScript = { 
                # Do Nothing
            }
            DependsOn = "[xWindowsFeatureSet]AddHyperVFeatures"
        }

    }
}

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
        }
    )
}

MtaMDEnvServer -ConfigurationData $cd